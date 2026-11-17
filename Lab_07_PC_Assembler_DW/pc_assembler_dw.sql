/*
===============================================================================
Lab 07 - PC Assembler Data Warehouse
Dialect: PostgreSQL 14+
Source: 07-DW-project-PC-text.pdf
===============================================================================

The assignment contains two business processes, so the solution uses two fact
 tables:
- FACT_COMPONENT_PURCHASE for procurement/assembly inputs
- FACT_PC_SALE for configuration sales and warranty returns

Supplier and retailer attributes that may change over time are modeled as SCD2.
*/

-- =============================================================================
-- 1. DIMENSIONS AND FACT TABLES
-- =============================================================================

CREATE TABLE dim_date (
    date_key            INTEGER PRIMARY KEY,
    full_date           DATE NOT NULL UNIQUE,
    month_num           SMALLINT NOT NULL,
    two_month_period    SMALLINT NOT NULL,
    trimester           SMALLINT NOT NULL,
    four_month_period   SMALLINT NOT NULL,
    semester            SMALLINT NOT NULL,
    year_num            SMALLINT NOT NULL
);

CREATE TABLE dim_supplier (
    supplier_key        INTEGER PRIMARY KEY,
    supplier_code       VARCHAR(60) NOT NULL,
    supplier_name       VARCHAR(160) NOT NULL,
    region              VARCHAR(120) NOT NULL,
    geographical_area   VARCHAR(30) NOT NULL,
    valid_from          DATE NOT NULL,
    valid_to            DATE,
    is_current          BOOLEAN NOT NULL,
    UNIQUE (supplier_code, valid_from)
);

CREATE TABLE dim_component (
    component_key       INTEGER PRIMARY KEY,
    component_code      VARCHAR(80) NOT NULL UNIQUE,
    component_type      VARCHAR(30) NOT NULL
                        CHECK (component_type IN ('RAM','HD','CPU','GRAPHIC_BOARD')),
    supplier_code       VARCHAR(60) NOT NULL,
    supplier_name       VARCHAR(160) NOT NULL,
    memory_capacity     VARCHAR(60),
    ram_type            VARCHAR(60),
    access_time         VARCHAR(60),
    physical_dimensions VARCHAR(80),
    cpu_type            VARCHAR(80),
    clock_speed         VARCHAR(60),
    max_resolution      VARCHAR(60)
);

CREATE TABLE dim_configuration (
    configuration_key   INTEGER PRIMARY KEY,
    configuration_code  VARCHAR(80) NOT NULL UNIQUE,
    market_segment      VARCHAR(100),
    ram_component_key   INTEGER NOT NULL REFERENCES dim_component(component_key),
    hd_component_key    INTEGER NOT NULL REFERENCES dim_component(component_key),
    cpu_component_key   INTEGER NOT NULL REFERENCES dim_component(component_key),
    graphic_component_key INTEGER NOT NULL REFERENCES dim_component(component_key)
);

CREATE TABLE dim_retailer (
    retailer_key        INTEGER PRIMARY KEY,
    retailer_code       VARCHAR(60) NOT NULL,
    retailer_name       VARCHAR(160) NOT NULL,
    number_of_shops     INTEGER NOT NULL CHECK (number_of_shops >= 0),
    valid_from          DATE NOT NULL,
    valid_to            DATE,
    is_current          BOOLEAN NOT NULL,
    UNIQUE (retailer_code, valid_from)
);

CREATE TABLE fact_component_purchase (
    purchase_fact_key   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    date_key            INTEGER NOT NULL REFERENCES dim_date(date_key),
    component_key       INTEGER NOT NULL REFERENCES dim_component(component_key),
    supplier_key        INTEGER NOT NULL REFERENCES dim_supplier(supplier_key),
    quantity            BIGINT NOT NULL CHECK (quantity >= 0),
    component_cost      NUMERIC(18,2) NOT NULL CHECK (component_cost >= 0),
    delivery_cost       NUMERIC(18,2) NOT NULL CHECK (delivery_cost >= 0)
);

CREATE TABLE fact_pc_sale (
    sale_fact_key       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    date_key            INTEGER NOT NULL REFERENCES dim_date(date_key),
    configuration_key   INTEGER NOT NULL REFERENCES dim_configuration(configuration_key),
    retailer_key        INTEGER NOT NULL REFERENCES dim_retailer(retailer_key),
    production_cost     NUMERIC(18,2) NOT NULL CHECK (production_cost >= 0),
    selling_revenue     NUMERIC(18,2) NOT NULL CHECK (selling_revenue >= 0),
    sold_quantity       BIGINT NOT NULL CHECK (sold_quantity >= 0),
    defective_quantity  BIGINT NOT NULL CHECK (defective_quantity >= 0)
);

