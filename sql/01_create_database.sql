-- Run this in SSMS connected to (localdb)\MSSQLLocalDB

USE master;
GO

IF DB_ID('RetailDW') IS NOT NULL
BEGIN
    ALTER DATABASE RetailDW SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE RetailDW;
END
GO

CREATE DATABASE RetailDW;
GO

USE RetailDW;
GO

PRINT 'RetailDW database created successfully.';
