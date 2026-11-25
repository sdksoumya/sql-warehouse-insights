/*
===============================================================================
Script Name : bronze_ddl.sql
Purpose     : Create the Bronze-layer tables for CRM and ERP source data.
===============================================================================

Description:
    - Creates the bronze schema if it does not already exist.
    - Drops existing Bronze tables, if present.
    - Recreates the six staging tables used to load the source CSV files.

WARNING:
    Running this script drops and recreates the listed tables. All existing
    data in those tables will be permanently deleted.

Execution:
    Run this script in the target data warehouse database before running
    bronze_load.sql.
===============================================================================
*/

-- ============================================================================
-- 1. CREATE BRONZE SCHEMA
-- ============================================================================

IF SCHEMA_ID('bronze') IS NULL
BEGIN
    EXEC('CREATE SCHEMA bronze');
END;
GO


-- ============================================================================
-- 2. CRM TABLES
-- ============================================================================

-- 2.1 CRM Customer Information
IF OBJECT_ID('bronze.crm_cust_info', 'U') IS NOT NULL
    DROP TABLE bronze.crm_cust_info;
GO

CREATE TABLE bronze.crm_cust_info
(
    cst_id              INT,
    cst_key             NVARCHAR(50),
    cst_firstname       NVARCHAR(50),
    cst_lastname        NVARCHAR(50),
    cst_marital_status  NVARCHAR(50),
    cst_gndr            NVARCHAR(50),
    cst_create_date     DATE
);
GO


-- 2.2 CRM Product Information
IF OBJECT_ID('bronze.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE bronze.crm_prd_info;
GO

CREATE TABLE bronze.crm_prd_info
(
    prd_id       INT,
    prd_key      NVARCHAR(50),
    prd_nm       NVARCHAR(50),
    prd_cost     INT,
    prd_line     NVARCHAR(50),
    prd_start_dt DATETIME,
    prd_end_dt   DATETIME
);
GO


-- 2.3 CRM Sales Details
IF OBJECT_ID('bronze.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE bronze.crm_sales_details;
GO

CREATE TABLE bronze.crm_sales_details
(
    sls_ord_num  NVARCHAR(50),
    sls_prd_key  NVARCHAR(50),
    sls_cust_id  INT,
    sls_order_dt INT,
    sls_ship_dt  INT,
    sls_due_dt   INT,
    sls_sales    INT,
    sls_quantity INT,
    sls_price    INT
);
GO


-- ============================================================================
-- 3. ERP TABLES
-- ============================================================================

-- 3.1 ERP Location Data
IF OBJECT_ID('bronze.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE bronze.erp_loc_a101;
GO

CREATE TABLE bronze.erp_loc_a101
(
    cid    NVARCHAR(50),
    cntry  NVARCHAR(50)
);
GO


-- 3.2 ERP Customer Data
IF OBJECT_ID('bronze.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE bronze.erp_cust_az12;
GO

CREATE TABLE bronze.erp_cust_az12
(
    cid    NVARCHAR(50),
    bdate  DATE,
    gen    NVARCHAR(50)
);
GO


-- 3.3 ERP Product Category Data
IF OBJECT_ID('bronze.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE bronze.erp_px_cat_g1v2;
GO

CREATE TABLE bronze.erp_px_cat_g1v2
(
    id           NVARCHAR(50),
    cat          NVARCHAR(50),
    subcat       NVARCHAR(50),
    maintenance  NVARCHAR(50)
);
GO


-- ============================================================================
-- 4. BRONZE TABLE CREATION SUMMARY
-- ============================================================================

SELECT
    s.name AS schema_name,
    t.name AS table_name
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON t.schema_id = s.schema_id
WHERE s.name = 'bronze'
ORDER BY t.name;
GO


-- ============================================================================
-- END OF BRONZE TABLE DDL
-- ============================================================================
