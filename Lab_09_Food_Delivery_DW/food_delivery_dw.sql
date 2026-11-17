/*
===============================================================================
Lab 09 - Food Delivery Data Warehouse
Dialect: PostgreSQL 14+
Source: Food_delivery_DW_text.pdf
===============================================================================
*/

-- =============================================================================
-- 1. DIMENSIONS AND FACT TABLE
-- =============================================================================

CREATE TABLE dim_date (
    date_key            INTEGER PRIMARY KEY,
    full_date           DATE NOT NULL UNIQUE,
    month_num           SMALLINT NOT NULL,
    two_month_period    SMALLINT NOT NULL,
    trimester           SMALLINT NOT NULL,
    four_month_period   SMALLINT NOT NULL,
    semester            SMALLINT NOT NULL,
    year_num            SMALLINT NOT NULL,
    is_working_day      BOOLEAN NOT NULL
);

CREATE TABLE dim_time_slot (
    time_slot_key   INTEGER PRIMARY KEY,
    time_slot_label VARCHAR(20) NOT NULL UNIQUE,
    start_hour      SMALLINT NOT NULL,
    end_hour        SMALLINT NOT NULL
);

CREATE TABLE dim_location (
    location_key    INTEGER PRIMARY KEY,
    neighborhood    VARCHAR(150),
    city            VARCHAR(120) NOT NULL,
    province        VARCHAR(120),
    region          VARCHAR(120),
    UNIQUE (neighborhood, city, province, region)
);

CREATE TABLE dim_restaurant (
    restaurant_key  INTEGER PRIMARY KEY,
    restaurant_id   VARCHAR(60) NOT NULL UNIQUE,
    restaurant_name VARCHAR(180) NOT NULL,
    location_key    INTEGER NOT NULL REFERENCES dim_location(location_key)
);

