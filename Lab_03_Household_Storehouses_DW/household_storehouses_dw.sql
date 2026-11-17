/*
===============================================================================
Lab 03 - Household Appliance Storehouses Data Warehouse
Dialect: PostgreSQL 14+
Source: 03-DW-project-household-text.pdf
===============================================================================

Design choice:
- FACT_INVENTORY_DAILY is at date x storehouse x product grain.
- FACT_STOREHOUSE_SURFACE_DAILY is at date x storehouse grain.
Keeping surface measures in a separate fact prevents double counting when a
storehouse contains multiple product types.
*/

-- =============================================================================
-- 1. DIMENSIONS AND FACT TABLES
-- =============================================================================

CREATE TABLE dim_date (
    date_key            INTEGER PRIMARY KEY,       -- YYYYMMDD
    full_date           DATE NOT NULL UNIQUE,
    day_of_month        SMALLINT NOT NULL,
    month_num           SMALLINT NOT NULL,
    month_name          VARCHAR(12) NOT NULL,
    trimester           SMALLINT NOT NULL,
    four_month_period   SMALLINT NOT NULL,
    semester            SMALLINT NOT NULL,
    year_num            SMALLINT NOT NULL
);

CREATE TABLE dim_location (
    location_key    INTEGER PRIMARY KEY,
    city            VARCHAR(100) NOT NULL,
    province        VARCHAR(100) NOT NULL,
    region          VARCHAR(100) NOT NULL,
    UNIQUE (city, province, region)
);

CREATE TABLE dim_storehouse (
    storehouse_key   INTEGER PRIMARY KEY,
    storehouse_id    VARCHAR(50) NOT NULL UNIQUE,
    storehouse_name  VARCHAR(150),
    location_key     INTEGER NOT NULL REFERENCES dim_location(location_key)
);

CREATE TABLE dim_product (
    product_key       INTEGER PRIMARY KEY,
    product_type      VARCHAR(100) NOT NULL,
    product_category  VARCHAR(100) NOT NULL
);

CREATE TABLE fact_inventory_daily (
    date_key          INTEGER NOT NULL REFERENCES dim_date(date_key),
    storehouse_key    INTEGER NOT NULL REFERENCES dim_storehouse(storehouse_key),
    product_key       INTEGER NOT NULL REFERENCES dim_product(product_key),
    units_in_stock    NUMERIC(18,2) NOT NULL CHECK (units_in_stock >= 0),
    inventory_value   NUMERIC(18,2) NOT NULL CHECK (inventory_value >= 0),
    PRIMARY KEY (date_key, storehouse_key, product_key)
);

CREATE TABLE fact_storehouse_surface_daily (
    date_key                    INTEGER NOT NULL REFERENCES dim_date(date_key),
    storehouse_key              INTEGER NOT NULL REFERENCES dim_storehouse(storehouse_key),
    total_available_surface_m2  NUMERIC(18,2) NOT NULL CHECK (total_available_surface_m2 > 0),
    free_surface_m2             NUMERIC(18,2) NOT NULL CHECK (free_surface_m2 >= 0),
    PRIMARY KEY (date_key, storehouse_key),
    CHECK (free_surface_m2 <= total_available_surface_m2)
);

-- Insurance policies may cover a single storehouse or several storehouses in
-- the same city/province/region. The bridge materializes the applicable scope.
CREATE TABLE dim_insurance_policy (
    policy_key       INTEGER PRIMARY KEY,
    policy_name      VARCHAR(150) NOT NULL,
    insurer_name     VARCHAR(150),
    scope_level      VARCHAR(20) NOT NULL
                     CHECK (scope_level IN ('STOREHOUSE','CITY','PROVINCE','REGION')),
    notes            TEXT
);

CREATE TABLE bridge_policy_storehouse (
    policy_key       INTEGER NOT NULL REFERENCES dim_insurance_policy(policy_key),
    storehouse_key   INTEGER NOT NULL REFERENCES dim_storehouse(storehouse_key),
    PRIMARY KEY (policy_key, storehouse_key)
);

-- =============================================================================
-- 2. FREQUENT QUERIES
-- =============================================================================

