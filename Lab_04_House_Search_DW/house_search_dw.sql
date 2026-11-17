/*
===============================================================================
Lab 04 - House Search Data Warehouse
Dialect: PostgreSQL 14+
Source: 04-DW-project-HouseSearch-text.pdf
===============================================================================

Snapshot grain:
FACT_PROPERTY_WEEKLY_SNAPSHOT stores one row per property per weekly snapshot.
This matches the source process in which adverts are refreshed every Monday.
Furniture is many-to-many and is therefore modeled with a bridge table.
*/

-- =============================================================================
-- 1. DIMENSIONS AND FACT TABLE
-- =============================================================================

CREATE TABLE dim_date (
    date_key            INTEGER PRIMARY KEY,
    full_date           DATE NOT NULL UNIQUE,
    week_of_year        SMALLINT NOT NULL,
    month_num           SMALLINT NOT NULL,
    two_month_period    SMALLINT NOT NULL,
    trimester           SMALLINT NOT NULL,
    four_month_period   SMALLINT NOT NULL,
    semester            SMALLINT NOT NULL,
    season              VARCHAR(10) NOT NULL,
    year_num            SMALLINT NOT NULL
);

CREATE TABLE dim_location (
    location_key        INTEGER PRIMARY KEY,
    district            VARCHAR(150),
    city                VARCHAR(120) NOT NULL,
    province            VARCHAR(120) NOT NULL,
    region              VARCHAR(120) NOT NULL,
    country_area        VARCHAR(30) NOT NULL,
    university_present  BOOLEAN NOT NULL,
    UNIQUE (district, city, province, region)
);

CREATE TABLE dim_property (
    property_key        INTEGER PRIMARY KEY,
    property_id         VARCHAR(80) NOT NULL UNIQUE,
    location_key        INTEGER NOT NULL REFERENCES dim_location(location_key),
    property_type       VARCHAR(80) NOT NULL,
    surface_m2          NUMERIC(10,2) NOT NULL CHECK (surface_m2 > 0),
    rooms               SMALLINT NOT NULL,
    bathrooms           SMALLINT,
    floor_num           SMALLINT,
    has_elevator        BOOLEAN,
    has_cellar          BOOLEAN,
    has_garage          BOOLEAN,
    surface_range       VARCHAR(30) NOT NULL
);

