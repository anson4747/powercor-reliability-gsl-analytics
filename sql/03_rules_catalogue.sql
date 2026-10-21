USE PowerNetworks;
GO

CREATE TABLE ref.validation_rules (
    rule_id      varchar(10)   NOT NULL PRIMARY KEY,
    rule_name    nvarchar(100) NOT NULL,
    severity     varchar(10)   NOT NULL,   -- Critical / High / Medium
    description  nvarchar(400) NOT NULL,
    why_it_matters nvarchar(400) NOT NULL
);
GO

INSERT INTO ref.validation_rules VALUES
('V01','End before or equal to start','Critical',
 'end_datetime <= start_datetime',
 'Duration is negative or zero, so SAIDI and GSL hours cannot be calculated'),
('V02','Suspected day/month swap','High',
 'Day <= 12 and the date is out of sequence with the interruption ID',
 'Event lands in the wrong month, quarter or regulatory year'),
('V03','Extreme duration','Medium',
 'Duration over 7 days (10,080 minutes)',
 'Likely a data entry error; inflates SAIDI and GSL eligibility'),
('V04','Missing or zero customers','High',
 'number_of_icps_interrupted is null or <= 0',
 'Event contributes nothing to SAIFI and no customer can be assessed for GSL'),
('V05','Fractional customer count','Medium',
 'number_of_icps_interrupted is not a whole number',
 'Customers are whole connections; indicates a calculation or entry error'),
('V06','Customer minutes mismatch','Medium',
 'icp_interruption_minutes differs from customers x duration by more than 5%',
 'Customer minutes drive SAIDI; a mismatch means one of the inputs is wrong');
GO

SELECT * FROM ref.validation_rules;