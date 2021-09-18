pg_business_days
================

Functions for handling business days in PostgreSQL.

Install
-------

```ShellSession
$ git clone https://github.com/tom-sato/pg_business_days.git
$ cd pg_business_days
$ sudo make install PG_CONFIG=/usr/pgsql-13/bin/pg_config
/usr/bin/mkdir -p '/usr/pgsql-13/share/extension'
/usr/bin/mkdir -p '/usr/pgsql-13/share/extension'
/usr/bin/install -c -m 644 .//pg_business_days.control '/usr/pgsql-13/share/extension/'
/usr/bin/install -c -m 644 .//pg_business_days--1.0.sql  '/usr/pgsql-13/share/extension/'
```

Usage
-----

```ShellSession
$ psql -U postgres
psql (13.4)
Type "help" for help.

=# CREATE EXTENSION pg_business_days;
CREATE EXTENSION
=# CREATE TABLE holidays (
       id serial PRIMARY KEY,
       date date NOT NULL,
       name text NOT NULL,
       UNIQUE (date, name)
   );
CREATE TABLE
=# COPY holidays (date, name) FROM PROGRAM 'curl https://holidays-jp.github.io/api/v1/2020/date.csv' (FORMAT CSV);
COPY 18
=# COPY holidays (date, name) FROM PROGRAM 'curl https://holidays-jp.github.io/api/v1/2021/date.csv' (FORMAT CSV);
COPY 17
=# COPY holidays (date, name) FROM PROGRAM 'curl https://holidays-jp.github.io/api/v1/2022/date.csv' (FORMAT CSV);
COPY 16
=# SELECT add_business_days('2021-09-16', 3);
   add_business_days
------------------------
 2021-09-21 00:00:00+09
(1 row)

=# SELECT add_business_days('2021-09-16', 3, weekend_days := ARRAY[0]);
   add_business_days
------------------------
 2021-09-20 00:00:00+09
(1 row)

=# SELECT add_business_days('2021-09-16', 3, holidays_relation := 'holidays', holidays_column := 'date');
   add_business_days
------------------------
 2021-09-22 00:00:00+09
(1 row)

=# SELECT business_days_between('2021-09-16', '2021-09-30');
 business_days_between
-----------------------
                    11
(1 row)
```

Functions
---------

### add_business_days

Returns the date before or after the number of business days from the start date, like the WORKDAY.INTL function in Microsoft Excel.

```SQLPL
add_business_days(
    start_date timestamp with time zone,
    days integer,
    weekend_days integer[] DEFAULT ARRAY[0, 6],
    holidays_relation regclass DEFAULT NULL,
    holidays_column name DEFAULT NULL
) RETURNS timestamp with time zone
```

* start_date - Required. The start date.
* days - Required. The number of business days.
* weekend_days - Optional. Weekend days that are not considered business days. The value is an array of Sunday (0) to Saturday (6). The default is Sunday and Saturday.
* holidays_relation, holidays_column - Optional. Table and column name to store holidays. Holidays are not considered business days. The default is not set.

### business_days_between

Returns the number of business days between the start and end days, like the NETWORKDAYS.INTL function in Microsoft Excel.

```SQLPL
business_days_between(
    start_date timestamp with time zone,
    end_date timestamp with time zone,
    weekend_days integer[] DEFAULT ARRAY[0, 6],
    holidays_relation regclass DEFAULT NULL,
    holidays_column name DEFAULT NULL
) RETURNS integer
```

* start_date - Required. The start date.
* end_date - Required. The end date.
* weekend_days - Optional. Weekend days that are not considered business days. The value is an array of Sunday (0) to Saturday (6). The default is Sunday and Saturday.
* holidays_relation, holidays_column - Optional. Table and column name to store holidays. Holidays are not considered business days. The default is not set.

License
-------

BSD

Author Information
------------------

Tomoaki Sato
