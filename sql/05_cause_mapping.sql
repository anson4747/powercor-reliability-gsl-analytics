SELECT cause, COUNT(*) AS events
FROM stg.nz_interruptions
GROUP BY cause
ORDER BY cause;


DROP TABLE IF EXISTS ref.cause_mapping;   -- idempotent rebuild

CREATE TABLE ref.cause_mapping (
    raw_cause      nvarchar(255) NOT NULL PRIMARY KEY,
    standard_cause nvarchar(50)  NOT NULL,
    note           nvarchar(200) NULL
);

INSERT INTO ref.cause_mapping (raw_cause, standard_cause, note) VALUES
-- Planned
(N'11.0 Planned Shutdown', N'Planned', NULL),
(N'Planned', N'Planned', NULL),
(N'Planned Capital / Maintenance Outage', N'Planned', NULL),
(N'Planned interruption', N'Planned', NULL),
(N'Planned Outage', N'Planned', NULL),
(N'Planned Shutdown', N'Planned', NULL),
(N'PLANNED SHUTDOWN - CAPITAL WORKS', N'Planned', NULL),
(N'PLANNED SHUTDOWN - MAINTENANCE', N'Planned', NULL),
(N'THIRD PARTY SERVICES - CUSTOMER REQUEST', N'Planned', N'Judgment: customer requested shutdown'),
-- Vegetation
(N'2.0 Vegetation', N'Vegetation', NULL),
(N'Vegeatation', N'Vegetation', N'Typo in source'),
(N'Vegetation', N'Vegetation', NULL),
(N'VEGETATION - INSIDE ZONE', N'Vegetation', NULL),
(N'VEGETATION - OUTSIDE ZONE', N'Vegetation', NULL),
(N'VEGETATION - WIND-BLOWN DEBRIS - TREES', N'Vegetation', NULL),
(N'Trees', N'Vegetation', NULL),
-- Adverse weather
(N'3.0 Adverse Weather', N'Adverse weather', NULL),
(N'Adverse weather', N'Adverse weather', NULL),
(N'ADVERSE WEATHER - SNOW/ICE', N'Adverse weather', NULL),
(N'ADVERSE WEATHER - WIND', N'Adverse weather', NULL),
(N'ADVERSE WEATHER - WIND-BLOWN DEBRIS (NOT TREES)', N'Adverse weather', NULL),
(N'AdverseWeather', N'Adverse weather', NULL),
-- Adverse environment
(N'4.0 Adverse Environment', N'Adverse environment', NULL),
(N'Adverse environment', N'Adverse environment', NULL),
(N'ADVERSE ENVIRONMENT - FIRE', N'Adverse environment', NULL),
(N'ADVERSE ENVIRONMENT - LAND SLIPPAGE', N'Adverse environment', NULL),
-- Third party
(N'3rd Party interference', N'Third party', NULL),
(N'5.0 Third party Interference', N'Third party', NULL),
(N'Foreign Interference', N'Third party', N'Judgment: foreign object contact'),
(N'Third Party', N'Third party', NULL),
(N'Third party interference', N'Third party', NULL),
(N'THIRD PARTY INTERFERENCE - DIG IN', N'Third party', NULL),
(N'THIRD PARTY INTERFERENCE - OTHER', N'Third party', NULL),
(N'THIRD PARTY INTERFERENCE - OVERHEAD CONTACT', N'Third party', NULL),
(N'THIRD PARTY INTERFERENCE - TREES', N'Third party', N'Judgment: reporter classed as third party'),
(N'THIRD PARTY INTERFERENCE - VANDALISM/THEFT', N'Third party', NULL),
(N'THIRD PARTY INTERFERENCE - VEHICLE DAMAGE', N'Third party', NULL),
(N'Third_party', N'Third party', NULL),
(N'Third-party Interference', N'Third party', NULL),
(N'ThirdPartyInterference', N'Third party', NULL),
-- Wildlife
(N'6.0 Wildlife', N'Wildlife', NULL),
(N'Wildlife', N'Wildlife', NULL),
(N'WILDLIFE - BIRD', N'Wildlife', NULL),
(N'WILDLIFE - OTHER', N'Wildlife', NULL),
(N'WILDLIFE - POSSUM', N'Wildlife', NULL),
-- Defective equipment
(N'8.0 Defective Equipment', N'Defective equipment', NULL),
(N'Defective equipment', N'Defective equipment', NULL),
(N'DEFECTIVE EQUIPMENT - JUMPER FAILURE', N'Defective equipment', NULL),
(N'DEFECTIVE EQUIPMENT - LINE CLASH', N'Defective equipment', NULL),
(N'DEFECTIVE EQUIPMENT - OH EQUIPMENT FAILURE', N'Defective equipment', NULL),
(N'DEFECTIVE EQUIPMENT - UG EQUIPMENT FAILURE', N'Defective equipment', NULL),
(N'DEFECTIVE EQUIPMENT - ZONE SUBSTATION', N'Defective equipment', NULL),
(N'DefectiveEquipment', N'Defective equipment', NULL),
-- Unknown
(N'9.0 Cause Unknown', N'Unknown', NULL),
(N'Cause Unknown', N'Unknown', NULL),
(N'CauseUnknown', N'Unknown', NULL),
(N'Unknown', N'Unknown', NULL),
(N'UNKNOWN - CURSORY PATROLLED - CAUSE UNKNOWN', N'Unknown', NULL),
(N'UNKNOWN - DATA QUALITY', N'Unknown', NULL),
(N'UNKNOWN - NOT PATROLLED - CAUSE UNKNOWN', N'Unknown', NULL),
(N'UNKNOWN - OPERATIONAL PATROLLED - CAUSE UNKNOWN', N'Unknown', NULL),
(N'Unknown cause', N'Unknown', NULL),
-- Human error
(N'Human Element', N'Human error', NULL),
(N'Human error', N'Human error', NULL),
(N'HUMAN ERROR - LOAD SHEDDING - NETWORK LOAD', N'Human error', NULL),
(N'HUMAN ERROR - POTENTIAL SWITCHING ERROR', N'Human error', NULL),
(N'HUMAN ERROR - POTENTIAL WORKMANSHIP', N'Human error', NULL),
(N'HUMAN ERROR - PROTECTION SETTINGS - INCORRECT/ERROR', N'Human error', NULL),
(N'HumanError', N'Human error', NULL),
-- Lightning
(N'Lighting', N'Lightning', N'Typo in source'),
(N'Lightning', N'Lightning', NULL),
(N'LIGHTNING - LIGHTNING STRIKE', N'Lightning', NULL),
-- Other and transmission
(N'OTHER', N'Other', NULL),
(N'Other cause', N'Other', NULL),
(N'Transpower', N'Transmission', N'Judgment: upstream transmission, usually excluded');

-- Check 1: labels with no mapping (expect 0 rows)
SELECT s.cause, COUNT(*) AS events
FROM stg.nz_interruptions s
LEFT JOIN ref.cause_mapping m ON s.cause = m.raw_cause
WHERE m.raw_cause IS NULL
GROUP BY s.cause;

-- Check 2: events by standard cause
SELECT m.standard_cause, COUNT(*) AS events
FROM stg.nz_interruptions s
JOIN ref.cause_mapping m ON s.cause = m.raw_cause
GROUP BY m.standard_cause
ORDER BY events DESC;