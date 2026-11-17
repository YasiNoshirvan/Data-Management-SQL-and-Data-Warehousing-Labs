[README.md](https://github.com/user-attachments/files/34973979/README.md)
# Lab 09 - Food Delivery Data Warehouse

This lab models food-delivery operations for analytics on **delivery time, rider distance, revenue, restaurant categories, destination geography, payment method, transport mode, and time slot**.

## Files

- `Food_delivery_DW_text.pdf` - original assignment
- `food_delivery_dw.sql` - warehouse schema and both frequent queries
- `README.md` - design documentation

## Dimensional model

`fact_delivery` uses one row per delivery. Core measures are:

- distance in kilometers
- delivery time in minutes
- revenue

Restaurant category is many-to-many, so a bridge table is used. The Pizza filter in Query B is implemented with `EXISTS` to avoid duplicate delivery rows when a restaurant belongs to multiple categories.

## Query A
For Partner orders, the solution calculates:

- average delivery time
- average number of deliveries per one-hour time slot
- average kilometers per minute
- trimester rank within each transport mode

The hourly average is computed by first counting deliveries in each actual date/time-slot combination and then averaging those counts.

## Query B
For restaurants associated with the Pizza category:

- cumulative revenue from the start of each trimester
- average revenue per delivery
- revenue percentage relative to all payment methods for the same city/month

## SQL dialect

PostgreSQL 14+.
