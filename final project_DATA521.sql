CREATE DATABASE IF NOT EXISTS cdc_final_project;
USE cdc_final_project;

-- This table was used to match raw CSV structure.
CREATE TABLE staging_data_raw (
    YearStart INT,
    YearEnd INT,
    LocationAbbr VARCHAR(10),
    LocationDesc VARCHAR(100),
    Datasource VARCHAR(100),
    Class VARCHAR(100),
    Topic VARCHAR(100),
    Question VARCHAR(255),
    Data_Value_Unit VARCHAR(50),
    Data_Value_Type VARCHAR(50),
    Data_Value VARCHAR(50),  
    Data_Value_Alt VARCHAR(50),
    Data_Value_Footnote_Symbol VARCHAR(50),
    Data_Value_Footnote VARCHAR(255),
    Low_Confidence_Limit VARCHAR(50),
    High_Confidence_Limit VARCHAR(50),
    Sample_Size VARCHAR(50), 
    Total VARCHAR(100),
    `Age(years)` VARCHAR(100), 
    Education VARCHAR(100),
    Sex VARCHAR(100),
    Income VARCHAR(100),
    `Race/Ethnicity` VARCHAR(100), 
    GeoLocation VARCHAR(100),
    ClassID VARCHAR(50),
    TopicID VARCHAR(50),
    QuestionID VARCHAR(50),
    DataValueTypeID VARCHAR(50),
    LocationID INT,
    StratificationCategory1 VARCHAR(100),
    Stratification1 VARCHAR(100),
    StratificationCategoryId1 VARCHAR(50),
    StratificationID1 VARCHAR(50)
);

-- 1. Dimension: Location
CREATE TABLE dim_location (
    location_key INT AUTO_INCREMENT PRIMARY KEY,
    location_abbr VARCHAR(10) NOT NULL,
    location_desc VARCHAR(100),
    geo_location VARCHAR(100),
    UNIQUE(location_abbr)
);

-- 2. Dimension: Question
CREATE TABLE dim_question (
    question_key VARCHAR(20) PRIMARY KEY, 
    class VARCHAR(100),
    topic VARCHAR(100),
    question_text TEXT
);

-- 3. Dimension: Stratification (Demographics)
CREATE TABLE dim_stratification (
    strat_key VARCHAR(20) PRIMARY KEY, 
    category VARCHAR(50), 
    segment VARCHAR(100)  
);

-- 4. Fact Table: Health Data
CREATE TABLE fact_health_data (
    fact_id INT AUTO_INCREMENT PRIMARY KEY,
    year_start INT,
    location_key INT,
    question_key VARCHAR(20),
    strat_key VARCHAR(20),
    data_value DECIMAL(10, 1),
    sample_size INT,
    
    -- Foreign Key Constraints
    CONSTRAINT fk_loc FOREIGN KEY (location_key) REFERENCES dim_location(location_key),
    CONSTRAINT fk_qst FOREIGN KEY (question_key) REFERENCES dim_question(question_key),
    CONSTRAINT fk_str FOREIGN KEY (strat_key) REFERENCES dim_stratification(strat_key)
);


-- 1. Populate Locations
INSERT IGNORE INTO dim_location (location_abbr, location_desc, geo_location)
SELECT DISTINCT LocationAbbr, LocationDesc, GeoLocation
FROM staging_data_raw 
WHERE LocationAbbr IS NOT NULL AND LocationAbbr <> '';

-- 2. Populate Questions
INSERT IGNORE INTO dim_question (question_key, class, topic, question_text)
SELECT DISTINCT QuestionID, Class, Topic, Question
FROM staging_data_raw 
WHERE QuestionID IS NOT NULL;

-- 3. Populate Stratifications
INSERT IGNORE INTO dim_stratification (strat_key, category, segment)
SELECT DISTINCT StratificationID1, StratificationCategory1, Stratification1
FROM staging_data_raw 
WHERE StratificationID1 IS NOT NULL;

