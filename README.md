# CDC Chronic Disease Indicators — SQL Analytics Pipeline

An end-to-end SQL project transforming 50,000+ raw CDC BRFSS records into a normalized star-schema database and extracting public health insights on U.S. obesity and physical activity trends.

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

- **String cleaning:** `REPLACE()` to strip commas from numeric fields
- **Type casting:** `CAST(... AS DECIMAL)` and `CAST(... AS SIGNED)`
- **Null handling:** `NULLIF()` to prevent empty-string truncation errors
- **Deduplication:** `INSERT IGNORE INTO ... SELECT DISTINCT`

## Analytical Queries

**Q1 — Geographic Hotspots:** Top 5 states by average obesity rate
```sql
GROUP BY l.location_desc
ORDER BY Avg_Obesity_Rate DESC
LIMIT 5;
```
→ Mississippi (35.84%), West Virginia (35.53%), Louisiana (35.01%), Oklahoma (34.17%), Arkansas (34.08%)

---

**Q2 — Gender Disparity:** National male vs. female obesity comparison using `AVG()` and `GROUP BY`
```sql
WHERE s.category = 'Sex'
  AND l.location_abbr = 'US'
GROUP BY s.segment;
```
→ Female: 28.04% (n=1,263,256) | Male: 28.44% (n=931,352)

---

**Q3 — National Outliers:** States with overweight rate above the national average, using a CTE and `HAVING`
```sql
WITH national_avg AS (
    SELECT ROUND(AVG(f.data_value), 2) AS nat_avg ...
)
...
HAVING ROUND(AVG(f.data_value), 2) > n.nat_avg;
```
→ 28 states identified (national benchmark: 35.55%)

---

**Q4 — Data Coverage:** Record count and geographic coverage by stratification category
```sql
COUNT(f.fact_id) AS Record_Count,
COUNT(DISTINCT l.location_abbr) AS States_Covered
GROUP BY s.category;
```
→ Income: 8,431 records | Age: 7,136 records | All 55 locations covered across every category

---

**Q5 — Reusable Reporting View:** Persistent view for high-risk obesity areas (rate > 35%)
```sql
CREATE OR REPLACE VIEW v_high_risk_obesity_areas AS
SELECT ...
WHERE f.question_key = 'Q036'
  AND f.data_value > 35.0;
```
→ Enables recurring public health reporting without rewriting complex joins

## Key Findings

- Southern and Appalachian states consistently lead in obesity prevalence, with Mississippi at 35.84%
- National male and female obesity rates are nearly identical (~28%), suggesting sex is not a primary driver
- 28 of 55 states/territories exceed the national overweight benchmark of 35.55%
- Income is the most densely recorded stratification variable (8,431 records), making it the strongest candidate for socioeconomic subgroup analysis

## Tools & Data Source

- **Database:** MySQL 8.0 / MySQL Workbench
- **Dataset:** CDC Nutrition, Physical Activity, and Obesity — Behavioral Risk Factor Surveillance System (BRFSS), downloaded from [data.cdc.gov](https://data.cdc.gov)
- **Course:** DATA521 — Introduction to Data Management, Emory University, Fall 2025
