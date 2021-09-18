EXTENSION = pg_business_days
DATA = pg_business_days--1.0.sql
PGFILEDESC = "pg_business_days - functions for handling business days"

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
