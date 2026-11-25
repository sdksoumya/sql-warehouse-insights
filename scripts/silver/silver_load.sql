/*
===============================================================================
Project     : SQL Warehouse Insight
Script Name : silver_load.sql
Purpose     : Load and transform data from Bronze Layer into Silver Layer.
Layer       : Silver

Description:
    This stored procedure performs the following operations:

    1. Cleans and deduplicates CRM customer information.
    2. Transforms CRM product information.
    3. Cleans and validates CRM sales details.
    4. Standardizes ERP customer information.
    5. Standardizes ERP location information.
    6. Loads ERP product category information.

Execution:
    EXEC silver.load_silver;

Dependencies:
    Bronze Tables:
        bronze.crm_cust_info
        bronze.crm_prd_info
        bronze.crm_sales_details
        bronze.erp_cust_az12
        bronze.erp_loc_a101
        bronze.erp_px_cat_g1v2

    Silver Tables:
        silver.crm_cust_info
        silver.crm_prd_info
        silver.crm_sales_details
        silver.erp_cust_az12
        silver.erp_loc_a101
        silver.erp_px_cat_g1v2

WARNING:
    This procedure uses TRUNCATE TABLE before loading data.
    Existing Silver Layer data will be replaced on every execution.

===============================================================================
*/


-- ============================================================================
-- 1. CREATE STORED PROCEDURE
-- ============================================================================

