
/*
===============================================================================
Project     : SQL Data Warehouse
Script Name : silver_quality_checks.sql
Purpose     : Perform data quality checks and validation on Silver Layer data.
Layer       : Silver

Description:
    This script validates the quality, consistency, and accuracy of
    transformed data loaded into the Silver Layer.

Validation Categories:

    1. Primary Key Validation
       - Identify NULL values.
       - Identify duplicate records.

    2. Data Cleansing Validation
       - Check unwanted leading and trailing spaces.
       - Validate NULL and negative values.

    3. Data Standardization
       - Check consistency of categorical values.
       - Validate standardized country and gender values.

    4. Date Validation
       - Identify invalid dates.
       - Check date ranges and chronological consistency.

    5. Data Consistency
       - Validate sales calculations.
       - Check quantity, price, and sales relationships.

    6. ERP Data Validation
       - Validate customer birthdates.
       - Check location and product category information.

Execution:
    Execute this script after successfully loading the Silver Layer.

Expected Results:
    Most validation queries should return no records.
    DISTINCT queries display available values for manual inspection.

===============================================================================
*/


-- ============================================================================
-- 1. VALIDATE CRM CUSTOMER INFORMATION
-- ============================================================================

-- Check for NULLs or Duplicates in Primary Key
-- Expectation: No Results

SELECT
    cst_id,
    COUNT(*) AS duplicate_count
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1
    OR cst_id IS NULL;


-- Check for Unwanted Leading or Trailing Spaces
-- Expectation: No Results

SELECT
    cst_key
FROM silver.crm_cust_info
WHERE cst_key <> TRIM(cst_key);


-- Check Data Standardization and Consistency
-- Expectation: Only standardized marital status values

SELECT DISTINCT
    cst_marital_status
FROM silver.crm_cust_info;


-- Check Gender Standardization
-- Expectation: Female, Male, or n/a

SELECT DISTINCT
    cst_gndr
FROM silver.crm_cust_info;


-- ============================================================================
-- 2. VALIDATE CRM PRODUCT INFORMATION
-- ============================================================================

-- Check for NULLs or Duplicates in Primary Key
-- Expectation: No Results

SELECT
    prd_id,
    COUNT(*) AS duplicate_count
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1
    OR prd_id IS NULL;


-- Check for Unwanted Leading or Trailing Spaces
-- Expectation: No Results

SELECT
    prd_nm
FROM silver.crm_prd_info
WHERE prd_nm <> TRIM(prd_nm);


-- Check for NULL or Negative Product Costs
-- Expectation: No Results

SELECT
    prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0
    OR prd_cost IS NULL;


-- Check Product Line Standardization
-- Expectation: Only standardized product line values

SELECT DISTINCT
    prd_line
FROM silver.crm_prd_info;


-- Check for Invalid Date Orders (Start Date > End Date)
-- Expectation: No Results

SELECT
    *
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;


-- Check for NULL Product Keys and Product Names
-- Expectation: No Results

SELECT
    *
FROM silver.crm_prd_info
WHERE prd_key IS NULL
    OR prd_nm IS NULL;


-- ============================================================================
-- 3. VALIDATE CRM SALES DETAILS
-- ============================================================================

-- Check for Invalid Dates in Bronze Source
-- Expectation: No Invalid Dates

SELECT
    sls_due_dt
FROM bronze.crm_sales_details
WHERE sls_due_dt <= 0
    OR LEN(CONVERT(VARCHAR(20), sls_due_dt)) <> 8
    OR sls_due_dt > 20500101
    OR sls_due_dt < 19000101;


-- Check for Invalid Date Conversions in Silver
-- Expectation: No Results

SELECT
    *
FROM silver.crm_sales_details
WHERE
    (sls_order_dt IS NULL AND EXISTS
        (
            SELECT 1
            FROM bronze.crm_sales_details b
            WHERE b.sls_ord_num = silver.crm_sales_details.sls_ord_num
              AND b.sls_order_dt IS NOT NULL
              AND b.sls_order_dt <> 0
        ));


-- Check for Invalid Date Orders
-- Order Date should not be later than Shipping or Due Date.
-- Expectation: No Results

SELECT
    *
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt
    OR sls_order_dt > sls_due_dt;


-- Check Sales Calculation Consistency
-- Expectation: No Results

SELECT DISTINCT
    sls_sales,
    sls_quantity,
    sls_price
FROM silver.crm_sales_details
WHERE sls_sales <> sls_quantity * sls_price
    OR sls_sales IS NULL
    OR sls_quantity IS NULL
    OR sls_price IS NULL
    OR sls_sales <= 0
    OR sls_quantity <= 0
    OR sls_price <= 0
ORDER BY
    sls_sales,
    sls_quantity,
    sls_price;


-- ============================================================================
-- 4. VALIDATE ERP CUSTOMER INFORMATION
-- ============================================================================

-- Check for Birthdates Outside Valid Range
-- Expectation: Birthdates between 1924-01-01 and Today

SELECT DISTINCT
    bdate
FROM silver.erp_cust_az12
WHERE bdate < '1924-01-01'
    OR bdate > CAST(GETDATE() AS DATE);


-- Check Gender Standardization
-- Expectation: Female, Male, or n/a

SELECT DISTINCT
    gen
FROM silver.erp_cust_az12;


-- Check for NULL Customer IDs
-- Expectation: No Results

SELECT
    *
FROM silver.erp_cust_az12
WHERE cid IS NULL;


-- ============================================================================
-- 5. VALIDATE ERP LOCATION INFORMATION
-- ============================================================================

-- Check Country Standardization
-- Expectation: Standardized country names and approved values

SELECT DISTINCT
    cntry
FROM silver.erp_loc_a101
ORDER BY cntry;


-- Check for NULL Customer IDs
-- Expectation: No Results

SELECT
    *
FROM silver.erp_loc_a101
WHERE cid IS NULL;


-- ============================================================================
-- 6. VALIDATE ERP PRODUCT CATEGORY INFORMATION
-- ============================================================================

-- Check for Unwanted Leading or Trailing Spaces
-- Expectation: No Results

SELECT
    *
FROM silver.erp_px_cat_g1v2
WHERE cat <> TRIM(cat)
    OR subcat <> TRIM(subcat)
    OR maintenance <> TRIM(maintenance);


-- Check Maintenance Standardization
-- Expectation: Review available values

SELECT DISTINCT
    maintenance
FROM silver.erp_px_cat_g1v2;


-- Check Product Category Information for NULL Values
-- Expectation: No Results (if all fields are mandatory)

SELECT
    *
FROM silver.erp_px_cat_g1v2
WHERE id IS NULL
    OR cat IS NULL
    OR subcat IS NULL;


-- ============================================================================
-- 7. END OF VALIDATION SCRIPT
-- ============================================================================

PRINT '================================================';
PRINT 'SILVER LAYER DATA QUALITY CHECKS COMPLETED';
PRINT '================================================';

GO
