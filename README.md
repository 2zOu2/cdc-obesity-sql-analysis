# CDC Chronic Disease Indicators — SQL Analytics Pipeline

An SQL project transforming 50,000+ raw CDC BRFSS records into a 
normalized star-schema database and extracting public health insights on U.S. 
obesity and physical activity trends.

## Project Structure
```
cdc-obesity-sql-analysis/
├── final_project_DATA521.sql   # Full pipeline: DDL, ETL, and all queries
├── results/
│   ├── q1_obesity_by_state.csv
│   ├── q2_gender_disparity.csv
│   ├── q3_national_outliers.csv
│   ├── q4_data_coverage.csv
│   └── q5_high_risk_view.csv
└── README.md
```
## Database Design

Star schema with 1 fact table and 3 dimension tables built in MySQL 8.0:

| Table | Rows | Description |
|---|---|---|
| `fact_health_data` | 30,816 | Core metrics: data value, sample size |
| `dim_location` | 55 | State names and geo-coordinates |
| `dim_question` | 9 | CDC survey question text |
| `dim_stratification` | 31 | Demographics: age, sex, income, race |

## ETL Process

Raw CSV → `staging_data_raw` → dimension tables → fact table

- String cleaning: `REPLACE()` to strip commas from numeric fields
- Type casting: `CAST(... AS DECIMAL)` and `CAST(... AS SIGNED)`
- Null handling: `NULLIF()` to prevent empty-string truncation errors
- Deduplication: `INSERT IGNORE INTO ... SELECT DISTINCT`

## Analytical Queries

**Q1 — Geographic Hotspots:** Top 5 states by average obesity rate  
→ Mississippi (35.84%), West Virginia (35.53%), Louisiana (35.01%)

**Q2 — Gender Disparity:** National male vs. female obesity comparison  
→ Female: 28.04% (n=1,263,256) | Male: 28.44% (n=931,352)

**Q3 — National Outliers:** States with overweight rate above national average (35.55%)  
→ 28 states identified using CTE + `HAVING` clause

**Q4 — Data Coverage:** Record count and state coverage by stratification category  
→ Income: 8,431 records | Age: 7,136 records — all 55 locations covered

**Q5 — Reusable View:** `CREATE OR REPLACE VIEW v_high_risk_obesity_areas`  
→ Filters obesity rate > 35% for recurring public health reporting

## Tools
MySQL 8.0 · MySQL Workbench · CDC BRFSS Open Data