CREATE OR ALTER PROCEDURE silver.load_silver
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @StartTime       DATETIME2,
        @EndTime         DATETIME2,
        @BatchStartTime  DATETIME2,
        @BatchEndTime    DATETIME2,
        @RowsInserted    INT;

    BEGIN TRY

        SET @BatchStartTime = SYSDATETIME();

        PRINT '================================================';
        PRINT 'STARTING SILVER LAYER DATA LOAD';
        PRINT '================================================';

        BEGIN TRANSACTION;


        -- ================================================================
        -- 1. CRM CUSTOMER INFORMATION
        -- ================================================================

        SET @StartTime = SYSDATETIME();

        PRINT 'Loading: silver.crm_cust_info';

        TRUNCATE TABLE silver.crm_cust_info;

        INSERT INTO silver.crm_cust_info
        (
            cst_id,
            cst_key,
            cst_firstname,
            cst_lastname,
            cst_marital_status,
            cst_gndr,
            cst_create_date
        )
        SELECT
            cst_id,
            cst_key,
            TRIM(cst_firstname),
            TRIM(cst_lastname),

            CASE
                WHEN UPPER(TRIM(cst_marital_status)) = 'S'
                    THEN 'Single'
                WHEN UPPER(TRIM(cst_marital_status)) = 'M'
                    THEN 'Married'
                ELSE 'n/a'
            END,

            CASE
                WHEN UPPER(TRIM(cst_gndr)) = 'F'
                    THEN 'Female'
                WHEN UPPER(TRIM(cst_gndr)) = 'M'
                    THEN 'Male'
                ELSE 'n/a'
            END,

            cst_create_date

        FROM
        (
            SELECT
                *,
                ROW_NUMBER() OVER
                (
                    PARTITION BY cst_id
                    ORDER BY cst_create_date DESC
                ) AS flag_last

            FROM bronze.crm_cust_info
            WHERE cst_id IS NOT NULL

        ) AS customer_data

        WHERE flag_last = 1;

        SET @RowsInserted = @@ROWCOUNT;
        SET @EndTime = SYSDATETIME();

        PRINT 'Rows Inserted: ' + CAST(@RowsInserted AS VARCHAR(20));
        PRINT 'Duration: ' +
            CAST(DATEDIFF(SECOND, @StartTime, @EndTime) AS VARCHAR(20))
            + ' Seconds';


        -- ================================================================
        -- 2. CRM PRODUCT INFORMATION
        -- ================================================================

        SET @StartTime = SYSDATETIME();

        PRINT 'Loading: silver.crm_prd_info';

        TRUNCATE TABLE silver.crm_prd_info;

        INSERT INTO silver.crm_prd_info
        (
            prd_id,
            cat_id,
            prd_key,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_dt,
            prd_end_dt
        )
        SELECT
            prd_id,

            -- Standardize category ID
            REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,

            -- Extract product key
            SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,

            prd_nm,

            -- Replace NULL product cost with zero
            ISNULL(prd_cost, 0) AS prd_cost,

            -- Standardize product line
            CASE
                WHEN UPPER(TRIM(prd_line)) = 'M'
                    THEN 'Mountain'
                WHEN UPPER(TRIM(prd_line)) = 'R'
                    THEN 'Road'
                WHEN UPPER(TRIM(prd_line)) = 'S'
                    THEN 'Other Sales'
                WHEN UPPER(TRIM(prd_line)) = 'T'
                    THEN 'Touring'
                ELSE 'n/a'
            END AS prd_line,

            prd_start_dt,

            -- Calculate product end date using next start date
            DATEADD
            (
                DAY,
                -1,
                LEAD(prd_start_dt) OVER
                (
                    PARTITION BY prd_key
                    ORDER BY prd_start_dt
                )
            ) AS prd_end_dt

        FROM bronze.crm_prd_info;

        SET @RowsInserted = @@ROWCOUNT;
        SET @EndTime = SYSDATETIME();

        PRINT 'Rows Inserted: ' + CAST(@RowsInserted AS VARCHAR(20));
        PRINT 'Duration: ' +
            CAST(DATEDIFF(SECOND, @StartTime, @EndTime) AS VARCHAR(20))
            + ' Seconds';


        -- ================================================================
        -- 3. CRM SALES DETAILS
        -- ================================================================

        SET @StartTime = SYSDATETIME();

        PRINT 'Loading: silver.crm_sales_details';

        TRUNCATE TABLE silver.crm_sales_details;

        INSERT INTO silver.crm_sales_details
        (
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )
        SELECT
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,

            -- Convert integer date values into DATE
            TRY_CONVERT
            (
                DATE,
                CONVERT(CHAR(8), NULLIF(sls_order_dt, 0)),
                112
            ),

            TRY_CONVERT
            (
                DATE,
                CONVERT(CHAR(8), NULLIF(sls_ship_dt, 0)),
                112
            ),

            TRY_CONVERT
            (
                DATE,
                CONVERT(CHAR(8), NULLIF(sls_due_dt, 0)),
                112
            ),

            -- Recalculate sales when invalid
            CASE
                WHEN sls_sales IS NULL
                    OR sls_sales <= 0
                    OR sls_sales <> sls_quantity * ABS(sls_price)
                THEN TRY_CONVERT
                (
                    INT,
                    CAST(sls_quantity AS BIGINT)
                    * ABS(CAST(sls_price AS BIGINT))
                )
                ELSE sls_sales
            END AS sls_sales,

            sls_quantity,

            -- Recalculate price when invalid
            CASE
                WHEN sls_price IS NULL OR sls_price <= 0
                THEN TRY_CONVERT
                (
                    INT,
                    CAST(sls_sales AS DECIMAL(18,2))
                    / NULLIF(sls_quantity, 0)
                )
                ELSE sls_price
            END AS sls_price

        FROM bronze.crm_sales_details;

        SET @RowsInserted = @@ROWCOUNT;
        SET @EndTime = SYSDATETIME();

        PRINT 'Rows Inserted: ' + CAST(@RowsInserted AS VARCHAR(20));
        PRINT 'Duration: ' +
            CAST(DATEDIFF(SECOND, @StartTime, @EndTime) AS VARCHAR(20))
            + ' Seconds';


        -- ================================================================
        -- 4. ERP CUSTOMER INFORMATION
        -- ================================================================

        SET @StartTime = SYSDATETIME();

        PRINT 'Loading: silver.erp_cust_az12';

        TRUNCATE TABLE silver.erp_cust_az12;

        INSERT INTO silver.erp_cust_az12
        (
            cid,
            bdate,
            gen
        )
        SELECT

            -- Remove NAS prefix from customer ID
            CASE
                WHEN LEFT(cid, 3) = 'NAS'
                    THEN SUBSTRING(cid, 4, LEN(cid))
                ELSE cid
            END AS cid,

            -- Remove future birth dates
            CASE
                WHEN bdate > CAST(GETDATE() AS DATE)
                    THEN NULL
                ELSE bdate
            END AS bdate,

            -- Standardize gender
            CASE
                WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE')
                    THEN 'Female'
                WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')
                    THEN 'Male'
                ELSE 'n/a'
            END AS gen

        FROM bronze.erp_cust_az12;

        SET @RowsInserted = @@ROWCOUNT;
        SET @EndTime = SYSDATETIME();

        PRINT 'Rows Inserted: ' + CAST(@RowsInserted AS VARCHAR(20));
        PRINT 'Duration: ' +
            CAST(DATEDIFF(SECOND, @StartTime, @EndTime) AS VARCHAR(20))
            + ' Seconds';


        -- ================================================================
        -- 5. ERP LOCATION INFORMATION
        -- ================================================================

        SET @StartTime = SYSDATETIME();

        PRINT 'Loading: silver.erp_loc_a101';

        TRUNCATE TABLE silver.erp_loc_a101;

        INSERT INTO silver.erp_loc_a101
        (
            cid,
            cntry
        )
        SELECT

            -- Remove special characters from customer ID
            REPLACE(cid, '-', '') AS cid,

            -- Standardize country names
            CASE
                WHEN TRIM(cntry) = 'DE'
                    THEN 'Germany'
                WHEN TRIM(cntry) IN ('US', 'USA')
                    THEN 'United States'
                WHEN TRIM(cntry) = ''
                    OR cntry IS NULL
                    THEN 'n/a'
                ELSE TRIM(cntry)
            END AS cntry

        FROM bronze.erp_loc_a101;

        SET @RowsInserted = @@ROWCOUNT;
        SET @EndTime = SYSDATETIME();

        PRINT 'Rows Inserted: ' + CAST(@RowsInserted AS VARCHAR(20));
        PRINT 'Duration: ' +
            CAST(DATEDIFF(SECOND, @StartTime, @EndTime) AS VARCHAR(20))
            + ' Seconds';


        -- ================================================================
        -- 6. ERP PRODUCT CATEGORY INFORMATION
        -- ================================================================

        SET @StartTime = SYSDATETIME();

        PRINT 'Loading: silver.erp_px_cat_g1v2';

        TRUNCATE TABLE silver.erp_px_cat_g1v2;

        INSERT INTO silver.erp_px_cat_g1v2
        (
            id,
            cat,
            subcat,
            maintenance
        )
        SELECT
            id,
            cat,
            subcat,
            maintenance

        FROM bronze.erp_px_cat_g1v2;

        SET @RowsInserted = @@ROWCOUNT;
        SET @EndTime = SYSDATETIME();

        PRINT 'Rows Inserted: ' + CAST(@RowsInserted AS VARCHAR(20));
        PRINT 'Duration: ' +
            CAST(DATEDIFF(SECOND, @StartTime, @EndTime) AS VARCHAR(20))
            + ' Seconds';


        -- ================================================================
        -- 7. COMMIT TRANSACTION
        -- ================================================================

        COMMIT TRANSACTION;

        SET @BatchEndTime = SYSDATETIME();

        PRINT '================================================';
        PRINT 'SILVER LAYER LOAD COMPLETED SUCCESSFULLY';
        PRINT 'Total Duration: ' +
            CAST
            (
                DATEDIFF(SECOND, @BatchStartTime, @BatchEndTime)
                AS VARCHAR(20)
            )
            + ' Seconds';
        PRINT '================================================';

    END TRY

    BEGIN CATCH

        -- Rollback transaction if an error occurs
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        PRINT '================================================';
        PRINT 'ERROR OCCURRED DURING SILVER LAYER LOAD';
        PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS VARCHAR(20));
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Line: ' + CAST(ERROR_LINE() AS VARCHAR(20));
        PRINT '================================================';

        THROW;

    END CATCH

END;
GO


-- ============================================================================
-- 2. EXECUTE SILVER LOAD PROCEDURE
-- ============================================================================

EXEC silver.load_silver;
GO


-- ============================================================================
-- 3. VALIDATE SILVER LAYER DATA
-- ============================================================================

SELECT
    'crm_cust_info' AS table_name,
    COUNT(*) AS total_records
FROM silver.crm_cust_info

UNION ALL

SELECT
    'crm_prd_info',
    COUNT(*)
FROM silver.crm_prd_info

UNION ALL

SELECT
    'crm_sales_details',
    COUNT(*)
FROM silver.crm_sales_details

UNION ALL

SELECT
    'erp_cust_az12',
    COUNT(*)
FROM silver.erp_cust_az12

UNION ALL

SELECT
    'erp_loc_a101',
    COUNT(*)
FROM silver.erp_loc_a101

UNION ALL

SELECT
    'erp_px_cat_g1v2',
    COUNT(*)
FROM silver.erp_px_cat_g1v2;

GO

-- ============================================================================
-- END OF SCRIPT
-- ============================================================================
