-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_business_days" to load this file. \quit

CREATE FUNCTION add_business_days(
    start_date timestamp with time zone,
    days integer,
    weekend_days integer[] DEFAULT ARRAY[0, 6],
    holidays_relation regclass DEFAULT NULL,
    holidays_column name DEFAULT NULL
) RETURNS timestamp with time zone AS $$
    DECLARE
        end_date date;
    BEGIN
        IF cardinality(weekend_days) > 0 THEN
            IF NOT weekend_days <@ ARRAY[0, 1, 2, 3, 4, 5, 6] THEN
                RAISE 'weekend days contain days except Sunday (0) to Saturday (6): %', weekend_days;
            END IF;
            IF  weekend_days @> ARRAY[0, 1, 2, 3, 4, 5, 6] THEN
                RAISE 'weekend days are filled with Sunday (0) to Saturday (6): %', weekend_days;
            END IF;
        END IF;
        IF holidays_relation IS NULL AND holidays_column IS NOT NULL THEN
            RAISE 'holidays column "%" specified, but relation is not specified', holidays_column;
        END IF;
        IF holidays_relation IS NOT NULL THEN
            IF holidays_column IS NULL THEN
                RAISE 'holidays relation "%" specified, but column is not specified', holidays_relation;
            END IF;
            IF holidays_column NOT IN (SELECT attname FROM pg_attribute WHERE attrelid = holidays_relation) THEN
                RAISE 'holidays column "%" of relation "%" does not exist', holidays_column, holidays_relation;
            END IF;
        END IF;
        EXECUTE format(
            $COMMAND$
                WITH h (hd) AS (%1$s)
                SELECT d
                FROM generate_series(
                    %2$L,
                    %2$L::timestamp with time zone + (ceil(abs(%3$L::double precision) * 7 / (7 - cardinality(%4$L::int[])) + (SELECT count(*) FROM h)) * sign(%3$L) || ' days')::interval,
                    (CASE WHEN %3$L > 0 THEN 1 ELSE -1 END || ' day')::interval
                ) AS d
                WHERE d = %2$L OR (extract(DOW FROM d) != ALL (%4$L) AND d::date NOT IN (SELECT hd FROM h))
                ORDER BY extract(EPOCH FROM d) * sign(%3$L)
                LIMIT 1 OFFSET abs(%3$L);
            $COMMAND$,
            CASE WHEN holidays_relation IS NULL OR holidays_column IS NULL THEN 'SELECT NULL::date LIMIT 0'
                ELSE format('SELECT %1$I FROM %2$I.%3$I', VARIADIC (SELECT ARRAY[holidays_column, relnamespace::regnamespace::name, relname] FROM pg_class WHERE oid = holidays_relation))
            END,
            start_date,
            days,
            coalesce((SELECT array_agg(DISTINCT wd) FROM unnest(weekend_days) AS wd), ARRAY[]::int[])
        ) INTO end_date;
        RETURN end_date;
    END;
$$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION business_days_between(
    start_date timestamp with time zone,
    end_date timestamp with time zone,
    weekend_days integer[] DEFAULT ARRAY[0, 6],
    holidays_relation regclass DEFAULT NULL,
    holidays_column name DEFAULT NULL
) RETURNS integer AS $$
    DECLARE
        days integer;
    BEGIN
        IF cardinality(weekend_days) > 0 THEN
            IF NOT weekend_days <@ ARRAY[0, 1, 2, 3, 4, 5, 6] THEN
                RAISE 'weekend days contain days except Sunday (0) to Saturday (6): %', weekend_days;
            END IF;
            IF  weekend_days @> ARRAY[0, 1, 2, 3, 4, 5, 6] THEN
                RAISE 'weekend days are filled with Sunday (0) to Saturday (6): %', weekend_days;
            END IF;
        END IF;
        IF holidays_relation IS NULL AND holidays_column IS NOT NULL THEN
            RAISE 'holidays column "%" specified, but relation is not specified', holidays_column;
        END IF;
        IF holidays_relation IS NOT NULL THEN
            IF holidays_column IS NULL THEN
                RAISE 'holidays relation "%" specified, but column is not specified', holidays_relation;
            END IF;
            IF holidays_column NOT IN (SELECT attname FROM pg_attribute WHERE attrelid = holidays_relation) THEN
                RAISE 'holidays column "%" of relation "%" does not exist', holidays_column, holidays_relation;
            END IF;
        END IF;
        EXECUTE format(
            $COMMAND$
                WITH h (hd) AS (%1$s)
                SELECT count(*) * (CASE WHEN %2$L < %3$L THEN 1 ELSE -1 END)
                FROM generate_series(
                    %2$L,
                    %3$L,
                    (CASE WHEN %2$L < %3$L THEN 1 ELSE -1 END || ' day')::interval
                ) AS d
                WHERE extract(DOW FROM d) != ALL (%4$L) AND d::date NOT IN (SELECT hd FROM h)
            $COMMAND$,
            CASE WHEN holidays_relation IS NULL OR holidays_column IS NULL THEN 'SELECT NULL::date LIMIT 0'
                ELSE format('SELECT %1$I FROM %2$I.%3$I', VARIADIC (SELECT ARRAY[holidays_column, relnamespace::regnamespace::name, relname] FROM pg_class WHERE oid = holidays_relation))
            END,
            start_date,
            end_date,
            coalesce((SELECT array_agg(DISTINCT wd) FROM unnest(weekend_days) AS wd), ARRAY[]::int[])
        ) INTO days;
        RETURN days;
    END;
$$ LANGUAGE plpgsql STABLE;
