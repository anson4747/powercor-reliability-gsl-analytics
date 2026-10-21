SELECT
    edb, interruption_identifier, start_datetime, end_datetime,
    number_of_icps_interrupted,
    COUNT(*) AS copies
FROM stg.nz_interruptions
GROUP BY edb, subnetwork, row_num, interruption_identifier, circuit_location, feeder,
         start_datetime, end_datetime, saidi_value, saifi_value,
         number_of_icps_interrupted, icp_interruption_minutes,
         planned_or_unplanned, cause
HAVING COUNT(*) > 1
ORDER BY copies DESC;


ALTER TABLE stg.nz_interruptions
ADD load_row_id INT IDENTITY(1,1) NOT NULL;
GO

SELECT TOP 5 load_row_id, edb, interruption_identifier
FROM stg.nz_interruptions;



USE PowerNetworks;
GO

INSERT INTO ref.validation_rules VALUES
('V07','Exact duplicate record','Critical',
 'Every column identical to an earlier row',
 'Outage counted twice: SAIDI, SAIFI and GSL totals overstated');
GO

CREATE TABLE clean.exception_log (
    exception_id  INT IDENTITY(1,1) PRIMARY KEY,
    rule_id       varchar(10)  NOT NULL,
    load_row_id   INT          NOT NULL,
    edb           nvarchar(255),
    detail        nvarchar(400),
    logged_at     datetime2    NOT NULL DEFAULT SYSDATETIME()
);
GO


INSERT INTO clean.exception_log (rule_id, load_row_id, edb, detail)
SELECT
    'V01',
    load_row_id,
    edb,
    CONCAT('Start ', start_datetime, ' / End ', end_datetime,
           ' / Duration ', DATEDIFF(MINUTE, start_datetime, end_datetime), ' min')
FROM stg.nz_interruptions
WHERE end_datetime <= start_datetime;

SELECT * FROM clean.exception_log;

INSERT INTO ref.validation_rules VALUES
('V08','Momentary event in sustained data','Medium',
 'Duration greater than 0 and under 60 seconds',
 'Momentary interruptions belong in MAIFI, not SAIDI/SAIFI; counting them inflates SAIFI');


 INSERT INTO clean.exception_log (rule_id, load_row_id, edb, detail)
SELECT
    'V03',                                                              -- ① changed
    load_row_id,
    edb,
    CONCAT('Duration ', DATEDIFF(MINUTE, start_datetime, end_datetime),
           ' min (', DATEDIFF(DAY, start_datetime, end_datetime), ' days)')  -- ② changed
FROM stg.nz_interruptions
WHERE DATEDIFF(MINUTE, start_datetime, end_datetime) > 10080;          -- ③ changed


INSERT INTO clean.exception_log (rule_id, load_row_id, edb, detail)
SELECT
    'V04',                                       -- ① which rule ID?
    load_row_id,
    edb,
    CONCAT('Customers interrupted = ', number_of_icps_interrupted)
FROM stg.nz_interruptions
WHERE number_of_icps_interrupted IS NULL
   OR number_of_icps_interrupted <= 0;          -- ③ which comparison means "zero or less"?


SELECT rule_id, COUNT(*) AS failures
FROM clean.exception_log
GROUP BY rule_id
ORDER BY rule_id;


INSERT INTO clean.exception_log (rule_id, load_row_id, edb, detail)
SELECT
    'V05',                                       -- ① which rule ID?
    load_row_id,
    edb,
    CONCAT('Customers interrupted = ', number_of_icps_interrupted)
FROM stg.nz_interruptions
WHERE number_of_icps_interrupted <> FLOOR(number_of_icps_interrupted);    


INSERT INTO clean.exception_log (rule_id, load_row_id, edb, detail)
SELECT
    'V08',                                                   -- ① rule ID
    load_row_id,
    edb,
    CONCAT('Duration ', DATEDIFF(SECOND, start_datetime, end_datetime), ' seconds')
FROM stg.nz_interruptions
WHERE DATEDIFF(SECOND, start_datetime, end_datetime) > 0   -- ② more than 0
  AND DATEDIFF(SECOND, start_datetime, end_datetime) < 60; -- ③ less than 60

  SELECT rule_id, COUNT(*) AS failures
FROM clean.exception_log GROUP BY rule_id ORDER BY rule_id;

-- 1. Is V07 in the catalogue?
SELECT * FROM ref.validation_rules;