-- Query A
-- Q1 2003, Turin: daily inventory value per storehouse and 7-day moving
-- average including the current day.
WITH daily_storehouse AS (
    SELECT
        f.date_key,
        f.storehouse_key,
        SUM(f.inventory_value) AS daily_total_value
    FROM fact_inventory_daily AS f
    GROUP BY f.date_key, f.storehouse_key
), turin_q1 AS (
    SELECT
        d.full_date,
        s.storehouse_id,
        ds.storehouse_key,
        ds.daily_total_value
    FROM daily_storehouse AS ds
    JOIN dim_date AS d
        ON d.date_key = ds.date_key
    JOIN dim_storehouse AS s
        ON s.storehouse_key = ds.storehouse_key
    JOIN dim_location AS l
        ON l.location_key = s.location_key
    WHERE d.year_num = 2003
      AND d.trimester = 1
      AND l.city = 'Turin'
)
SELECT
    full_date,
    storehouse_id,
    daily_total_value,
    AVG(daily_total_value) OVER (
        PARTITION BY storehouse_key
        ORDER BY full_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS avg_daily_value_previous_7_days
FROM turin_q1
ORDER BY storehouse_id, full_date;

-- Query B
-- 2004: daily free-surface percentage by city; rank 1 = lowest percentage.
WITH city_daily_surface AS (
    SELECT
        f.date_key,
        l.city,
        SUM(f.free_surface_m2) AS free_m2,
        SUM(f.total_available_surface_m2) AS total_m2
    FROM fact_storehouse_surface_daily AS f
    JOIN dim_storehouse AS s
        ON s.storehouse_key = f.storehouse_key
    JOIN dim_location AS l
        ON l.location_key = s.location_key
    JOIN dim_date AS d
        ON d.date_key = f.date_key
    WHERE d.year_num = 2004
    GROUP BY f.date_key, l.city
), city_pct AS (
    SELECT
        date_key,
        city,
        100.0 * free_m2 / NULLIF(total_m2, 0) AS free_surface_pct
    FROM city_daily_surface
)
SELECT
    d.full_date,
    c.city,
    c.free_surface_pct,
    RANK() OVER (
        PARTITION BY c.date_key
        ORDER BY c.free_surface_pct ASC
    ) AS free_surface_rank
FROM city_pct AS c
JOIN dim_date AS d
    ON d.date_key = c.date_key
ORDER BY d.full_date, free_surface_rank, c.city;

-- Query C
-- First six months of 2004: free-surface percentage per storehouse and date.
SELECT
    d.full_date,
    s.storehouse_id,
    100.0 * f.free_surface_m2 / NULLIF(f.total_available_surface_m2, 0)
        AS free_surface_pct
FROM fact_storehouse_surface_daily AS f
JOIN dim_date AS d
    ON d.date_key = f.date_key
JOIN dim_storehouse AS s
    ON s.storehouse_key = f.storehouse_key
WHERE d.year_num = 2004
  AND d.month_num BETWEEN 1 AND 6
ORDER BY s.storehouse_id, d.full_date;

-- Query D
-- 2003: average daily total inventory value by storehouse and month.
WITH daily_storehouse AS (
    SELECT
        f.date_key,
        f.storehouse_key,
        SUM(f.inventory_value) AS daily_total_value
    FROM fact_inventory_daily AS f
    GROUP BY f.date_key, f.storehouse_key
)
SELECT
    s.storehouse_id,
    d.month_num,
    AVG(ds.daily_total_value) AS avg_daily_total_value
FROM daily_storehouse AS ds
JOIN dim_date AS d
    ON d.date_key = ds.date_key
JOIN dim_storehouse AS s
    ON s.storehouse_key = ds.storehouse_key
WHERE d.year_num = 2003
GROUP BY s.storehouse_id, d.month_num
ORDER BY s.storehouse_id, d.month_num;

-- Query E
-- 2003: average daily total inventory value by region.
WITH region_daily AS (
    SELECT
        f.date_key,
        l.region,
        SUM(f.inventory_value) AS daily_region_value
    FROM fact_inventory_daily AS f
    JOIN dim_storehouse AS s
        ON s.storehouse_key = f.storehouse_key
    JOIN dim_location AS l
        ON l.location_key = s.location_key
    JOIN dim_date AS d
        ON d.date_key = f.date_key
    WHERE d.year_num = 2003
    GROUP BY f.date_key, l.region
)
SELECT
    region,
    AVG(daily_region_value) AS avg_daily_total_value
FROM region_daily
GROUP BY region
ORDER BY region;

-- Query F
-- 2004: average daily free-surface percentage by month and region.
WITH region_daily_surface AS (
    SELECT
        f.date_key,
        l.region,
        SUM(f.free_surface_m2) AS free_m2,
        SUM(f.total_available_surface_m2) AS total_m2
    FROM fact_storehouse_surface_daily AS f
    JOIN dim_storehouse AS s
        ON s.storehouse_key = f.storehouse_key
    JOIN dim_location AS l
        ON l.location_key = s.location_key
    JOIN dim_date AS d
        ON d.date_key = f.date_key
    WHERE d.year_num = 2004
    GROUP BY f.date_key, l.region
), region_daily_pct AS (
    SELECT
        r.date_key,
        r.region,
        100.0 * r.free_m2 / NULLIF(r.total_m2, 0) AS daily_free_pct
    FROM region_daily_surface AS r
)
SELECT
    r.region,
    d.month_num,
    AVG(r.daily_free_pct) AS avg_daily_free_surface_pct
FROM region_daily_pct AS r
JOIN dim_date AS d
    ON d.date_key = r.date_key
GROUP BY r.region, d.month_num
ORDER BY r.region, d.month_num;

-- =============================================================================
-- 3. PERFORMANCE STRUCTURES
-- =============================================================================

-- This view removes the product dimension from common inventory-value analyses.
CREATE MATERIALIZED VIEW mv_storehouse_daily_inventory AS
SELECT
    date_key,
    storehouse_key,
    SUM(units_in_stock) AS total_units,
    SUM(inventory_value) AS total_inventory_value
FROM fact_inventory_daily
GROUP BY date_key, storehouse_key;

CREATE UNIQUE INDEX idx_mv_storehouse_daily_inventory
    ON mv_storehouse_daily_inventory (date_key, storehouse_key);

CREATE INDEX idx_inventory_storehouse_date
    ON fact_inventory_daily (storehouse_key, date_key);

CREATE INDEX idx_surface_storehouse_date
    ON fact_storehouse_surface_daily (storehouse_key, date_key);

CREATE INDEX idx_storehouse_location
    ON dim_storehouse (location_key);

CREATE INDEX idx_location_city_region
    ON dim_location (city, region);
