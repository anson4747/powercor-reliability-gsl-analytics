-- Phase 0.2: create the project database and its layers
CREATE DATABASE PowerNetworks;
GO

USE PowerNetworks;
GO

CREATE SCHEMA stg;    -- raw data, as received
GO
CREATE SCHEMA clean;  -- validated and standardised
GO
CREATE SCHEMA rpt;    -- reporting tables for Power BI
GO
CREATE SCHEMA ref;    -- lookup and rule tables
GO