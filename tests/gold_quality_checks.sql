
/*
===============================================================================
Project     : SQL Warehouse Insights
Script Name : gold_quality_checks.sql
Purpose     : Perform data quality and integration checks on Gold Layer views.
Layer       : Gold

Description:
    This script validates the integrity, uniqueness, and connectivity
    of Gold Layer analytical views.

Validation Categories:

    1. Customer Dimension Validation
       - Check uniqueness of customer surrogate keys.

    2. Product Dimension Validation
       - Check uniqueness of product surrogate keys.

    3. Fact Table Validation
       - Check referential integrity between the fact table
         and customer/product dimensions.
       - Identify unmatched dimension records.

Expected Results:
    - No duplicate customer keys.
    - No duplicate product keys.
    - No unmatched customer or product dimension keys.

Dependencies:
    gold.dim_customers
    gold.dim_products
    gold.fact_sales

Execution:
    Execute this script after creating Gold Layer views.

===============================================================================
*/


-- ============================================================================
-- 1. VALIDATE CUSTOMER DIMENSION
-- ============================================================================

-- Check Uniqueness of Customer Surrogate Key
-- Expectation: No Results

SELECT
    customer_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;


-- Check for NULL Customer Surrogate Keys
-- Expectation: No Results

SELECT
    *
FROM gold.dim_customers
WHERE customer_key IS NULL;


-- ============================================================================
-- 2. VALIDATE PRODUCT DIMENSION
-- ============================================================================

-- Check Uniqueness of Product Surrogate Key
-- Expectation: No Results

SELECT
    product_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;


-- Check for NULL Product Surrogate Keys
-- Expectation: No Results

SELECT
    *
FROM gold.dim_products
WHERE product_key IS NULL;


-- ============================================================================
-- 3. VALIDATE FACT TABLE AND DIMENSION CONNECTIVITY
-- ============================================================================

-- Check Referential Integrity Between Fact and Dimensions
-- Identify sales records without matching customer or product dimensions.
-- Expectation: No Results

SELECT
    f.order_number,
    f.customer_key,
    c.customer_id,
    f.product_key,
    p.product_id
FROM gold.fact_sales AS f

LEFT JOIN gold.dim_customers AS c
    ON f.customer_key = c.customer_key

LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key

WHERE c.customer_key IS NULL
    OR p.product_key IS NULL;


-- ============================================================================
-- 4. VALIDATE NULL FOREIGN KEYS IN FACT TABLE
-- ============================================================================

-- Check for NULL Customer and Product Keys
-- Expectation: No Results (if every transaction must have both dimensions)

SELECT
    *
FROM gold.fact_sales
WHERE customer_key IS NULL
    OR product_key IS NULL;


-- ============================================================================
-- 5. VALIDATE FACT TABLE RECORD COUNTS
-- ============================================================================

-- Review Total Records in Gold Layer Views

SELECT
    'gold.dim_customers' AS object_name,
    COUNT(*) AS total_records
FROM gold.dim_customers

UNION ALL

SELECT
    'gold.dim_products',
    COUNT(*)
FROM gold.dim_products

UNION ALL

SELECT
    'gold.fact_sales',
    COUNT(*)
FROM gold.fact_sales;


-- ============================================================================
-- 6. END OF VALIDATION SCRIPT
-- ============================================================================

PRINT '================================================';
PRINT 'GOLD LAYER DATA QUALITY CHECKS COMPLETED';
PRINT '================================================';

GO
