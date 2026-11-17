# Lab 11 - Vehicle Rental Data Warehouse

This exercise builds a warehouse for a vehicle-rental company that wants to analyze **revenue and traveled distance** across routes, vehicle models, options, payment methods, client profiles, and time.

## Files

- `Vehicle_rental_DW_text.pdf` - original assignment
- `vehicle_rental_dw.sql` - warehouse design and both frequent queries
- `README.md` - design notes and query assumptions

## Model

The main fact table is one row per rental. Departure and arrival use the same location dimension in two different roles.

Vehicle options are open-ended in the assignment, so they are not stored as fixed columns. Instead, `bridge_vehicle_option` supports any number of options per model.

Client domicile points to the same location dimension and enables province/region analysis of customer profiles.

## Query A
For credit-card rentals, the query produces:

- average kilometers per rental
- cumulative kilometers from the beginning of the year
- average daily kilometers

by month, client type, and domicile province.

## Query B
For truck rentals, it calculates:

- revenue per kilometer
- share of yearly revenue
- share of revenue in the corresponding departure region

The phrase "corresponding departure region" is not temporally qualified in the PDF. The implementation compares a province-month to its region for the **same year and month**, which preserves the query's requested monthly grain.

## SQL dialect

PostgreSQL 14+.
