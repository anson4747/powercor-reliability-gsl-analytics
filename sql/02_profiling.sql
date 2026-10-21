SELECT
    edb,
    COUNT(*) AS events,
    SUM(CASE WHEN planned_or_unplanned = 'Unplanned' THEN 1 ELSE 0 END) AS unplanned_events
FROM stg.nz_interruptions
GROUP BY edb
ORDER BY events DESC;

SELECT
    planned_or_unplanned,
    cause,
    COUNT(*) AS events
FROM stg.nz_interruptions
GROUP BY planned_or_unplanned, cause
ORDER BY events DESC;


SELECT
    MIN(DATEDIFF(MINUTE, start_datetime, end_datetime)) AS shortest_min,
    AVG(DATEDIFF(MINUTE, start_datetime, end_datetime)) AS average_min,
    MAX(DATEDIFF(MINUTE, start_datetime, end_datetime)) AS longest_min
FROM stg.nz_interruptions;


SELECT TOP 10
    edb,
    interruption_identifier,
    start_datetime,
    end_datetime,
    DATEDIFF(MINUTE, start_datetime, end_datetime) AS duration_min,
    number_of_icps_interrupted,
    cause
FROM stg.nz_interruptions
ORDER BY duration_min ASC;

SELECT
    interruption_identifier,
    start_datetime,
    DAY(start_datetime)   AS start_day,
    MONTH(start_datetime) AS start_month
FROM stg.nz_interruptions
WHERE edb = 'MainPower NZ'
ORDER BY interruption_identifier;


SELECT
    DAY(start_datetime) AS day_of_month,
    COUNT(*) AS events
FROM stg.nz_interruptions
WHERE edb = 'MainPower NZ'
GROUP BY DAY(start_datetime)
ORDER BY day_of_month;