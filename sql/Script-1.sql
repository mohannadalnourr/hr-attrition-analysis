
-- HR ATTRITION ANALYSIS 
-- ============================================
-- cleaning phase
-- ============================================

-- drop constant columns — these never change, so they can't explain anything
ALTER TABLE hr_data
DROP COLUMN employeecount;

ALTER TABLE hr_data
DROP COLUMN over18;

ALTER TABLE hr_data
DROP COLUMN standardhours;

-- convert attrition (Yes/No) into a numeric flag so we can use AVG() to get rates
ALTER TABLE hr_data
ADD COLUMN attrition_flag INT;

UPDATE hr_data
SET attrition_flag = (
    CASE
        WHEN attrition = 'Yes' THEN 1
        ELSE 0
    END
);

-- convert overTime (Yes/No) the same way
ALTER TABLE hr_data
ADD COLUMN overtime_flag INT;

UPDATE hr_data
SET overtime_flag = (
    CASE
        WHEN overtime = 'Yes' THEN 1
        ELSE 0
    END
);

-- check for duplicate employee records — employeenumber should be unique
SELECT employeenumber, COUNT(employeenumber)
FROM hr_data
GROUP BY employeenumber
HAVING COUNT(employeenumber) > 1;
-- Result: 0 rows returned, confirming no duplicates

-- Baseline attrition rate — every other number gets compared back to this
SELECT ROUND(AVG(attrition_flag), 2) AS attrition_rate
FROM hr_data;
-- Result: 0.16 (16%)



-- Q1 — Overall attrition rate by department and job role


-- By department
SELECT department, ROUND(AVG(attrition_flag),2) AS attrition_rate, COUNT(*) AS emp_count
FROM hr_data
GROUP BY department
ORDER BY attrition_rate DESC;

-- By job role
SELECT jobrole, ROUND(AVG(attrition_flag),2) AS attrition_rate, COUNT(*) AS emp_count
FROM hr_data
GROUP BY jobrole
ORDER BY attrition_rate DESC;



-- Q2 — Attrition by overtime and income level


-- By overtime
SELECT overtime, ROUND(AVG(attrition_flag),2) AS attrition_rate, COUNT(*) AS emp_count
FROM hr_data
GROUP BY overtime
ORDER BY attrition_rate DESC;

-- By income bucket (buckets decided before looking at results)
SELECT
    CASE
        WHEN monthlyincome BETWEEN 0 AND 2999 THEN 'Low Income'
        WHEN monthlyincome BETWEEN 3000 AND 5999 THEN 'Lower-Mid Income'
        WHEN monthlyincome BETWEEN 6000 AND 8999 THEN 'Upper-Mid Income'
        ELSE 'High Income'
    END AS income_level,
    ROUND(AVG(attrition_flag),2) AS attrition_rate,
    COUNT(*) AS emp_count
FROM hr_data
GROUP BY income_level
ORDER BY attrition_rate DESC;

-- Overtime + income combined — checking for a compounding effect
SELECT overtime,
    CASE
        WHEN monthlyincome BETWEEN 0 AND 2999 THEN 'Low Income'
        WHEN monthlyincome BETWEEN 3000 AND 5999 THEN 'Lower-Mid Income'
        WHEN monthlyincome BETWEEN 6000 AND 8999 THEN 'Upper-Mid Income'
        ELSE 'High Income'
    END AS income_level,
    ROUND(AVG(attrition_flag),2) AS attrition_rate,
    COUNT(*) AS emp_count
FROM hr_data
GROUP BY overtime, income_level
ORDER BY attrition_rate DESC;

