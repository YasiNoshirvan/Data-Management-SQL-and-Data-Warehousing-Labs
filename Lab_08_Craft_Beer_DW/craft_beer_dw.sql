/*
===============================================================================
Lab 08 - Craft Beer Data Warehouse
Dialect: PostgreSQL 14+
Source: Craft_beer_DW_text.pdf
===============================================================================
*/

-- =============================================================================
-- 1. DIMENSIONS AND FACT TABLE
-- =============================================================================

CREATE TABLE dim_date (
    date_key            INTEGER PRIMARY KEY,
    full_date           DATE NOT NULL UNIQUE,
    day_of_week         VARCHAR(12) NOT NULL,
    month_num           SMALLINT NOT NULL,
    month_of_year       VARCHAR(12) NOT NULL,
    two_month_period    SMALLINT NOT NULL,
    trimester           SMALLINT NOT NULL,
    four_month_period   SMALLINT NOT NULL,
    semester            SMALLINT NOT NULL,
    year_num            SMALLINT NOT NULL
);

CREATE TABLE dim_location (
    location_key    INTEGER PRIMARY KEY,
    city            VARCHAR(120) NOT NULL,
    province        VARCHAR(120),
    region          VARCHAR(120),
    state           VARCHAR(120) NOT NULL,
    UNIQUE (city, province, region, state)
);

CREATE TABLE dim_factory (
    factory_key             INTEGER PRIMARY KEY,
    factory_id              VARCHAR(60) NOT NULL UNIQUE,
    factory_name            VARCHAR(150) NOT NULL,
    production_line_count   INTEGER NOT NULL CHECK (production_line_count > 0),
    location_key            INTEGER NOT NULL REFERENCES dim_location(location_key)
);

CREATE TABLE dim_storage (
    storage_key     INTEGER PRIMARY KEY,
    storage_id      VARCHAR(60) NOT NULL UNIQUE,
    storage_name    VARCHAR(150) NOT NULL,
    capacity_m3     NUMERIC(16,2) NOT NULL CHECK (capacity_m3 > 0),
    location_key    INTEGER NOT NULL REFERENCES dim_location(location_key)
);

CREATE TABLE dim_beer_type (
    beer_type_key       INTEGER PRIMARY KEY,
    beer_type_name      VARCHAR(120) NOT NULL UNIQUE,
    alcoholic_content  NUMERIC(5,2) NOT NULL,
    ibu                 NUMERIC(8,2) NOT NULL
);

