CREATE TABLE public.staging_er_data (
    patient_id            VARCHAR(50),
    admission_datetime    TIMESTAMP,
    first_initial         VARCHAR(5),
    last_name             VARCHAR(100),
    gender                VARCHAR(10),
    age                   INTEGER,
    race                  VARCHAR(50),
    department            VARCHAR(100),
    admission_flag        VARCHAR(10),
    satisfaction_score    INTEGER,
    wait_time             INTEGER,
    patients_cm           VARCHAR(10)
);
DROP TABLE IF EXISTS public.staging_er_data;


CREATE TABLE public.staging_er_data (
    patient_id            VARCHAR(50),
    admission_datetime    VARCHAR(50),   
    first_initial         VARCHAR(5),
    last_name             VARCHAR(100),
    gender                VARCHAR(10),
    age                   INTEGER,
    race                  VARCHAR(50),
    department            VARCHAR(100),
    admission_flag        VARCHAR(10),
    satisfaction_score    INTEGER,
    wait_time             INTEGER,
    patients_cm           VARCHAR(10)
);


SELECT * 
FROM staging_er_data
LIMIT 5;

SELECT COUNT(*) AS total_patients
FROM staging_er_data;

SELECT 
    COUNT(*) AS total_rows,
    COUNT(satisfaction_score) AS satisfaction_available
FROM staging_er_data;


CREATE TABLE er_data_cleaned (
    patient_id            VARCHAR(20),
    admission_datetime    TIMESTAMP,
    first_initial         CHAR(1),
    last_name             VARCHAR(50),
    gender                CHAR(1),
    age                   INTEGER,
    race                  VARCHAR(100),
    department            VARCHAR(100),
    admission_flag        BOOLEAN,
    satisfaction_score    INTEGER,
    wait_time             INTEGER);
--Standardize Gender
UPDATE staging_er_data
SET gender = CASE
    WHEN gender = 'M' THEN 'Male'
    WHEN gender = 'F' THEN 'Female'
    ELSE 'Other'
END;
--Create Patient Name
ALTER TABLE staging_er_data
ADD patient_name VARCHAR(100);

UPDATE staging_er_data
SET patient_name = CONCAT(first_initial, '. ', last_name);
--Convert Admission Flag
ALTER TABLE staging_er_data
ADD admission_status VARCHAR(20);

UPDATE public.staging_er_data
SET admission_status = CASE
    WHEN admission_flag ILIKE 'Y%' THEN 'Admitted'
    ELSE 'Not Admitted'
END;
--Split Date & Time
-- 1️⃣ Add new columns (if not already added)
ALTER TABLE staging_er_data
ADD COLUMN visit_date DATE,
ADD COLUMN visit_time TIME;


UPDATE staging_er_data
SET visit_date = TO_TIMESTAMP(admission_datetime, 'DD-MM-YYYY HH24:MI')::DATE,
    visit_time = TO_TIMESTAMP(admission_datetime, 'DD-MM-YYYY HH24:MI')::TIME;
--Create Age Groups

ALTER TABLE staging_er_data
ADD COLUMN age_group VARCHAR(20);


UPDATE staging_er_data
SET age_group = CASE
    WHEN age IS NULL THEN 'Unknown'
    WHEN age BETWEEN 0 AND 9 THEN '0–9'
    WHEN age BETWEEN 10 AND 19 THEN '10–19'
    WHEN age BETWEEN 20 AND 29 THEN '20–29'
    WHEN age BETWEEN 30 AND 39 THEN '30–39'
    WHEN age BETWEEN 40 AND 49 THEN '40–49'
    WHEN age BETWEEN 50 AND 59 THEN '50–59'
    WHEN age BETWEEN 60 AND 69 THEN '60–69'
    ELSE '70+'
END;
--Wait Time SLA Logic

ALTER TABLE staging_er_data
ADD COLUMN wait_time_status VARCHAR(20);


UPDATE staging_er_data
SET wait_time_status = CASE
    WHEN wait_time IS NULL THEN 'Unknown'
    WHEN wait_time <= 30 THEN 'On Time'
    ELSE 'Delayed'
END;

CREATE TABLE dim_calendar (
    date_id DATE PRIMARY KEY,
    year INT,
    month INT,
    month_name VARCHAR(15),
    weekday_name VARCHAR(15)
);

INSERT INTO dim_calendar (date_id, year, month, month_name, weekday_name)
SELECT
    d::DATE,
    EXTRACT(YEAR FROM d)::INT,
    EXTRACT(MONTH FROM d)::INT,
    TO_CHAR(d, 'FMMonth'),
    TO_CHAR(d, 'FMDay')
FROM generate_series(
        '2023-01-01'::DATE, 
        '2024-12-31'::DATE, 
        INTERVAL '1 day'
     ) AS d;
--Total Patients
	SELECT COUNT(DISTINCT patient_id) AS total_patients
FROM staging_er_data;
--Average Wait Time
SELECT ROUND(AVG(wait_time),2) AS avg_wait_time
FROM staging_er_data;
--Average Satisfaction Score
SELECT ROUND(AVG(satisfaction_score),2) AS avg_satisfaction
FROM staging_er_data
WHERE satisfaction_score IS NOT NULL;
--On-Time vs Delayed
SELECT wait_time_status, COUNT(*) AS patients
FROM staging_er_data
GROUP BY wait_time_status;
--Department Referrals
SELECT department, COUNT(*) AS total_patients
FROM staging_er_data
GROUP BY department
ORDER BY total_patients DESC;

--Age Group Distribution
SELECT 
    CASE 
        WHEN wait_time < 20 THEN 'Low Wait'
        WHEN wait_time BETWEEN 20 AND 40 THEN 'Medium Wait'
        ELSE 'High Wait'
    END AS wait_category,
    ROUND(AVG(satisfaction_score),2) AS avg_satisfaction
FROM er_data_cleaned
GROUP BY wait_category;

--Monthly Trend
SELECT
    c.year,
    c.month_name,
    COUNT(*) AS total_patients
FROM staging_er_data s
JOIN dim_calendar c
ON s.visit_date = c.date_id
GROUP BY c.year, c.month_name, c.month
ORDER BY c.year, c.month;



