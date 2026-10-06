
/* =========================================================
   BRONZE LAYER - RAW FASHION DATA
   Creates the database and bronze schema, then initializes
   the raw staging table for the source fashion dataset.
   ========================================================= */

-- Create the database if it does not already exist
IF DB_ID('FashionPortfolio') IS NULL
    CREATE DATABASE FashionPortfolio;
GO

USE FashionPortfolio;
GO

-- Create the bronze schema if it does not already exist
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')
    EXEC('CREATE SCHEMA bronze');
GO

-- Recreate the raw table for a fresh data load
IF OBJECT_ID('bronze.raw_fashion', 'U') IS NOT NULL
    DROP TABLE bronze.raw_fashion;
GO

CREATE TABLE bronze.raw_fashion
(
    source_row_id   INT NULL,
    brand_name      NVARCHAR(MAX) NULL,
    deatils         NVARCHAR(MAX) NULL,
    sizes           NVARCHAR(MAX) NULL,
    mrp             NVARCHAR(MAX) NULL,
    sell_price      NVARCHAR(MAX) NULL,
    discount        NVARCHAR(MAX) NULL,
    category        NVARCHAR(MAX) NULL,
    dwh_source_file NVARCHAR(MAX) NULL,
    dwh_load_date   DATETIME2 DEFAULT SYSDATETIME()
);
GO

