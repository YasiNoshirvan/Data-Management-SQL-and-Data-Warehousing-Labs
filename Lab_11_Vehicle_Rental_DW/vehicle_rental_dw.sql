/*
===============================================================================
Lab 11 - Vehicle Rental Data Warehouse
Dialect: PostgreSQL 14+
Source: Vehicle_rental_DW_text.pdf
===============================================================================
*/

-- =============================================================================
-- 1. DIMENSIONS AND FACT TABLE
-- =============================================================================

CREATE TABLE dim_date (
    date_key            INTEGER PRIMARY KEY,
    full_date           DATE NOT NULL UNIQUE,
    month_num           SMALLINT NOT NULL,
    month_of_year       VARCHAR(12) NOT NULL,
    two_month_period    SMALLINT NOT NULL,
    trimester           SMALLINT NOT NULL,
    semester            SMALLINT NOT NULL,
    year_num            SMALLINT NOT NULL,
    day_of_week         VARCHAR(12) NOT NULL,
    is_working_day      BOOLEAN NOT NULL
);

CREATE TABLE dim_location (
    location_key    INTEGER PRIMARY KEY,
    city            VARCHAR(120) NOT NULL,
    province        VARCHAR(120),
    region          VARCHAR(120),
    UNIQUE (city, province, region)
);

CREATE TABLE dim_vehicle_model (
    vehicle_model_key INTEGER PRIMARY KEY,
    model_name        VARCHAR(120) NOT NULL,
    brand             VARCHAR(120) NOT NULL,
    vehicle_type      VARCHAR(60) NOT NULL,
    UNIQUE (model_name, brand)
);

CREATE TABLE dim_vehicle_option (
    option_key      INTEGER PRIMARY KEY,
    option_name     VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE bridge_vehicle_option (
    vehicle_model_key INTEGER NOT NULL REFERENCES dim_vehicle_model(vehicle_model_key),
    option_key        INTEGER NOT NULL REFERENCES dim_vehicle_option(option_key),
    PRIMARY KEY (vehicle_model_key, option_key)
);

CREATE TABLE dim_payment_method (
    payment_key     INTEGER PRIMARY KEY,
    payment_method  VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE dim_client (
    client_key              INTEGER PRIMARY KEY,
    client_id               VARCHAR(60) NOT NULL UNIQUE,
    client_type             VARCHAR(30) NOT NULL,
    domicile_location_key   INTEGER NOT NULL REFERENCES dim_location(location_key)
);

CREATE TABLE fact_rental (
    rental_key              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    start_date_key          INTEGER NOT NULL REFERENCES dim_date(date_key),
    departure_location_key  INTEGER NOT NULL REFERENCES dim_location(location_key),
    arrival_location_key    INTEGER NOT NULL REFERENCES dim_location(location_key),
    vehicle_model_key       INTEGER NOT NULL REFERENCES dim_vehicle_model(vehicle_model_key),
    payment_key             INTEGER NOT NULL REFERENCES dim_payment_method(payment_key),
    client_key              INTEGER NOT NULL REFERENCES dim_client(client_key),
    revenue                 NUMERIC(16,2) NOT NULL CHECK (revenue >= 0),
    distance_km             NUMERIC(16,3) NOT NULL CHECK (distance_km >= 0)
);

-- =============================================================================
-- 2. FREQUENT QUERIES
-- =============================================================================

-- Query A
-- Credit-card rentals: month x client type x domicile province.
WITH filtered AS (
    SELECT
        f.rental_key,
        f.start_date_key,
        f.distance_km,
        c.client_type,
        loc.province AS domicile_province
    FROM fact_rental AS f
    JOIN dim_payment_method AS p ON p.payment_key = f.payment_key
    JOIN dim_client AS c ON c.client_key = f.client_key
    JOIN dim_location AS loc ON loc.location_key = c.domicile_location_key
    WHERE p.payment_method = 'Credit card'
), daily AS (
    SELECT
        client_type,
        domicile_province,
        start_date_key,
        SUM(distance_km) AS daily_km,
        COUNT(*) AS daily_rentals
    FROM filtered
    GROUP BY client_type, domicile_province, start_date_key
), monthly AS (
    SELECT
        x.client_type,
        x.domicile_province,
        d.year_num,
        d.month_num,
        SUM(x.daily_km) AS monthly_km,
        SUM(x.daily_rentals) AS monthly_rentals,
        AVG(x.daily_km) AS avg_daily_km
    FROM daily AS x
    JOIN dim_date AS d ON d.date_key = x.start_date_key
    GROUP BY x.client_type, x.domicile_province, d.year_num, d.month_num
)
SELECT
    client_type,
    domicile_province,
    year_num,
    month_num,
    monthly_km / NULLIF(monthly_rentals, 0) AS avg_km_per_rental,
    SUM(monthly_km) OVER (
        PARTITION BY client_type, domicile_province, year_num
        ORDER BY month_num
    ) AS cumulative_km_ytd,
    avg_daily_km
FROM monthly
ORDER BY client_type, domicile_province, year_num, month_num;

-- Query B
-- Truck rentals: month x departure province.
-- Assumption: the "corresponding departure region" denominator is the revenue
-- of all truck rentals in that region for the same year/month.
WITH province_month AS (
    SELECT
        dep.region,
        dep.province,
        d.year_num,
        d.month_num,
        SUM(f.revenue) AS revenue,
        SUM(f.distance_km) AS distance_km
    FROM fact_rental AS f
    JOIN dim_vehicle_model AS v ON v.vehicle_model_key = f.vehicle_model_key
    JOIN dim_location AS dep ON dep.location_key = f.departure_location_key
    JOIN dim_date AS d ON d.date_key = f.start_date_key
    WHERE LOWER(v.vehicle_type) = 'truck'
    GROUP BY dep.region, dep.province, d.year_num, d.month_num
)
SELECT
    region,
    province,
    year_num,
    month_num,
    revenue / NULLIF(distance_km, 0) AS avg_revenue_per_km,
    100.0 * revenue
      / NULLIF(SUM(revenue) OVER (PARTITION BY year_num), 0)
      AS pct_revenue_of_year,
    100.0 * revenue
      / NULLIF(SUM(revenue) OVER (
            PARTITION BY region, year_num, month_num
        ), 0) AS pct_revenue_of_departure_region
FROM province_month
ORDER BY year_num, month_num, region, province;

-- =============================================================================
-- 3. INDEXES
-- =============================================================================

CREATE INDEX idx_rental_date_payment
    ON fact_rental (start_date_key, payment_key);
CREATE INDEX idx_rental_vehicle
    ON fact_rental (vehicle_model_key);
CREATE INDEX idx_rental_departure
    ON fact_rental (departure_location_key);
CREATE INDEX idx_rental_client
    ON fact_rental (client_key);
CREATE INDEX idx_vehicle_option_bridge
    ON bridge_vehicle_option (vehicle_model_key, option_key);
