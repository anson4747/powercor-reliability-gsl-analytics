CREATE OR ALTER VIEW clean.interruptions AS
SELECT
    s.load_row_id,
    s.edb,
    s.disc_yr,
    s.feeder,
    s.interruption_identifier,
    s.planned_or_unplanned,
    s.start_datetime,
    s.end_datetime,
    DATEDIFF(SECOND, s.start_datetime, s.end_datetime) / 60.0 AS duration_min,
    s.number_of_icps_interrupted AS customers,
    s.icp_interruption_minutes,
    s.saidi_value,
    s.saifi_value,
    s.cause AS raw_cause,
    COALESCE(m.standard_cause, N'Unmapped') AS standard_cause
FROM stg.nz_interruptions s
LEFT JOIN ref.cause_mapping m ON s.cause = m.raw_cause
WHERE NOT EXISTS (
    SELECT 1
    FROM clean.exception_log e
    JOIN ref.validation_rules r ON e.rule_id = r.rule_id
    WHERE e.load_row_id = s.load_row_id
      AND r.severity = 'Critical'
);
GO

-- Check 1: row count
SELECT COUNT(*) AS clean_rows FROM clean.interruptions;

-- Check 2: Westpower SAIDI after removing duplicates
SELECT edb, SUM(saidi_value) AS saidi
FROM clean.interruptions
WHERE edb = 'Westpower'
GROUP BY edb;