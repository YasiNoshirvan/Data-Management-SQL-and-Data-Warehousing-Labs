# Lab 04 - House Search Data Warehouse

This project models weekly rental-advert snapshots for an Italian property-search website. The analysis combines **market availability, rent levels, geography, university presence, property characteristics, furniture, and user favorites**.

## Files

- `04-DW-project-HouseSearch-text.pdf` - original assignment
- `house_search_dw.sql` - warehouse DDL, six analytical queries, and performance structures
- `README.md` - design explanation

## Grain and model

The central fact table is `fact_property_weekly_snapshot`, with one row per **property x weekly snapshot**. This directly reflects the source process described in the PDF: adverts are refreshed every Monday.

Measures include:

- availability
- monthly rent
- rent-price range
- number of users who added the property to favorites

Dimensions describe time, property characteristics, and geography. Furniture is a many-to-many property characteristic, so it is modeled through `bridge_property_furniture` rather than adding a fixed set of furniture columns.

## Important query-design detail

When a query requires properties that contain several furniture items at once (for example bed + fridge + table), the solution uses independent `EXISTS` predicates. This avoids multiplying fact rows through the furniture bridge and therefore protects rent and favorite-count measures from double counting.

## Queries implemented

All frequent queries from the PDF are included, covering:

- monthly and year-to-date rent averages
- weekly availability shares and city ranking
- favorite-list analysis by district and rent range
- rent per square meter
- city-versus-province comparisons
- filters on university cities and furniture combinations

## Performance

A city-month materialized view supports repeated market-level reporting. Additional indexes target weekly snapshots, geography, property type, university filters, and furniture membership.

## SQL dialect

PostgreSQL 14+. The model is intended as a portfolio-quality warehouse design; loading/ETL code is outside the scope of the original assignment.