-- =============================================================================
-- 2. FREQUENT QUERIES
-- =============================================================================

-- Query A
-- CPUs bought from north-Italy suppliers by four-month period and CPU type.
SELECT
    d.year_num,
    d.four_month_period,
    c.cpu_type,
    SUM(f.quantity) AS cpu_pieces_bought
FROM fact_component_purchase AS f
JOIN dim_date AS d ON d.date_key = f.date_key
JOIN dim_component AS c ON c.component_key = f.component_key
JOIN dim_supplier AS s ON s.supplier_key = f.supplier_key
WHERE d.year_num IN (2005, 2006)
  AND c.component_type = 'CPU'
  AND s.geographical_area = 'North Italy'
GROUP BY d.year_num, d.four_month_period, c.cpu_type
ORDER BY d.year_num, d.four_month_period, c.cpu_type;

-- Query B
-- Lowest production-cost/revenue ratio configuration per year, only when RAM
-- and CPU originate from the same supplier.
WITH config_year AS (
    SELECT
        d.year_num,
        cfg.configuration_code,
        SUM(f.production_cost) / NULLIF(SUM(f.selling_revenue), 0) AS cost_price_ratio
    FROM fact_pc_sale AS f
    JOIN dim_date AS d ON d.date_key = f.date_key
    JOIN dim_configuration AS cfg ON cfg.configuration_key = f.configuration_key
    JOIN dim_component AS ram ON ram.component_key = cfg.ram_component_key
    JOIN dim_component AS cpu ON cpu.component_key = cfg.cpu_component_key
    WHERE ram.supplier_code = cpu.supplier_code
    GROUP BY d.year_num, cfg.configuration_code
), ranked AS (
    SELECT
        *,
        RANK() OVER (PARTITION BY year_num ORDER BY cost_price_ratio ASC) AS rnk
    FROM config_year
)
SELECT year_num, configuration_code, cost_price_ratio
FROM ranked
WHERE rnk = 1
ORDER BY year_num, configuration_code;

-- Query C
-- Pieces bought in March 2007 and in the entire year, per component.
SELECT
    c.component_code,
    SUM(f.quantity) FILTER (WHERE d.month_num = 3) AS pieces_march_2007,
    SUM(f.quantity) AS pieces_whole_2007
FROM fact_component_purchase AS f
JOIN dim_date AS d ON d.date_key = f.date_key
JOIN dim_component AS c ON c.component_key = f.component_key
WHERE d.year_num = 2007
GROUP BY c.component_code
ORDER BY c.component_code;

-- Query D - explicitly required by the assignment
-- 2002: defective percentage for configurations whose RAM supplier is
-- IntelligenceDevice.
SELECT
    cfg.configuration_code,
    100.0 * SUM(f.defective_quantity) / NULLIF(SUM(f.sold_quantity), 0)
        AS defective_product_pct
FROM fact_pc_sale AS f
JOIN dim_date AS d ON d.date_key = f.date_key
JOIN dim_configuration AS cfg ON cfg.configuration_key = f.configuration_key
JOIN dim_component AS ram ON ram.component_key = cfg.ram_component_key
WHERE d.year_num = 2002
  AND ram.supplier_name = 'IntelligenceDevice'
GROUP BY cfg.configuration_code
ORDER BY cfg.configuration_code;

-- Query E - explicitly required by the assignment
-- 2007 RAM: period total cost and cumulative cost by supplier geographical area
-- and RAM type.
WITH period_cost AS (
    SELECT
        s.geographical_area,
        c.ram_type,
        d.four_month_period,
        SUM(f.component_cost + f.delivery_cost) AS total_cost
    FROM fact_component_purchase AS f
    JOIN dim_date AS d ON d.date_key = f.date_key
    JOIN dim_component AS c ON c.component_key = f.component_key
    JOIN dim_supplier AS s ON s.supplier_key = f.supplier_key
    WHERE d.year_num = 2007
      AND c.component_type = 'RAM'
    GROUP BY s.geographical_area, c.ram_type, d.four_month_period
)
SELECT
    geographical_area,
    ram_type,
    four_month_period,
    total_cost,
    SUM(total_cost) OVER (
        PARTITION BY geographical_area, ram_type
        ORDER BY four_month_period
    ) AS cumulative_cost
