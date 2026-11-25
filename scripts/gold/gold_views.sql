
/*
===============================================================================
Project     : SQL Warehouse Insights
Script Name : gold_views.sql
Purpose     : Create analytical views in the Gold Layer.
Layer       : Gold

Description:
    This script creates the Gold Layer analytical views using
    transformed data from the Silver Layer.

    Gold Layer Objects:

    1. gold.dim_customers
       - Customer dimension view.
       - Integrates CRM and ERP customer information.
       - Generates a surrogate customer key.
       - Standardizes gender using CRM as the primary source
         and ERP as the fallback source.

    2. gold.dim_products
       - Product dimension view.
       - Integrates CRM product information with ERP category data.
       - Generates a surrogate product key.
       - Includes only current product records.

    3. gold.fact_sales
       - Sales fact view.
       - Connects sales transactions with customer and product dimensions.
       - Provides sales measures and transaction dates.

Dependencies:
    Silver Tables:
        silver.crm_cust_info
        silver.crm_prd_info
        silver.crm_sales_details
        silver.erp_cust_az12
        silver.erp_loc_a101
        silver.erp_px_cat_g1v2

Execution:
    Execute this script after successfully loading the Silver Layer.

WARNING:
    This script drops and recreates existing Gold Layer views.
    Dependent database objects may be affected by these changes.

===============================================================================
*/


-- ============================================================================
-- 1. CUSTOMER DIMENSION
-- ============================================================================

IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO

CREATE VIEW gold.dim_customers AS

SELECT
    -- Generate surrogate customer key
    ROW_NUMBER() OVER
    (
        ORDER BY ci.cst_id
    ) AS customer_key,

    -- Customer identification
    ci.cst_id AS customer_id,
    ci.cst_key AS customer_number,

    -- Customer personal information
    ci.cst_firstname AS first_name,
    ci.cst_lastname AS last_name,

    -- Customer geographical information
    la.cntry AS country,

    -- Customer demographic information
    ci.cst_marital_status AS marital_status,

    -- CRM is the primary source for gender.
    -- ERP is used as a fallback when CRM gender is unavailable.
    CASE
        WHEN ci.cst_gndr <> 'n/a'
            THEN ci.cst_gndr
        ELSE COALESCE(ca.gen, 'n/a')
    END AS gender,

    ca.bdate AS birthdate,

    -- Customer creation date
    ci.cst_create_date AS create_date

FROM silver.crm_cust_info AS ci

LEFT JOIN silver.erp_cust_az12 AS ca
    ON ci.cst_key = ca.cid

LEFT JOIN silver.erp_loc_a101 AS la
    ON ci.cst_key = la.cid;

GO


-- ============================================================================
-- 2. PRODUCT DIMENSION
-- ============================================================================

IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO

CREATE VIEW gold.dim_products AS

SELECT
    -- Generate surrogate product key
    ROW_NUMBER() OVER
    (
        ORDER BY pn.prd_start_dt, pn.prd_key
    ) AS product_key,

    -- Product identification
    pn.prd_id AS product_id,
    pn.prd_key AS product_number,

    -- Product information
    pn.prd_nm AS product_name,

    -- Product category information
    pn.cat_id AS category_id,
    pc.cat AS category,
    pc.subcat AS subcategory,
    pc.maintenance AS maintenance,

    -- Product pricing and classification
    pn.prd_cost AS cost,
    pn.prd_line AS product_line,

    -- Product validity period
    pn.prd_start_dt AS start_date

FROM silver.crm_prd_info AS pn

LEFT JOIN silver.erp_px_cat_g1v2 AS pc
    ON pn.cat_id = pc.id

-- Include only current product records
WHERE pn.prd_end_dt IS NULL;

GO


-- ============================================================================
-- 3. SALES FACT VIEW
-- ============================================================================

IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;
GO

CREATE VIEW gold.fact_sales AS

SELECT

    -- Transaction identification
    sd.sls_ord_num AS order_number,

    -- Dimension surrogate keys
    pr.product_key AS product_key,
    cu.customer_key AS customer_key,

    -- Transaction dates
    sd.sls_order_dt AS order_date,
    sd.sls_ship_dt AS shipping_date,
    sd.sls_due_dt AS due_date,

    -- Sales measures
    sd.sls_sales AS sales_amount,
    sd.sls_quantity AS quantity,
    sd.sls_price AS price

FROM silver.crm_sales_details AS sd

-- Connect sales transactions to product dimension
LEFT JOIN gold.dim_products AS pr
    ON sd.sls_prd_key = pr.product_number

-- Connect sales transactions to customer dimension
LEFT JOIN gold.dim_customers AS cu
    ON sd.sls_cust_id = cu.customer_id;

GO


-- ============================================================================
-- 4. GOLD LAYER VALIDATION
-- ============================================================================

-- Validate Customer Dimension
SELECT
    'gold.dim_customers' AS view_name,
    COUNT(*) AS total_records
FROM gold.dim_customers

UNION ALL

-- Validate Product Dimension
SELECT
    'gold.dim_products',
    COUNT(*)
FROM gold.dim_products

UNION ALL

-- Validate Sales Fact View
SELECT
    'gold.fact_sales',
    COUNT(*)
FROM gold.fact_sales;

GO


-- ============================================================================
-- 5. END OF SCRIPT
-- ============================================================================