SET SESSION sql_mode = 'NO_ENGINE_SUBSTITUTION';
-- 4. Populate Fact Table
INSERT INTO fact_health_data (year_start, location_key, question_key, strat_key, data_value, sample_size)
SELECT 
    s.YearStart,
    l.location_key,
    s.QuestionID,
    s.StratificationID1,
    -- Remove commas 
    CAST(NULLIF(REPLACE(s.Data_Value, ',', ''), '') AS DECIMAL(10, 2)), 
    -- Remove commas 
    CAST(NULLIF(REPLACE(s.Sample_Size, ',', ''), '') AS SIGNED)
FROM staging_data_raw s
JOIN dim_location l ON s.LocationAbbr = l.location_abbr
WHERE NULLIF(s.Data_Value, '') is NOT NULL;

drop table staging_data_raw;

-- Q1: Which 5 states have the highest average Obesity rates recorded in the dataset?
SELECT 
    l.location_desc AS State,
    ROUND(AVG(f.data_value), 2) AS Avg_Obesity_Rate
FROM fact_health_data f
JOIN dim_location l ON f.location_key = l.location_key
JOIN dim_question q ON f.question_key = q.question_key
JOIN dim_stratification s ON f.strat_key = s.strat_key
WHERE q.question_key = 'Q036' -- filter for Obesity 
  AND s.strat_key = 'OVERALL' -- filter for overall population
  AND l.location_abbr != 'US' 
GROUP BY l.location_desc
ORDER BY Avg_Obesity_Rate DESC
LIMIT 5;

-- Q2: How do obesity rates compare between Males and Females on a national level?
SELECT 
    s.segment AS Gender,
    ROUND(AVG(f.data_value), 2) AS Avg_Obesity_Rate,
    SUM(f.sample_size) AS Total_Sample_Size
FROM fact_health_data f
JOIN dim_stratification s ON f.strat_key = s.strat_key
JOIN dim_location l ON f.location_key = l.location_key
JOIN dim_question q ON f.question_key = q.question_key
WHERE s.category = 'Sex'
  AND l.location_abbr = 'US' -- National Level only
  AND q.question_key = 'Q036'
GROUP BY s.segment;

-- Q3: Which states have an "Overweight" rate (Q037) that is higher than the national average?

WITH national_avg AS (
    SELECT ROUND(AVG(f.data_value), 2) AS nat_avg
    FROM fact_health_data f
    JOIN dim_location l ON f.location_key = l.location_key
    WHERE l.location_abbr = 'US'
      AND f.question_key = 'Q037'
      AND f.strat_key = 'OVERALL'
)

SELECT
    l.location_desc AS State,
    ROUND(AVG(f.data_value), 2) AS State_Overweight_Rate,
    n.nat_avg AS National_Overweight_Rate
FROM fact_health_data f
JOIN dim_location l ON f.location_key = l.location_key
JOIN dim_question q ON f.question_key = q.question_key
CROSS JOIN national_avg n
WHERE q.question_key = 'Q037'
  AND f.strat_key = 'OVERALL'
  AND l.location_abbr != 'US'
GROUP BY l.location_desc, n.nat_avg
HAVING ROUND(AVG(f.data_value), 2) > n.nat_avg
ORDER BY State_Overweight_Rate DESC;

-- Q4: How many data points (records) exist for each stratification category (e.g., Income, Education, Age) to ensure we have enough data for analysis?
SELECT 
    s.category AS Stratification_Type,
    COUNT(f.fact_id) AS Record_Count,
    COUNT(DISTINCT l.location_abbr) AS States_Covered
FROM fact_health_data f
JOIN dim_stratification s ON f.strat_key = s.strat_key
JOIN dim_location l ON f.location_key = l.location_key
GROUP BY s.category
ORDER BY Record_Count DESC;

-- Q5 Create a reusable view that summarizes "High Risk" locations (Obesity > 35%) for easy exporting.
CREATE OR REPLACE VIEW v_high_risk_obesity_areas AS
SELECT 
    l.location_desc,
    f.year_start,
    s.segment AS demographic_group,
    f.data_value AS obesity_rate
FROM fact_health_data f
JOIN dim_location l ON f.location_key = l.location_key
JOIN dim_stratification s ON f.strat_key = s.strat_key
WHERE f.question_key = 'Q036'
  AND f.data_value > 35.0;

-- Execute
SELECT * FROM v_high_risk_obesity_areas LIMIT 10;