FROM period_cost
ORDER BY geographical_area, ram_type, four_month_period;

-- Query F
-- Different configurations sold to each retailer by month in 2007.
SELECT
    r.retailer_name,
    d.month_num,
    COUNT(DISTINCT f.configuration_key) AS distinct_configurations_sold
FROM fact_pc_sale AS f
JOIN dim_date AS d ON d.date_key = f.date_key
JOIN dim_retailer AS r ON r.retailer_key = f.retailer_key
WHERE d.year_num = 2007
  AND f.sold_quantity > 0
GROUP BY r.retailer_name, d.month_num
ORDER BY r.retailer_name, d.month_num;

-- Query G
-- Delivery cost by supplier geographical area and year.
SELECT
    s.geographical_area,
    d.year_num,
    SUM(f.delivery_cost) AS total_delivery_cost
FROM fact_component_purchase AS f
JOIN dim_date AS d ON d.date_key = f.date_key
JOIN dim_supplier AS s ON s.supplier_key = f.supplier_key
GROUP BY s.geographical_area, d.year_num
ORDER BY s.geographical_area, d.year_num;

-- Query H - explicitly required by the assignment
-- Suppliers with >100,000 components bought in 2003; report second two-month
-- period totals by supplier and component type.
WITH eligible_suppliers AS (
    SELECT f.supplier_key
    FROM fact_component_purchase AS f
    JOIN dim_date AS d ON d.date_key = f.date_key
    WHERE d.year_num = 2003
    GROUP BY f.supplier_key
    HAVING SUM(f.quantity) > 100000
)
SELECT
    s.supplier_name,
    c.component_type,
    SUM(f.quantity) AS pieces_bought,
    SUM(f.component_cost + f.delivery_cost) AS total_cost
FROM fact_component_purchase AS f
JOIN eligible_suppliers AS e ON e.supplier_key = f.supplier_key
JOIN dim_date AS d ON d.date_key = f.date_key
JOIN dim_supplier AS s ON s.supplier_key = f.supplier_key
JOIN dim_component AS c ON c.component_key = f.component_key
WHERE d.year_num = 2003
  AND d.two_month_period = 2
GROUP BY s.supplier_name, c.component_type
ORDER BY s.supplier_name, c.component_type;

-- =============================================================================
-- 3. PERFORMANCE STRUCTURES
-- =============================================================================

CREATE MATERIALIZED VIEW mv_component_purchase_period AS
SELECT
    f.component_key,
    f.supplier_key,
    d.year_num,
    d.month_num,
    d.two_month_period,
    d.four_month_period,
    SUM(f.quantity) AS quantity,
    SUM(f.component_cost) AS component_cost,
    SUM(f.delivery_cost) AS delivery_cost
FROM fact_component_purchase AS f
JOIN dim_date AS d ON d.date_key = f.date_key
GROUP BY f.component_key, f.supplier_key, d.year_num, d.month_num,
         d.two_month_period, d.four_month_period;

CREATE MATERIALIZED VIEW mv_pc_sales_month AS
SELECT
    f.configuration_key,
    f.retailer_key,
    d.year_num,
    d.month_num,
    d.two_month_period,
    d.trimester,
    SUM(f.production_cost) AS production_cost,
    SUM(f.selling_revenue) AS selling_revenue,
    SUM(f.sold_quantity) AS sold_quantity,
    SUM(f.defective_quantity) AS defective_quantity
FROM fact_pc_sale AS f
JOIN dim_date AS d ON d.date_key = f.date_key
GROUP BY f.configuration_key, f.retailer_key, d.year_num, d.month_num,
         d.two_month_period, d.trimester;

CREATE INDEX idx_purchase_date_supplier_component
    ON fact_component_purchase (date_key, supplier_key, component_key);
CREATE INDEX idx_sale_date_configuration_retailer
    ON fact_pc_sale (date_key, configuration_key, retailer_key);

-- =============================================================================
-- 4. SLOWLY CHANGING DIMENSIONS
-- =============================================================================

-- SCD Type 2 is appropriate for attributes whose historical value matters.
-- Examples:
--   * retailer number_of_shops
--   * supplier region / geographical_area if a supplier changes location
--
-- ETL rule (conceptual):
-- 1. Close the current row by setting valid_to and is_current = FALSE.
-- 2. Insert a new dimension row with a new surrogate key and new valid_from.
-- 3. New fact rows reference the new surrogate key; historical facts keep the
--    old key and therefore preserve the historical context.