-- Job role + overtime + income combined — found real signal here, but many small groups
-- (used to identify Sales Rep / Lab Tech / Research Scientist + overtime + low income as trustworthy hot spots)
SELECT jobrole, overtime,
    CASE
        WHEN monthlyincome BETWEEN 0 AND 2999 THEN 'Low Income'
        WHEN monthlyincome BETWEEN 3000 AND 5999 THEN 'Lower-Mid Income'
        WHEN monthlyincome BETWEEN 6000 AND 8999 THEN 'Upper-Mid Income'
        ELSE 'High Income'
    END AS income_level,
    ROUND(AVG(attrition_flag),2) AS attrition_rate,
    COUNT(*) AS emp_count
FROM hr_data
GROUP BY jobrole, overtime, income_level
ORDER BY attrition_rate DESC;



-- Q3 — Attrition by age group and tenure group

-- By tenure bucket
SELECT
    CASE
        WHEN yearsatcompany BETWEEN 0 AND 2 THEN 'brand new'
        WHEN yearsatcompany BETWEEN 3 AND 5 THEN 'established'
        WHEN yearsatcompany BETWEEN 6 AND 10 THEN 'long-tenured'
        ELSE 'veteran'
    END AS tenure_group,
    ROUND(AVG(attrition_flag),2) AS attrition_rate,
    COUNT(*) AS emp_count
FROM hr_data
GROUP BY tenure_group
ORDER BY attrition_rate DESC;

-- By age bucket
SELECT
    CASE
        WHEN age BETWEEN 18 AND 25 THEN 'Young Adult'
        WHEN age BETWEEN 26 AND 35 THEN 'Adult'
        WHEN age BETWEEN 36 AND 45 THEN 'Middle-Aged'
        ELSE 'Older'
    END AS age_group,
    ROUND(AVG(attrition_flag),2) AS attrition_rate,
    COUNT(*) AS emp_count
FROM hr_data
GROUP BY age_group
ORDER BY attrition_rate DESC;

-- Age + tenure combined — checking if age was a real driver or just riding along with tenure
-- (finding: tenure is the real driver — "brand new" is high attrition regardless of age)
SELECT
    (CASE
        WHEN age BETWEEN 18 AND 25 THEN 'Young Adult'
        WHEN age BETWEEN 26 AND 35 THEN 'Adult'
        WHEN age BETWEEN 36 AND 45 THEN 'Middle-Aged'
        ELSE 'Older'
    END) AS age_group,
    (CASE
        WHEN yearsatcompany BETWEEN 0 AND 2 THEN 'brand new'
        WHEN yearsatcompany BETWEEN 3 AND 5 THEN 'established'
        WHEN yearsatcompany BETWEEN 6 AND 10 THEN 'long-tenured'
        ELSE 'veteran'
    END) AS tenure_group,
    ROUND(AVG(attrition_flag),2) AS attrition_rate,
    COUNT(*) AS emp_count
FROM hr_data
GROUP BY age_group, tenure_group
ORDER BY attrition_rate DESC;


-- Q4 — Attrition by job satisfaction score

-- Satisfaction is already a clean 1-4 scale, no bucketing needed
SELECT jobsatisfaction, ROUND(AVG(attrition_flag),2) AS attrition_rate, COUNT(*) AS emp_count
FROM hr_data
GROUP BY jobsatisfaction
ORDER BY attrition_rate DESC;
-- Note: clean pattern at the extremes (1 highest, 4 lowest), but 2 and 3 are basically flat


-- Q5 — Simple 3-factor risk score
-- Factors chosen: overtime, low income (<$3k), new tenure (<=2 years)
-- These were the three strongest, most independent signals from Q1-Q4=

SELECT
    (overtime_flag
     + CASE WHEN monthlyincome < 3000 THEN 1 ELSE 0 END
     + CASE WHEN yearsatcompany <= 2 THEN 1 ELSE 0 END) AS risk_score,
    ROUND(AVG(attrition_flag),2) AS attrition_rate,
    COUNT(*) AS emp_count
FROM hr_data
GROUP BY risk_score
ORDER BY risk_score;
-- Result: clean staircase — 0: 7%, 1: 14%, 2: 35%, 3: 67%
-- Employees with all 3 risk factors leave at ~10x the rate of those with none