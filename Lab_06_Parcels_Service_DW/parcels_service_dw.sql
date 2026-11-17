/*
===============================================================================
Lab 06 - International Parcels Service Data Warehouse
Dialect: PostgreSQL 14+
Source: 06-DW-project-parcels-text.pdf
===============================================================================

Grain: FACT_DELIVERY_ROUTE represents the portion of a dispatch traveling over
one route. Measures are assumed to be attributable to that route, which is
necessary for route-level income/weight/volume analysis requested by the PDF.
*/

-- =============================================================================
-- 1. DIMENSIONS AND FACT TABLE
-- =============================================================================

CREATE TABLE dim_date (
    date_key            INTEGER PRIMARY KEY,
    full_date           DATE NOT NULL UNIQUE,
    day_of_month        SMALLINT NOT NULL,
    day_of_week         VARCHAR(12) NOT NULL,
    month_num           SMALLINT NOT NULL,
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

CREATE TABLE dim_branch (
    branch_key      INTEGER PRIMARY KEY,
    branch_id       VARCHAR(60) NOT NULL UNIQUE,
    branch_name     VARCHAR(160) NOT NULL,
    branch_district VARCHAR(120) NOT NULL
);

CREATE TABLE dim_good_category (
    category_key    INTEGER PRIMARY KEY,
    category_name   VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE dim_carrier_type (
    carrier_key     INTEGER PRIMARY KEY,
    carrier_type    VARCHAR(60) NOT NULL UNIQUE
);

CREATE TABLE fact_delivery_route (
    route_fact_key              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dispatch_id                 VARCHAR(80) NOT NULL,
    date_key                    INTEGER NOT NULL REFERENCES dim_date(date_key),
    branch_key                  INTEGER NOT NULL REFERENCES dim_branch(branch_key),
    category_key                INTEGER NOT NULL REFERENCES dim_good_category(category_key),
    carrier_key                 INTEGER NOT NULL REFERENCES dim_carrier_type(carrier_key),
    departure_location_key      INTEGER NOT NULL REFERENCES dim_location(location_key),
    destination_location_key    INTEGER NOT NULL REFERENCES dim_location(location_key),
    income                      NUMERIC(16,2) NOT NULL CHECK (income >= 0),
    weight_kg                   NUMERIC(16,3) NOT NULL CHECK (weight_kg >= 0),
    volume_m3                   NUMERIC(16,4) NOT NULL CHECK (volume_m3 >= 0)
);

-- =============================================================================
-- 2. FREQUENT QUERIES
-- =============================================================================

-- Query A
-- Italian routes: average daily income by category/year/month and cumulative
-- monthly income from the beginning of the year.
WITH daily AS (
    SELECT
        f.category_key,
        f.date_key,
        SUM(f.income) AS daily_income
    FROM fact_delivery_route AS f
    JOIN dim_location AS dep ON dep.location_key = f.departure_location_key
    JOIN dim_location AS dst ON dst.location_key = f.destination_location_key
    WHERE dep.state = 'Italy'
      AND dst.state = 'Italy'
    GROUP BY f.category_key, f.date_key
), monthly AS (
    SELECT
        c.category_name,
        d.year_num,
        d.month_num,
        AVG(x.daily_income) AS avg_daily_income,
        SUM(x.daily_income) AS monthly_income
    FROM daily AS x
    JOIN dim_date AS d ON d.date_key = x.date_key
    JOIN dim_good_category AS c ON c.category_key = x.category_key
    GROUP BY c.category_name, d.year_num, d.month_num
)
SELECT
    category_name,
    year_num,
    month_num,
    avg_daily_income,
    monthly_income,
    SUM(monthly_income) OVER (
        PARTITION BY category_name, year_num
        ORDER BY month_num
    ) AS cumulative_monthly_income
FROM monthly
ORDER BY category_name, year_num, month_num;

-- Query B
-- Air carrier: yearly income per unit volume by destination province and its
-- percentage relative to the corresponding destination-state ratio.
WITH province_stats AS (
    SELECT
        d.year_num,
        dst.state,
        dst.province,
        SUM(f.income) AS province_income,
        SUM(f.volume_m3) AS province_volume
    FROM fact_delivery_route AS f
    JOIN dim_date AS d ON d.date_key = f.date_key
    JOIN dim_carrier_type AS c ON c.carrier_key = f.carrier_key
    JOIN dim_location AS dst ON dst.location_key = f.destination_location_key
    WHERE c.carrier_type = 'Air'
    GROUP BY d.year_num, dst.state, dst.province
), ratios AS (
    SELECT
        year_num,
        state,
        province,
        province_income / NULLIF(province_volume, 0) AS province_income_per_m3,
        SUM(province_income) OVER (PARTITION BY year_num, state)
          / NULLIF(SUM(province_volume) OVER (PARTITION BY year_num, state), 0)
          AS state_income_per_m3
    FROM province_stats
)
SELECT
    year_num,
    state,
    province,
    province_income_per_m3,
    100.0 * province_income_per_m3 / NULLIF(state_income_per_m3, 0)
        AS pct_of_state_income_per_m3
FROM ratios
ORDER BY year_num, state, province;

-- Query C
-- 2006: route by departure/destination region and month; average income per kg
-- and average daily income.
WITH daily_route AS (
    SELECT
        f.date_key,
        dep.region AS departure_region,
        dst.region AS destination_region,
        SUM(f.income) AS daily_income,
        SUM(f.weight_kg) AS daily_weight
    FROM fact_delivery_route AS f
    JOIN dim_date AS d ON d.date_key = f.date_key
    JOIN dim_location AS dep ON dep.location_key = f.departure_location_key
    JOIN dim_location AS dst ON dst.location_key = f.destination_location_key
    WHERE d.year_num = 2006
    GROUP BY f.date_key, dep.region, dst.region
)
SELECT
    x.departure_region,
    x.destination_region,
    d.month_num,
    SUM(x.daily_income) / NULLIF(SUM(x.daily_weight), 0) AS avg_income_per_kg,
    AVG(x.daily_income) AS avg_daily_income
FROM daily_route AS x
JOIN dim_date AS d ON d.date_key = x.date_key
GROUP BY x.departure_region, x.destination_region, d.month_num
ORDER BY x.departure_region, x.destination_region, d.month_num;

-- Query D
-- Branch district/carrier/month totals and rank by monthly delivered volume.
WITH monthly AS (
    SELECT
        b.branch_district,
        c.carrier_type,
        d.year_num,
        d.month_num,
        SUM(f.income) AS monthly_income,
        SUM(f.volume_m3) AS monthly_volume
    FROM fact_delivery_route AS f
    JOIN dim_branch AS b ON b.branch_key = f.branch_key
    JOIN dim_carrier_type AS c ON c.carrier_key = f.carrier_key
    JOIN dim_date AS d ON d.date_key = f.date_key
    GROUP BY b.branch_district, c.carrier_type, d.year_num, d.month_num
)
SELECT
    branch_district,
    carrier_type,
    year_num,
    month_num,
    monthly_income,
    monthly_volume,
    RANK() OVER (
        PARTITION BY year_num, month_num
        ORDER BY monthly_volume DESC
    ) AS monthly_volume_rank
FROM monthly
ORDER BY year_num, month_num, monthly_volume_rank;

-- Query E
-- 2005: departure/destination city route; yearly income per kg and average
-- daily income.
WITH daily_route AS (
    SELECT
        f.date_key,
        dep.city AS departure_city,
        dst.city AS destination_city,
        SUM(f.income) AS daily_income,
        SUM(f.weight_kg) AS daily_weight
    FROM fact_delivery_route AS f
    JOIN dim_date AS d ON d.date_key = f.date_key
    JOIN dim_location AS dep ON dep.location_key = f.departure_location_key
    JOIN dim_location AS dst ON dst.location_key = f.destination_location_key
    WHERE d.year_num = 2005
    GROUP BY f.date_key, dep.city, dst.city
)
SELECT
    departure_city,
    destination_city,
    SUM(daily_income) / NULLIF(SUM(daily_weight), 0) AS yearly_income_per_kg,
    AVG(daily_income) AS avg_daily_income
FROM daily_route
GROUP BY departure_city, destination_city
ORDER BY departure_city, destination_city;

-- Query F
-- 2005-2006, sea shipping: half-year income per volume and per weight by
-- branch and departure region.
SELECT
    b.branch_id,
    dep.region AS departure_region,
    d.year_num,
    d.semester,
    SUM(f.income) / NULLIF(SUM(f.volume_m3), 0) AS avg_income_per_m3,
    SUM(f.income) / NULLIF(SUM(f.weight_kg), 0) AS avg_income_per_kg
FROM fact_delivery_route AS f
JOIN dim_date AS d ON d.date_key = f.date_key
JOIN dim_branch AS b ON b.branch_key = f.branch_key
JOIN dim_carrier_type AS c ON c.carrier_key = f.carrier_key
JOIN dim_location AS dep ON dep.location_key = f.departure_location_key
WHERE d.year_num IN (2005, 2006)
  AND c.carrier_type = 'Sea'
GROUP BY b.branch_id, dep.region, d.year_num, d.semester
ORDER BY b.branch_id, dep.region, d.year_num, d.semester;

-- Query G
-- Departure city / branch district: income and volume by four-month period.
SELECT
    dep.city AS departure_city,
    b.branch_district,
    d.year_num,
    d.four_month_period,
    SUM(f.income) AS period_income,
    SUM(f.volume_m3) AS period_volume
FROM fact_delivery_route AS f
JOIN dim_date AS d ON d.date_key = f.date_key
JOIN dim_branch AS b ON b.branch_key = f.branch_key
JOIN dim_location AS dep ON dep.location_key = f.departure_location_key
GROUP BY dep.city, b.branch_district, d.year_num, d.four_month_period
ORDER BY dep.city, b.branch_district, d.year_num, d.four_month_period;

-- =============================================================================
-- 3. MATERIALIZED VIEWS / INDEXES
-- =============================================================================

CREATE MATERIALIZED VIEW mv_route_monthly AS
SELECT
    f.branch_key,
    f.category_key,
    f.carrier_key,
    f.departure_location_key,
    f.destination_location_key,
    d.year_num,
    d.month_num,
    d.semester,
    d.four_month_period,
    SUM(f.income) AS total_income,
    SUM(f.weight_kg) AS total_weight_kg,
    SUM(f.volume_m3) AS total_volume_m3
FROM fact_delivery_route AS f
JOIN dim_date AS d ON d.date_key = f.date_key
GROUP BY
    f.branch_key, f.category_key, f.carrier_key,
    f.departure_location_key, f.destination_location_key,
    d.year_num, d.month_num, d.semester, d.four_month_period;

CREATE INDEX idx_route_date_carrier ON fact_delivery_route (date_key, carrier_key);
CREATE INDEX idx_route_branch ON fact_delivery_route (branch_key);
CREATE INDEX idx_route_departure ON fact_delivery_route (departure_location_key);
CREATE INDEX idx_route_destination ON fact_delivery_route (destination_location_key);
