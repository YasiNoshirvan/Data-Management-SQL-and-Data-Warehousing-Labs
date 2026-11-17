# Data Management Labs

A curated portfolio of Data Management laboratory exercises covering **Extended SQL, analytical SQL, dimensional modeling, data warehousing, OLAP-style queries, materialized views, indexing, and slowly changing dimensions**.

The original exercise sheets are preserved in each lab folder. The SQL solutions were reconstructed from the assignment specifications and organized as readable, documented portfolio code.

---

Each lab folder contains exactly:

1. the original assignment PDF;
2. one complete `.sql` solution file;
3. one lab-specific `README.md` explaining the model, assumptions, and analytical techniques.

---

## Labs

| Lab | Topic | Main concepts |
|---:|---|---|
| 01 | Extended SQL | Aggregation, ranking, cumulative windows |
| 02 | Sales analytical SQL | Partitioned ranking, running totals |
| 03 | Household storehouses | Multi-fact DW, inventory, surface utilization, materialized views |
| 04 | House-search adverts | Weekly snapshots, furniture bridge, KPI analytics |
| 05 | Hotel chain | Room-state snapshots, income, feature bridge |
| 06 | International parcels | Route-grain fact table, role-playing locations, profitability ratios |
| 07 | PC assembler | Fact constellation, procurement and sales, SCD Type 2 |
| 08 | Craft beer | Production/storage flows, two date roles, hop bridge |
| 09 | Food delivery | Delivery analytics, time slots, restaurant-category bridge |
| 10 | Event tickets | Purchase/event date roles, tour-genre bridge |
| 11 | Vehicle rental | Route analysis, client profiles, model-option bridge |
| 12 | Versioning services | Commit analytics, repository-language bridge, developer teams |

---

## SQL style

The reconstructed data-warehouse solutions use **PostgreSQL 14+ compatible SQL**. The analytical logic relies on standard concepts available in most modern SQL platforms:

- `GROUP BY`
- common table expressions (`WITH`)
- `RANK()`
- cumulative and partitioned window functions
- conditional aggregation
- role-playing dimensions
- bridge tables for many-to-many dimensional relationships
- materialized views and indexes where requested by the assignment

The repository focuses on **warehouse design and analytical SQL**. It does not include ETL pipelines or source datasets, because those were not part of the provided lab material.

---

## Modeling principles used

Across the exercises, the solutions follow a few consistent rules:

- Define the fact-table grain before choosing measures.
- Separate facts when measures exist at different grains.
- Avoid double counting across many-to-many attributes by using bridge tables and `EXISTS` filters.
- Use surrogate keys for dimensional models.
- Preserve historical dimensional context with SCD Type 2 when the assignment requires changing dimensions.
- Use weighted ratios such as `SUM(revenue) / SUM(volume)` where ratio-of-sums is analytically more appropriate than averaging row-level ratios.
- Add pre-aggregation only where the frequent-query workload justifies it.

---

## Notes on source material

A few source PDFs contain minor naming inconsistencies or leftover text from other exercises. These are not silently rewritten. The corresponding lab README documents each assumption explicitly so the implementation remains traceable to the original assignment.

---

## Course

**Course:** Data Management  
**Institution:** Politecnico di Torino  
**Topics:** SQL, Extended SQL, Data Warehousing, OLAP, dimensional modeling

## Author

**Yasaman Noshirvanbaboli**  
GitHub: [YasiNoshirvan](https://github.com/YasiNoshirvan)