CREATE TABLE dim_hop (
    hop_key         INTEGER PRIMARY KEY,
    hop_name        VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE bridge_beer_hop (
    beer_type_key   INTEGER NOT NULL REFERENCES dim_beer_type(beer_type_key),
    hop_key         INTEGER NOT NULL REFERENCES dim_hop(hop_key),
    PRIMARY KEY (beer_type_key, hop_key)
);

CREATE TABLE dim_pack_format (
    pack_key        INTEGER PRIMARY KEY,
    bottles_per_pack SMALLINT NOT NULL UNIQUE CHECK (bottles_per_pack IN (1,3,6))
);

CREATE TABLE fact_beer_batch (
    batch_key               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    factory_key             INTEGER NOT NULL REFERENCES dim_factory(factory_key),
    storage_key             INTEGER NOT NULL REFERENCES dim_storage(storage_key),
    beer_type_key           INTEGER NOT NULL REFERENCES dim_beer_type(beer_type_key),
    pack_key                INTEGER NOT NULL REFERENCES dim_pack_format(pack_key),
    production_date_key     INTEGER NOT NULL REFERENCES dim_date(date_key),
    arrival_date_key        INTEGER NOT NULL REFERENCES dim_date(date_key),
    produced_liters         NUMERIC(18,3) NOT NULL CHECK (produced_liters >= 0),
    produced_bottles        BIGINT NOT NULL CHECK (produced_bottles >= 0),
    revenue                 NUMERIC(18,2) NOT NULL CHECK (revenue >= 0)
);

-- =============================================================================
-- 2. FREQUENT QUERIES
-- =============================================================================

-- Query A
-- Six-bottle packs: cumulative monthly liters, share of factory annual liters,
-- and factory rank by production within each production month.
WITH monthly AS (
    SELECT
        f.factory_key,
        fa.factory_name,
        d.year_num,
        d.month_num,
        SUM(f.produced_liters) AS monthly_liters
    FROM fact_beer_batch AS f
    JOIN dim_pack_format AS p ON p.pack_key = f.pack_key
    JOIN dim_factory AS fa ON fa.factory_key = f.factory_key
    JOIN dim_date AS d ON d.date_key = f.production_date_key
    WHERE p.bottles_per_pack = 6
    GROUP BY f.factory_key, fa.factory_name, d.year_num, d.month_num
)
SELECT
    factory_name,
    year_num,
    month_num,
    monthly_liters,
    SUM(monthly_liters) OVER (
        PARTITION BY factory_key, year_num
        ORDER BY month_num
    ) AS cumulative_liters_ytd,
    100.0 * monthly_liters
      / NULLIF(SUM(monthly_liters) OVER (PARTITION BY factory_key, year_num), 0)
      AS pct_of_factory_annual_liters,
    RANK() OVER (
        PARTITION BY year_num, month_num
        ORDER BY monthly_liters DESC
    ) AS factory_rank_for_month
FROM monthly
ORDER BY year_num, month_num, factory_rank_for_month;

-- Query B
-- Beer produced in 2018: beer type / storage / arrival month analysis.
-- Average daily bottle production is based on arrival-date daily totals.
WITH daily AS (
    SELECT
        f.beer_type_key,
        f.storage_key,
        f.arrival_date_key,
        SUM(f.revenue) AS daily_revenue,
        SUM(f.produced_bottles) AS daily_bottles
    FROM fact_beer_batch AS f
    JOIN dim_date AS prod ON prod.date_key = f.production_date_key
    WHERE prod.year_num = 2018
    GROUP BY f.beer_type_key, f.storage_key, f.arrival_date_key
), monthly AS (
    SELECT
        b.beer_type_key,
        b.beer_type_name,
        s.storage_key,
        s.storage_name,
        a.year_num AS arrival_year,
        a.month_num AS arrival_month,
        SUM(x.daily_revenue) AS revenue,
        SUM(x.daily_bottles) AS bottles,
        AVG(x.daily_bottles) AS avg_daily_bottles
    FROM daily AS x
    JOIN dim_beer_type AS b ON b.beer_type_key = x.beer_type_key
    JOIN dim_storage AS s ON s.storage_key = x.storage_key
    JOIN dim_date AS a ON a.date_key = x.arrival_date_key
    GROUP BY b.beer_type_key, b.beer_type_name, s.storage_key, s.storage_name,
             a.year_num, a.month_num
)
SELECT
    beer_type_name,
    storage_name,
    arrival_year,
    arrival_month,
    revenue / NULLIF(bottles, 0) AS avg_revenue_per_bottle,
    avg_daily_bottles,
    100.0 * bottles
      / NULLIF(SUM(bottles) OVER (
            PARTITION BY storage_key, arrival_year, arrival_month
        ), 0) AS pct_bottles_within_storage_month
FROM monthly
ORDER BY storage_name, arrival_year, arrival_month, beer_type_name;

-- =============================================================================
-- 3. PERFORMANCE STRUCTURES
-- =============================================================================

CREATE INDEX idx_beer_production_date
    ON fact_beer_batch (production_date_key, factory_key, pack_key);
CREATE INDEX idx_beer_arrival_date
    ON fact_beer_batch (arrival_date_key, storage_key, beer_type_key);
CREATE INDEX idx_beer_hop_bridge
    ON bridge_beer_hop (beer_type_key, hop_key);
