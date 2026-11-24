/*
===============================================================================
Script Name : bronze_load.sql
Purpose     : Load source CRM and ERP CSV files into the Bronze layer.
===============================================================================

Execution notes:
1. Update @? No variables are used in this script.
2. Make sure the CSV files exist at the paths specified below.
3. SQL Server must have permission to read the source files.
4. Run this script in the target data warehouse database.

This script truncates the Bronze tables before loading the latest source data.
===============================================================================
*/

-- ============================================================================
-- CRM SOURCE DATA
-- ============================================================================

-- 1. Load CRM Customer Information
TRUNCATE TABLE bronze.crm_cust_info;

BULK INSERT bronze.crm_cust_info
FROM 'C:\Users\datasets\source_crm\cust_info.csv'
WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    TABLOCK
);

SELECT COUNT(*) AS crm_cust_info_row_count
FROM bronze.crm_cust_info;
GO


-- 2. Load CRM Product Information
TRUNCATE TABLE bronze.crm_prd_info;

BULK INSERT bronze.crm_prd_info
FROM 'C:\Users\datasets\source_crm\prd_info.csv'
WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    TABLOCK
);

SELECT COUNT(*) AS crm_prd_info_row_count
FROM bronze.crm_prd_info;
GO


-- 3. Load CRM Sales Details
TRUNCATE TABLE bronze.crm_sales_details;

BULK INSERT bronze.crm_sales_details
FROM 'C:\Users\datasets\source_crm\sales_details.csv'
WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    TABLOCK
);

SELECT COUNT(*) AS crm_sales_details_row_count
FROM bronze.crm_sales_details;
GO


-- ============================================================================
-- ERP SOURCE DATA
-- ============================================================================

-- 4. Load ERP Customer Data
TRUNCATE TABLE bronze.erp_cust_az12;

BULK INSERT bronze.erp_cust_az12
FROM 'C:\Users\datasets\source_erp\cust_az12.csv'
WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    TABLOCK
);

SELECT COUNT(*) AS erp_cust_az12_row_count
FROM bronze.erp_cust_az12;
GO


-- 5. Load ERP Location Data
TRUNCATE TABLE bronze.erp_loc_a101;

BULK INSERT bronze.erp_loc_a101
FROM 'C:\Users\datasets\source_erp\loc_a101.csv'
WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    TABLOCK
);

SELECT COUNT(*) AS erp_loc_a101_row_count
FROM bronze.erp_loc_a101;
GO


-- 6. Load ERP Product Category Data
TRUNCATE TABLE bronze.erp_px_cat_g1v2;

BULK INSERT bronze.erp_px_cat_g1v2
FROM 'C:\Users\datasets\source_erp\px_cat_g1v2.csv'
WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    TABLOCK
);

SELECT COUNT(*) AS erp_px_cat_g1v2_row_count
FROM bronze.erp_px_cat_g1v2;
GO


-- ============================================================================
-- END OF BRONZE DATA LOAD
-- ============================================================================