CREATE TABLE dim_restaurant_category (
    category_key    INTEGER PRIMARY KEY,
    category_name   VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE bridge_restaurant_category (
    restaurant_key  INTEGER NOT NULL REFERENCES dim_restaurant(restaurant_key),
    category_key    INTEGER NOT NULL REFERENCES dim_restaurant_category(category_key),
    PRIMARY KEY (restaurant_key, category_key)
);

CREATE TABLE dim_order_type (
    order_type_key  INTEGER PRIMARY KEY,
    order_type      VARCHAR(60) NOT NULL UNIQUE
);

CREATE TABLE dim_payment_method (
    payment_key     INTEGER PRIMARY KEY,
    payment_method  VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE dim_transport (
    transport_key   INTEGER PRIMARY KEY,
    transport_mode  VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE fact_delivery (
    delivery_key            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    restaurant_key          INTEGER NOT NULL REFERENCES dim_restaurant(restaurant_key),
    order_type_key          INTEGER NOT NULL REFERENCES dim_order_type(order_type_key),
    destination_location_key INTEGER NOT NULL REFERENCES dim_location(location_key),
    payment_key             INTEGER NOT NULL REFERENCES dim_payment_method(payment_key),
    transport_key           INTEGER NOT NULL REFERENCES dim_transport(transport_key),
    date_key                INTEGER NOT NULL REFERENCES dim_date(date_key),
    time_slot_key           INTEGER NOT NULL REFERENCES dim_time_slot(time_slot_key),
    distance_km             NUMERIC(12,3) NOT NULL CHECK (distance_km >= 0),
    delivery_minutes        NUMERIC(12,2) NOT NULL CHECK (delivery_minutes > 0),
    revenue                 NUMERIC(14,2) NOT NULL CHECK (revenue >= 0)
);

-- =============================================================================
-- 2. FREQUENT QUERIES
-- =============================================================================

-- Query A
-- Partner orders: analysis by transport mode and trimester.
WITH partner_deliveries AS (
    SELECT f.*, d.year_num, d.trimester
    FROM fact_delivery AS f
    JOIN dim_order_type AS o ON o.order_type_key = f.order_type_key
    JOIN dim_date AS d ON d.date_key = f.date_key
    WHERE o.order_type = 'Partner order'
), slot_counts AS (
    SELECT
        transport_key,
        year_num,
        trimester,
        date_key,
        time_slot_key,
        COUNT(*) AS deliveries_in_hour
    FROM partner_deliveries
    GROUP BY transport_key, year_num, trimester, date_key, time_slot_key
), trimester_stats AS (
    SELECT
        p.transport_key,
        p.year_num,
        p.trimester,
        AVG(p.delivery_minutes) AS avg_delivery_minutes,
        SUM(p.distance_km) / NULLIF(SUM(p.delivery_minutes), 0) AS avg_km_per_minute
    FROM partner_deliveries AS p
    GROUP BY p.transport_key, p.year_num, p.trimester
), avg_slot AS (
    SELECT
        transport_key,
        year_num,
        trimester,
        AVG(deliveries_in_hour) AS avg_deliveries_per_time_slot
    FROM slot_counts
    GROUP BY transport_key, year_num, trimester
)
SELECT
    t.transport_mode,
    s.year_num,
    s.trimester,
    s.avg_delivery_minutes,
    a.avg_deliveries_per_time_slot,
    s.avg_km_per_minute,
    RANK() OVER (
        PARTITION BY s.transport_key
        ORDER BY s.avg_km_per_minute DESC
    ) AS trimester_rank_by_km_per_minute
FROM trimester_stats AS s
JOIN avg_slot AS a
  ON a.transport_key = s.transport_key
 AND a.year_num = s.year_num
 AND a.trimester = s.trimester
JOIN dim_transport AS t ON t.transport_key = s.transport_key
ORDER BY t.transport_mode, trimester_rank_by_km_per_minute;

-- Query B
-- Restaurants with Pizza category: payment method x delivery city x month.
WITH monthly AS (
    SELECT
        f.payment_key,
        pm.payment_method,
        dl.city AS delivery_city,
        d.year_num,
        d.trimester,
        d.month_num,
        SUM(f.revenue) AS monthly_revenue,
        COUNT(*) AS deliveries
    FROM fact_delivery AS f
    JOIN dim_payment_method AS pm ON pm.payment_key = f.payment_key
    JOIN dim_location AS dl ON dl.location_key = f.destination_location_key
    JOIN dim_date AS d ON d.date_key = f.date_key
    JOIN dim_restaurant AS r ON r.restaurant_key = f.restaurant_key
    WHERE EXISTS (
        SELECT 1
        FROM bridge_restaurant_category b
        JOIN dim_restaurant_category c ON c.category_key = b.category_key
        WHERE b.restaurant_key = r.restaurant_key
          AND LOWER(c.category_name) = 'pizza'
    )
    GROUP BY f.payment_key, pm.payment_method, dl.city,
             d.year_num, d.trimester, d.month_num
)
SELECT
    payment_method,
    delivery_city,
    year_num,
    month_num,
    monthly_revenue,
    SUM(monthly_revenue) OVER (
        PARTITION BY payment_key, delivery_city, year_num, trimester
        ORDER BY month_num
    ) AS cumulative_revenue_from_trimester_start,
    monthly_revenue / NULLIF(deliveries, 0) AS avg_revenue_per_delivery,
    100.0 * monthly_revenue
      / NULLIF(SUM(monthly_revenue) OVER (
            PARTITION BY delivery_city, year_num, month_num
        ), 0) AS pct_revenue_across_payment_methods
FROM monthly
ORDER BY delivery_city, year_num, month_num, payment_method;

-- =============================================================================
-- 3. INDEXES
-- =============================================================================

CREATE INDEX idx_delivery_date_transport
    ON fact_delivery (date_key, transport_key);
CREATE INDEX idx_delivery_restaurant
    ON fact_delivery (restaurant_key);
CREATE INDEX idx_delivery_destination_payment
    ON fact_delivery (destination_location_key, payment_key);
CREATE INDEX idx_restaurant_category_bridge
    ON bridge_restaurant_category (restaurant_key, category_key);