CREATE TABLE dim_furniture (
    furniture_key       INTEGER PRIMARY KEY,
    furniture_name      VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE bridge_property_furniture (
    property_key        INTEGER NOT NULL REFERENCES dim_property(property_key),
    furniture_key       INTEGER NOT NULL REFERENCES dim_furniture(furniture_key),
    PRIMARY KEY (property_key, furniture_key)
);

CREATE TABLE fact_property_weekly_snapshot (
    date_key             INTEGER NOT NULL REFERENCES dim_date(date_key),
    property_key         INTEGER NOT NULL REFERENCES dim_property(property_key),
    is_available         BOOLEAN NOT NULL,
    monthly_rent         NUMERIC(12,2) NOT NULL CHECK (monthly_rent >= 0),
    rent_price_range     VARCHAR(30) NOT NULL,
    favorite_users_count INTEGER NOT NULL DEFAULT 0 CHECK (favorite_users_count >= 0),
    PRIMARY KEY (date_key, property_key)
);

-- =============================================================================
-- 2. FREQUENT QUERIES
-- =============================================================================

-- Query A
-- 2004, university cities: monthly average rent and cumulative YTD average rent.
WITH city_month AS (
    SELECT
        l.city,
        d.year_num,
        d.month_num,
        SUM(f.monthly_rent) AS rent_sum,
        COUNT(*) AS observation_count
    FROM fact_property_weekly_snapshot AS f
    JOIN dim_date AS d ON d.date_key = f.date_key
    JOIN dim_property AS p ON p.property_key = f.property_key
    JOIN dim_location AS l ON l.location_key = p.location_key
    WHERE d.year_num = 2004
      AND l.university_present = TRUE
      AND f.is_available = TRUE
    GROUP BY l.city, d.year_num, d.month_num
)
SELECT
    city,
    year_num,
    month_num,
    rent_sum / NULLIF(observation_count, 0) AS avg_monthly_rent,
    SUM(rent_sum) OVER (
        PARTITION BY city, year_num
        ORDER BY month_num
    )
    / NULLIF(
        SUM(observation_count) OVER (
            PARTITION BY city, year_num
            ORDER BY month_num
        ), 0
      ) AS avg_rent_since_year_start
FROM city_month
ORDER BY city, month_num;

-- Query B
-- September 2004, Turin province: available properties by city/week, share of
-- the weekly province total, and descending rank.
WITH city_week AS (
    SELECT
        l.city,
        d.week_of_year,
        COUNT(*) FILTER (WHERE f.is_available) AS free_properties
    FROM fact_property_weekly_snapshot AS f
    JOIN dim_date AS d ON d.date_key = f.date_key
    JOIN dim_property AS p ON p.property_key = f.property_key
    JOIN dim_location AS l ON l.location_key = p.location_key
    WHERE d.year_num = 2004
      AND d.month_num = 9
      AND l.province = 'Turin'
    GROUP BY l.city, d.week_of_year
)
SELECT
    city,
    week_of_year,
    free_properties,
    free_properties::NUMERIC
      / NULLIF(SUM(free_properties) OVER (PARTITION BY week_of_year), 0)
      AS share_of_weekly_free_properties,
    RANK() OVER (
        PARTITION BY week_of_year
        ORDER BY free_properties DESC
    ) AS free_property_rank
FROM city_week
ORDER BY week_of_year, free_property_rank, city;

-- Helper predicate pattern used below: furniture requirements are expressed
-- with EXISTS to avoid duplicating fact rows through the many-to-many bridge.

-- Query C
-- Summer 2005, Rome, attics with bed + fridge + table: average favorite users
-- by district and rent range, plus district-wide average.
WITH filtered AS (
    SELECT
        l.district,
        f.rent_price_range,
        f.favorite_users_count
    FROM fact_property_weekly_snapshot AS f
    JOIN dim_date AS d ON d.date_key = f.date_key
    JOIN dim_property AS p ON p.property_key = f.property_key
    JOIN dim_location AS l ON l.location_key = p.location_key
    WHERE d.year_num = 2005
      AND d.season = 'Summer'
      AND l.city = 'Rome'
      AND p.property_type = 'Attic'
      AND EXISTS (
          SELECT 1
          FROM bridge_property_furniture b
          JOIN dim_furniture x ON x.furniture_key = b.furniture_key
          WHERE b.property_key = p.property_key AND x.furniture_name = 'Bed'
      )
      AND EXISTS (
          SELECT 1
          FROM bridge_property_furniture b
          JOIN dim_furniture x ON x.furniture_key = b.furniture_key
          WHERE b.property_key = p.property_key AND x.furniture_name = 'Fridge'
      )
      AND EXISTS (
          SELECT 1
          FROM bridge_property_furniture b
          JOIN dim_furniture x ON x.furniture_key = b.furniture_key
          WHERE b.property_key = p.property_key AND x.furniture_name = 'Table'
      )
), range_stats AS (
    SELECT
        district,
        rent_price_range,
        SUM(favorite_users_count) AS favorite_sum,
        COUNT(*) AS n
    FROM filtered
    GROUP BY district, rent_price_range
)
SELECT
    district,
    rent_price_range,
    favorite_sum::NUMERIC / NULLIF(n, 0) AS avg_users_per_property,
    SUM(favorite_sum) OVER (PARTITION BY district)::NUMERIC
      / NULLIF(SUM(n) OVER (PARTITION BY district), 0)
      AS district_avg_users_per_property
FROM range_stats
ORDER BY district, avg_users_per_property;

-- Query D
-- Properties with bed and table in university cities: city/month/year average
-- rent, average rent per square meter, and cumulative YTD city average rent.
WITH eligible AS (
    SELECT
        f.*,
        p.surface_m2,
        l.city,
        d.year_num,
        d.month_num
    FROM fact_property_weekly_snapshot AS f
    JOIN dim_date AS d ON d.date_key = f.date_key
    JOIN dim_property AS p ON p.property_key = f.property_key
    JOIN dim_location AS l ON l.location_key = p.location_key
    WHERE l.university_present = TRUE
      AND f.is_available = TRUE
      AND EXISTS (
          SELECT 1 FROM bridge_property_furniture b
          JOIN dim_furniture x ON x.furniture_key = b.furniture_key
          WHERE b.property_key = p.property_key AND x.furniture_name = 'Bed'
      )
      AND EXISTS (
          SELECT 1 FROM bridge_property_furniture b
          JOIN dim_furniture x ON x.furniture_key = b.furniture_key
          WHERE b.property_key = p.property_key AND x.furniture_name = 'Table'
      )
), monthly AS (
    SELECT
        city,
        year_num,
        month_num,
        SUM(monthly_rent) AS rent_sum,
        COUNT(*) AS n,
        AVG(monthly_rent / NULLIF(surface_m2, 0)) AS avg_rent_per_m2
    FROM eligible
    GROUP BY city, year_num, month_num
)
SELECT
    city,
    year_num,
    month_num,
    rent_sum / NULLIF(n, 0) AS avg_monthly_rent,
    avg_rent_per_m2,
    SUM(rent_sum) OVER (PARTITION BY city, year_num ORDER BY month_num)
      / NULLIF(SUM(n) OVER (PARTITION BY city, year_num ORDER BY month_num), 0)
      AS avg_rent_since_year_start
FROM monthly
ORDER BY city, year_num, month_num;

-- Query E
-- Piedmont, Sep-Nov 2004: city average rent and corresponding province average.
WITH city_stats AS (
    SELECT
        l.province,
        l.city,
        SUM(f.monthly_rent) AS rent_sum,
        COUNT(*) AS n
    FROM fact_property_weekly_snapshot AS f
    JOIN dim_date AS d ON d.date_key = f.date_key
    JOIN dim_property AS p ON p.property_key = f.property_key
    JOIN dim_location AS l ON l.location_key = p.location_key
    WHERE d.year_num = 2004
      AND d.month_num IN (9, 10, 11)
      AND l.region = 'Piedmont'
      AND f.is_available = TRUE
    GROUP BY l.province, l.city
)
SELECT
    province,
    city,
    rent_sum / NULLIF(n, 0) AS city_avg_monthly_rent,
    SUM(rent_sum) OVER (PARTITION BY province)
      / NULLIF(SUM(n) OVER (PARTITION BY province), 0)
      AS province_avg_monthly_rent
FROM city_stats
ORDER BY province, city;

-- Query F
-- 2004, university cities, bed + table: monthly city rent and rent/m2.
SELECT
    l.city,
    d.month_num,
    AVG(f.monthly_rent) AS avg_monthly_rent,
    AVG(f.monthly_rent / NULLIF(p.surface_m2, 0)) AS avg_monthly_rent_per_m2
FROM fact_property_weekly_snapshot AS f
JOIN dim_date AS d ON d.date_key = f.date_key
JOIN dim_property AS p ON p.property_key = f.property_key
JOIN dim_location AS l ON l.location_key = p.location_key
WHERE d.year_num = 2004
  AND l.university_present = TRUE
  AND f.is_available = TRUE
  AND EXISTS (
      SELECT 1 FROM bridge_property_furniture b
      JOIN dim_furniture x ON x.furniture_key = b.furniture_key
      WHERE b.property_key = p.property_key AND x.furniture_name = 'Bed'
  )
  AND EXISTS (
      SELECT 1 FROM bridge_property_furniture b
      JOIN dim_furniture x ON x.furniture_key = b.furniture_key
      WHERE b.property_key = p.property_key AND x.furniture_name = 'Table'
  )
GROUP BY l.city, d.month_num
ORDER BY l.city, d.month_num;

-- =============================================================================
-- 3. PERFORMANCE STRUCTURES
-- =============================================================================

CREATE MATERIALIZED VIEW mv_city_month_property_market AS
SELECT
    l.location_key,
    l.city,
    l.province,
    l.region,
    d.year_num,
    d.month_num,
    SUM(f.monthly_rent) AS rent_sum,
    COUNT(*) FILTER (WHERE f.is_available) AS available_observations,
    COUNT(*) AS observation_count
FROM fact_property_weekly_snapshot AS f
JOIN dim_date AS d ON d.date_key = f.date_key
JOIN dim_property AS p ON p.property_key = f.property_key
JOIN dim_location AS l ON l.location_key = p.location_key
GROUP BY l.location_key, l.city, l.province, l.region, d.year_num, d.month_num;

CREATE INDEX idx_property_snapshot_date_property
    ON fact_property_weekly_snapshot (date_key, property_key);
CREATE INDEX idx_property_location_type
    ON dim_property (location_key, property_type);
CREATE INDEX idx_location_geo_university
    ON dim_location (region, province, city, university_present);
CREATE INDEX idx_bridge_property_furniture
    ON bridge_property_furniture (property_key, furniture_key);
