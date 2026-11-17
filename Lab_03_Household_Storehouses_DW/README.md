# Lab 03 - Household Appliance Storehouses Data Warehouse

This exercise designs a warehouse for monitoring **inventory value, product quantities, storehouse capacity, free surface, and insurance scope** across Italian storehouses.

## Files

- `03-DW-project-household-text.pdf` - original exercise
- `household_storehouses_dw.sql` - physical warehouse design, all frequent queries, and performance structures
- `README.md` - design notes and assumptions

## Warehouse design

Two fact tables are used because the measures have different grains:

- `fact_inventory_daily` - one row per **date x storehouse x product type**
- `fact_storehouse_surface_daily` - one row per **date x storehouse**

This separation is important. If storehouse surface were repeated for every product type, aggregating across products would incorrectly multiply the available and free surface.

Main dimensions:

- Date: day, month, trimester, four-month period, semester, year
- Storehouse
- Location: city, province, region
- Product: type and category
- Insurance policy, connected to covered storehouses through a bridge table

## Queries implemented

All six frequent queries from the PDF are included:

- Turin inventory value and 7-day moving average
- city-level daily free-surface ranking
- storehouse free-surface percentages
- monthly average daily inventory value by storehouse
- regional average daily inventory value
- monthly regional average free-surface percentage

## Performance choices

The solution creates a materialized daily storehouse inventory view because several queries repeatedly aggregate product-level rows to storehouse-day level. Indexes support the principal joins and date/location filters.

With only about 100 storehouses and two years of data, very large numbers of pre-aggregated materialized views would add maintenance cost without much benefit. The selected view targets the most repeated aggregation directly.

## SQL dialect

PostgreSQL 14+. The analytical logic is standard SQL and can be ported to other warehouse platforms.