-- 2. Exact column names in the staging table
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'stg'
  AND TABLE_NAME = 'nz_interruptions'
ORDER BY ORDINAL_POSITION;

SELECT TOP 6
    load_row_id,
    row_num,
    interruption_identifier,
    start_datetime,
    end_datetime
FROM stg.nz_interruptions
WHERE edb LIKE 'Westpower%'
ORDER BY interruption_identifier, load_row_id;


SELECT STRING_AGG(COLUMN_NAME, ', ')
       WITHIN GROUP (ORDER BY ORDINAL_POSITION) AS partition_list
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'stg'
  AND TABLE_NAME = 'nz_interruptions'
  AND COLUMN_NAME <> 'load_row_id';   -- why exclude this one?


  WITH numbered AS (
    SELECT
        load_row_id,
        edb,
        interruption_identifier,
        ROW_NUMBER() OVER (
            PARTITION BY edb, disc_yr, subnetwork, row_num, interruption_identifier, circuit_location, feeder, start_datetime, end_datetime, saidi_value, saifi_value, number_of_icps_interrupted, icp_interruption_minutes, planned_or_unplanned, cause, explanation, section, sect_no, source, schedule   -- blank 1: what defines "identical"?
            ORDER BY   load_row_id  -- blank 2: which copy counts as the original?
        ) AS rn
    FROM stg.nz_interruptions
)
SELECT edb, COUNT(*) AS extra_copies
FROM numbered
WHERE rn >=2                 -- blank 3: which rows are the copies?
GROUP BY edb;


DELETE FROM clean.exception_log WHERE rule_id = 'V07';

WITH numbered AS (
    SELECT
        load_row_id,
        edb,
        interruption_identifier,
        ROW_NUMBER() OVER (
            PARTITION BY edb, disc_yr, subnetwork, row_num, interruption_identifier, circuit_location, feeder, start_datetime, end_datetime, saidi_value, saifi_value, number_of_icps_interrupted, icp_interruption_minutes, planned_or_unplanned, cause, explanation, section, sect_no, source, schedule
            ORDER BY load_row_id
        ) AS rn
    FROM stg.nz_interruptions
)
INSERT INTO clean.exception_log (rule_id, load_row_id, edb, detail)
SELECT
    'V07',
    load_row_id,
    edb,
    CONCAT('Duplicate of ', interruption_identifier, ', copy ', rn)
FROM numbered
WHERE rn >= 2;

SELECT TOP 5 * FROM clean.exception_log WHERE rule_id = 'V07';


SELECT rule_id, COUNT(*) AS failures
FROM clean.exception_log GROUP BY rule_id ORDER BY rule_id;


SELECT TOP 10
    load_row_id,
    edb,
    number_of_icps_interrupted AS customers,
    DATEDIFF(SECOND, start_datetime, end_datetime) / 60.0 AS duration_min,
    number_of_icps_interrupted
        * DATEDIFF(SECOND, start_datetime, end_datetime) / 60.0 AS expected_minutes,
    icp_interruption_minutes AS reported_minutes
FROM stg.nz_interruptions
WHERE DATEDIFF(SECOND, start_datetime, end_datetime) > 0
ORDER BY NEWID();


WITH calc AS (
    SELECT
        edb,
        DATEDIFF(SECOND, start_datetime, end_datetime) / 60.0 AS duration_min,
        number_of_icps_interrupted
            * DATEDIFF(SECOND, start_datetime, end_datetime) / 60.0 AS expected_min,
        icp_interruption_minutes AS reported_min
    FROM stg.nz_interruptions
    WHERE DATEDIFF(SECOND, start_datetime, end_datetime) > 0
      AND number_of_icps_interrupted > 1
)
SELECT
    edb,
    COUNT(*) AS events,
    SUM(CASE WHEN ABS(reported_min - expected_min) <= 0.05 * expected_min
             THEN 1 ELSE 0 END) AS matches_total,
    SUM(CASE WHEN ABS(reported_min - duration_min) <= 0.05 * duration_min
             THEN 1 ELSE 0 END) AS matches_per_customer,
    SUM(CASE WHEN reported_min < 0.95 * expected_min
              AND ABS(reported_min - duration_min) > 0.05 * duration_min
             THEN 1 ELSE 0 END) AS lower_other,
    SUM(CASE WHEN reported_min > 1.05 * expected_min
             THEN 1 ELSE 0 END) AS higher
FROM calc
GROUP BY edb
ORDER BY edb;