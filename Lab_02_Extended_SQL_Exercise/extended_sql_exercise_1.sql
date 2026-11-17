/*
===============================================================================
Lab 02 - Extended SQL Exercise
Dialect: PostgreSQL / ANSI SQL window-function style
Source: ExtendedSQL-Exercise-1-text-2021.pdf
===============================================================================
*/

-- -----------------------------------------------------------------------------
-- Query 1
-- Category totals and ranks by revenue and number of sold items.
-- -----------------------------------------------------------------------------
WITH category_totals AS (
    SELECT
        c.CategoryID,
        c.CategoryName,
        SUM(s.TotAmount) AS total_sale_amount,
        SUM(s.NumSoldItems) AS total_sold_items
    FROM Sales AS s
    JOIN Category AS c
        ON c.CategoryID = s.ItemCategoryID
    GROUP BY c.CategoryID, c.CategoryName
)
SELECT
    CategoryID,
    CategoryName,
    total_sale_amount,
    total_sold_items,
    RANK() OVER (ORDER BY total_sale_amount DESC) AS sale_amount_rank,
    RANK() OVER (ORDER BY total_sold_items DESC) AS sold_items_rank
FROM category_totals
ORDER BY total_sold_items ASC, CategoryID;

-- -----------------------------------------------------------------------------
-- Query 2
-- Province totals and rank within each region.
-- -----------------------------------------------------------------------------
WITH province_totals AS (
    SELECT
        c.Province,
        c.Region,
        SUM(s.TotAmount) AS total_sale_amount
    FROM Sales AS s
    JOIN Customer AS c
        ON c.CustomerID = s.CustomerID
    GROUP BY c.Province, c.Region
)
SELECT
    Province,
    Region,
    total_sale_amount,
    RANK() OVER (
        PARTITION BY Region
        ORDER BY total_sale_amount DESC
    ) AS province_rank_in_region
FROM province_totals
ORDER BY Region, province_rank_in_region, Province;

-- -----------------------------------------------------------------------------
-- Query 3
-- Province-month totals and rank across provinces for the same month.
-- Year is retained to make the query safe for multi-year data.
-- -----------------------------------------------------------------------------
WITH province_monthly AS (
    SELECT
        c.Province,
        c.Region,
        t.Year,
        t.Month,
        SUM(s.TotAmount) AS monthly_sale_amount
    FROM Sales AS s
    JOIN Customer AS c
        ON c.CustomerID = s.CustomerID
    JOIN TIME AS t
        ON t.TimeID = s.TimeID
    GROUP BY c.Province, c.Region, t.Year, t.Month
)
SELECT
    Province,
    Region,
    Year,
    Month,
    monthly_sale_amount,
    RANK() OVER (
        PARTITION BY Year, Month
        ORDER BY monthly_sale_amount DESC
    ) AS province_rank_for_month
FROM province_monthly
ORDER BY Year, Month, province_rank_for_month, Province;

-- -----------------------------------------------------------------------------
-- Query 4
-- Region-month totals and cumulative sales from the start of each year.
-- -----------------------------------------------------------------------------
WITH region_monthly AS (
    SELECT
        c.Region,
        t.Year,
        t.Month,
        SUM(s.TotAmount) AS monthly_sale_amount
    FROM Sales AS s
    JOIN Customer AS c
        ON c.CustomerID = s.CustomerID
    JOIN TIME AS t
        ON t.TimeID = s.TimeID
    GROUP BY c.Region, t.Year, t.Month
)
SELECT
    Region,
    Year,
    Month,
    monthly_sale_amount,
    SUM(monthly_sale_amount) OVER (
        PARTITION BY Region, Year
        ORDER BY Month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_sale_amount
FROM region_monthly
ORDER BY Region, Year, Month;
