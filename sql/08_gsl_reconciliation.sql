SELECT TABLE_NAME,
       STRING_AGG(COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY ORDINAL_POSITION) AS columns
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'stg'
  AND TABLE_NAME IN ('esc_gsl', 'pcr_gsl_model')
GROUP BY TABLE_NAME;

SELECT TOP 15 * FROM stg.esc_gsl;
SELECT TOP 15 * FROM stg.pcr_gsl_model;


SELECT DISTINCT category, measure
FROM stg.pcr_gsl_model
WHERE distributor = 'Powercor'
ORDER BY category, measure;

SELECT DISTINCT gsl_category
FROM stg.esc_gsl
WHERE distributor = 'Powercor Australia'
ORDER BY gsl_category;


DROP TABLE IF EXISTS ref.gsl_category_mapping;

CREATE TABLE ref.gsl_category_mapping (
    source        varchar(10)   NOT NULL,   -- 'PCR' or 'ESC'
    source_label  nvarchar(255) NOT NULL,
    std_category  nvarchar(50)  NOT NULL,
    note          nvarchar(200) NULL,
    PRIMARY KEY (source, source_label)
);

INSERT INTO ref.gsl_category_mapping (source, source_label, std_category, note) VALUES
-- Powercor model
('PCR', N'Appointments not met within 15 minutes of agreed time', N'Appointments', NULL),
('PCR', N'Connections - GSL payments - 1-4 day delay', N'Connections', NULL),
('PCR', N'Connections - GSL payments - 5+ day delay', N'Connections', NULL),
('PCR', N'Low reliability payments - 18 hours', N'Supply restoration', N'Hours based: ESC calls this supply restoration'),
('PCR', N'Low reliability payments - 30 hours', N'Supply restoration', N'Hours based: ESC calls this supply restoration'),
('PCR', N'Low reliability payments - 60 hours', N'Supply restoration', N'Hours based: ESC calls this supply restoration'),
('PCR', N'Low reliability payments - 8 events', N'Low reliability', NULL),
('PCR', N'Low reliability payments - 12 events', N'Low reliability', NULL),
('PCR', N'Low reliability payments - 20 events', N'Low reliability', NULL),
('PCR', N'Low reliability payments - 24 momentary events', N'Low reliability', NULL),
('PCR', N'Low reliability payments - 36 momentary events', N'Low reliability', NULL),
('PCR', N'MED - 12 hours:', N'Major event day', N'Trailing colon in source label'),
('PCR', N'Street lights - GSL payments', N'Street lights', N'No ESC equivalent'),
-- ESC published
('ESC', N'Appointments not met within 15 minutes of agreed time', N'Appointments', NULL),
('ESC', N'Failing to connect customers by agreed date', N'Connections', NULL),
('ESC', N'Supply restoration payments for over 18 hours of unplanned sustained interruptions per year', N'Supply restoration', NULL),
('ESC', N'Low reliability payments for over 8 unplanned sustained interruptions per year and momentary interruptions', N'Low reliability', NULL),
('ESC', N'Major event day payments for over 12 hours of unplanned sustained interruptions during storm events', N'Major event day', NULL);

-- Check: unmapped labels on either side (expect 0 rows)
SELECT 'PCR' AS source, p.measure AS label
FROM stg.pcr_gsl_model p
LEFT JOIN ref.gsl_category_mapping m ON m.source = 'PCR' AND m.source_label = p.measure
WHERE p.distributor = 'Powercor' AND m.source_label IS NULL
UNION ALL
SELECT 'ESC', e.gsl_category
FROM stg.esc_gsl e
LEFT JOIN ref.gsl_category_mapping m ON m.source = 'ESC' AND m.source_label = e.gsl_category
WHERE e.distributor = 'Powercor Australia' AND m.source_label IS NULL;


CREATE OR ALTER VIEW rpt.gsl_reconciliation AS
WITH pcr AS (                                   -- Powercor side: actuals only, tiers summed
    SELECT
        m.std_category,
        p.financial_year AS fy,
        SUM(p.gsl_count)  AS pcr_count,
        SUM(p.gsl_amount) AS pcr_amount
    FROM stg.pcr_gsl_model p
    JOIN ref.gsl_category_mapping m
      ON m.source = 'PCR' AND m.source_label = p.measure
    WHERE p.distributor = 'Powercor'
      AND p.year_label LIKE '%act'
    GROUP BY m.std_category, p.financial_year
),
esc AS (                                        -- ESC side: text to numbers, year reformatted
    SELECT
        m.std_category,
        CONCAT('FY', RIGHT(e.financial_year, 2)) AS fy,
        SUM(TRY_CAST(REPLACE(e.gsl_count, ',', '') AS decimal(18,2))) AS esc_count,
        SUM(TRY_CAST(REPLACE(REPLACE(e.total_value, '$', ''), ',', '') AS decimal(18,2))) AS esc_amount
    FROM stg.esc_gsl e
    JOIN ref.gsl_category_mapping m
      ON m.source = 'ESC' AND m.source_label = e.gsl_category
    WHERE e.distributor = 'Powercor Australia'
    GROUP BY m.std_category, CONCAT('FY', RIGHT(e.financial_year, 2))
)
SELECT
    COALESCE(p.std_category, e.std_category) AS std_category,
    COALESCE(p.fy, e.fy)                     AS fy,
    p.pcr_count,  e.esc_count,
    p.pcr_amount, e.esc_amount,
    p.pcr_amount - e.esc_amount              AS amount_diff,
    (p.pcr_amount - e.esc_amount) * 100.0 / NULLIF(e.esc_amount, 0) AS amount_diff_pct,
    CASE
        WHEN p.std_category IS NULL THEN 'Only in ESC'
        WHEN e.std_category IS NULL THEN 'Only in Powercor'
        WHEN ABS(p.pcr_count - e.esc_count) < 0.5
         AND ABS(p.pcr_amount - e.esc_amount) <= 1 THEN 'Match'
        ELSE 'Difference'
    END AS status
FROM pcr p
FULL OUTER JOIN esc e
  ON p.std_category = e.std_category
 AND p.fy = e.fy
WHERE COALESCE(p.fy, e.fy) IN (SELECT fy FROM pcr);   -- only years Powercor has actuals for
GO

-- 5.4 The reconciliation
SELECT * FROM rpt.gsl_reconciliation ORDER BY fy, std_category;

-- 5.5 Does rate x count = amount inside Powercor's own model? (expect 0 rows)
SELECT measure, financial_year, gsl_rate, gsl_count, gsl_amount,
       gsl_rate * gsl_count AS recalculated
FROM stg.pcr_gsl_model
WHERE distributor = 'Powercor'
  AND year_label LIKE '%act'
  AND ABS(gsl_rate * gsl_count - gsl_amount) > 0.01;