# Lab 06 - International Parcels Service Data Warehouse

This lab designs a warehouse for an international parcel-delivery company operating through more than 200 branches. The analytical focus is on **income, weight, volume, routes, branch districts, goods categories, and carrier types**.

## Files

- `06-DW-project-parcels-text.pdf` - original assignment
- `parcels_service_dw.sql` - complete dimensional model and all seven frequent queries
- `README.md` - design notes

## Fact grain

A dispatch can contain multiple routes, while the assignment explicitly asks for route-level analysis. The warehouse therefore uses `fact_delivery_route`, one row per **dispatch-route segment**, with route-attributable income, weight, and volume.

This grain allows direct analysis by:

- departure and destination geography
- branch and branch district
- carrier type
- goods category
- date hierarchy

## Query coverage

All seven frequent queries are implemented, including:

- average daily income and YTD cumulative income
- income per unit of volume/weight
- destination province versus state comparisons
- route-level monthly analysis
- branch-district volume ranking
- sea-carrier half-year ratios
- four-month-period flow analysis

## Performance

A route-month materialized view pre-aggregates the three core additive measures while retaining all dimensions needed by the frequent queries. Indexes support carrier, branch, and role-playing location lookups.

## Assumption

The source states that a dispatch can contain several routes but asks for route-level income, volume, and weight. The solution therefore assumes these measures can be allocated to individual route segments during ETL. Without that allocation, route-level financial analysis would be ambiguous.

## SQL dialect

PostgreSQL 14+.
