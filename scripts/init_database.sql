-- =========================================================
-- Create Database and Schemas
-- =========================================================

/*
Script Note:
    This script creates a database named 'DataWarehouse'
    if it does not already exist.

    If the database already exists, it will be dropped
    and recreated.

    Additionally, the script creates three schemas
    within the database:
        1. bronze
        2. silver
        3. gold
*/

USE master;
GO

IF EXISTS (
    SELECT 1
    FROM sys.databases
    WHERE name = 'DataWarehouse'
)
BEGIN
    ALTER DATABASE DataWarehouse
    SET SINGLE_USER
    WITH ROLLBACK IMMEDIATE;

    DROP DATABASE DataWarehouse;
END;
GO

CREATE DATABASE DataWarehouse;
GO

USE DataWarehouse;
GO

CREATE SCHEMA bronze;
GO

CREATE SCHEMA gold;
GO

CREATE SCHEMA silver;
GO
