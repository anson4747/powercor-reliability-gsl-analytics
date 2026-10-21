SELECT
    COUNT(*)                   AS total_rows,
    COUNT(saidi_value)         AS saidi_filled,
    COUNT(*) - COUNT(saidi_value) AS saidi_missing,
    COUNT(*) - COUNT(saifi_value) AS saifi_missing
FROM stg.nz_interruptions;


SELECT
    ROUND(SUM(saidi_value), 4)               AS total_saidi,
    ROUND(SUM(number_of_icps_interrupted), 1) AS total_icps,
    MIN(start_datetime)                       AS earliest_start,
    MAX(end_datetime)                         AS latest_end
FROM stg.nz_interruptions;

SELECT
    COUNT(*)                          AS days,
    MIN(day)                          AS first_day,
    MAX(day)                          AS last_day,
    ROUND(SUM(saidi_network_raw), 4)  AS total_network_saidi,
    SUM(CASE WHEN med_flag_powercor = 'Yes' THEN 1 ELSE 0 END) AS med_days
FROM stg.pcr_daily_reliability;