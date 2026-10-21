SELECT
    COUNT(*) AS days_used,
    AVG(LOG(saidi_network_after_excl))    AS alpha,
    STDEV(LOG(saidi_network_after_excl))  AS beta_sample,
    STDEVP(LOG(saidi_network_after_excl)) AS beta_population,
    EXP(AVG(LOG(saidi_network_after_excl))
        + 2.8 * STDEV(LOG(saidi_network_after_excl)))  AS threshold_sample,
    EXP(AVG(LOG(saidi_network_after_excl))
        + 2.8 * STDEVP(LOG(saidi_network_after_excl))) AS threshold_population
FROM stg.pcr_daily_reliability
WHERE saidi_network_after_excl > 0;


WITH t AS (
    SELECT EXP(AVG(LOG(saidi_network_after_excl))
               + 2.8 * STDEV(LOG(saidi_network_after_excl))) AS threshold
    FROM stg.pcr_daily_reliability
    WHERE saidi_network_after_excl > 0
),
flagged AS (
    SELECT
        d.day,
        d.saidi_network_after_excl,
        d.med_flag_powercor,
        CASE WHEN d.saidi_network_after_excl > t.threshold
             THEN 'Yes' ELSE 'No' END AS med_flag_ours
    FROM stg.pcr_daily_reliability d
    CROSS JOIN t
)
SELECT med_flag_ours, med_flag_powercor, COUNT(*) AS days
FROM flagged
GROUP BY med_flag_ours, med_flag_powercor
ORDER BY med_flag_ours, med_flag_powercor;

-- Would switching to population STDEV change any MED day?
SELECT day, saidi_network_after_excl
FROM stg.pcr_daily_reliability
WHERE saidi_network_after_excl > 6.75179972717917
  AND saidi_network_after_excl <= 6.75905194897646;


SELECT day, saidi_network_raw, saidi_network_after_excl
FROM stg.pcr_daily_reliability
WHERE day = '2020-01-31';


CREATE OR ALTER VIEW rpt.pcr_daily_med AS
WITH t AS (
    SELECT EXP(AVG(LOG(saidi_network_after_excl))
               + 2.8 * STDEV(LOG(saidi_network_after_excl))) AS threshold
    FROM stg.pcr_daily_reliability
    WHERE saidi_network_after_excl > 0
)
SELECT
    d.*,
    t.threshold,
    CASE WHEN d.saidi_network_after_excl > t.threshold
         THEN 'Yes' ELSE 'No' END AS med_flag_ours,
    YEAR(DATEADD(MONTH, 6, d.day)) AS fin_year
FROM stg.pcr_daily_reliability d
CROSS JOIN t;
GO


SELECT
    fin_year,
    SUM(saidi_urban_after_excl) AS urban_all,
    SUM(CASE WHEN med_flag_ours = 'No' THEN saidi_urban_after_excl ELSE 0 END) AS urban_ex_med,
    SUM(saidi_short_rural_after_excl) AS short_rural_all,
    SUM(CASE WHEN med_flag_ours = 'No' THEN saidi_short_rural_after_excl ELSE 0 END) AS short_rural_ex_med,
    SUM(saidi_long_rural_after_excl) AS long_rural_all,
    SUM(CASE WHEN med_flag_ours = 'No' THEN saidi_long_rural_after_excl ELSE 0 END) AS long_rural_ex_med
FROM rpt.pcr_daily_med
GROUP BY fin_year
ORDER BY fin_year;


WITH annual AS (
    SELECT fin_year,
        SUM(CASE WHEN med_flag_ours = 'No' THEN saidi_urban_after_excl ELSE 0 END)       AS urban,
        SUM(CASE WHEN med_flag_ours = 'No' THEN saidi_short_rural_after_excl ELSE 0 END) AS short_rural,
        SUM(CASE WHEN med_flag_ours = 'No' THEN saidi_long_rural_after_excl ELSE 0 END)  AS long_rural
    FROM rpt.pcr_daily_med
    GROUP BY fin_year
)
SELECT AVG(urban) AS urban_target, AVG(short_rural) AS short_rural_target, AVG(long_rural) AS long_rural_target
FROM annual;