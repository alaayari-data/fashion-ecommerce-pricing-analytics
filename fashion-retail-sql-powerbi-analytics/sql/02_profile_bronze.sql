
USE FashionPortfolio;
GO


/* =========================================================
   2A. DATA PROFILING & QUALITY ASSESSMENT
   Initial assessment of the raw dataset to identify
   completeness, format inconsistencies, duplicates,
   and potential data quality issues.
   ========================================================= */


/* 2A.1 DATASET OVERVIEW
   Basic dataset size and cardinality assessment.
*/

SELECT
    COUNT(*)                   AS total_rows,
    COUNT(DISTINCT brand_name) AS distinct_brands,
    COUNT(DISTINCT category)   AS distinct_categories
FROM bronze.raw_fashion;


/* 2A.2 MISSING & INVALID VALUES
   Identify NULL, empty, and text-based missing values
   represented by 'Nan' in the source data.
*/

SELECT
    SUM(CASE WHEN source_row_id IS NULL
             THEN 1 ELSE 0 END) AS null_source_row_id,

    SUM(CASE WHEN brand_name IS NULL
                  OR LOWER(TRIM(brand_name)) = 'nan'
                  OR brand_name = ''
             THEN 1 ELSE 0 END) AS null_brand_name,

    SUM(CASE WHEN deatils IS NULL
                  OR LOWER(TRIM(deatils)) = 'nan'
                  OR deatils = ''
             THEN 1 ELSE 0 END) AS null_deatils,

    SUM(CASE WHEN sizes IS NULL
                  OR LOWER(TRIM(sizes)) = 'nan'
                  OR sizes = ''
             THEN 1 ELSE 0 END) AS null_sizes,

    SUM(CASE WHEN mrp IS NULL
                  OR LOWER(TRIM(mrp)) = 'nan'
                  OR mrp = ''
             THEN 1 ELSE 0 END) AS null_mrp,

    SUM(CASE WHEN sell_price IS NULL
                  OR LOWER(TRIM(sell_price)) = 'nan'
                  OR sell_price = ''
             THEN 1 ELSE 0 END) AS null_sell_price,

    SUM(CASE WHEN discount IS NULL
                  OR LOWER(TRIM(discount)) = 'nan'
                  OR discount = ''
             THEN 1 ELSE 0 END) AS null_discount,

    SUM(CASE WHEN category IS NULL
                  OR LOWER(TRIM(category)) = 'nan'
                  OR category = ''
             THEN 1 ELSE 0 END) AS null_category

FROM bronze.raw_fashion;


/* 2A.3 CATEGORY DISTRIBUTION
   Assess the distribution of records across product categories.
*/

SELECT
    category,
    COUNT(*) AS row_count
FROM bronze.raw_fashion
GROUP BY category
ORDER BY row_count DESC;


/* 2A.4 MRP FORMAT VALIDATION
   Inspect common MRP formats and identify values that do not
   follow the expected 'Rs...' source format.
*/

SELECT TOP 20
    mrp,
    COUNT(*) AS row_count
FROM bronze.raw_fashion
GROUP BY mrp
ORDER BY row_count DESC;


SELECT
    COUNT(*) AS rows_not_matching_expected_mrp_pattern
FROM bronze.raw_fashion
WHERE mrp NOT LIKE 'Rs%';


/* 2A.5 DISCOUNT FORMAT VALIDATION
   Assess the consistency of discount values and identify
   text-based missing values and percentage formats.
*/

SELECT
    SUM(CASE WHEN discount = 'Nan'
             THEN 1 ELSE 0 END) AS discount_is_nan_text,

    SUM(CASE WHEN discount LIKE '%[0-9]%off%'
             THEN 1 ELSE 0 END) AS discount_is_percent,

    COUNT(DISTINCT discount) AS distinct_discount_values

FROM bronze.raw_fashion;


/* 2A.6 PRICE CONSISTENCY CHECK
   Identify records where the selling price exceeds the MRP.
*/

SELECT
    COUNT(*) AS sellprice_greater_than_mrp
FROM bronze.raw_fashion
WHERE TRY_CAST(sell_price AS DECIMAL(10,2)) >
      TRY_CAST(
          REPLACE(
              REPLACE(mrp, 'Rs', ''),
              CHAR(10),
              ''
          ) AS DECIMAL(10,2)
      );


/* 2A.7 DUPLICATE RECORDS
   Identify duplicate product records based on the available
   product attributes.
*/

SELECT
    COUNT(*) AS duplicate_rows_to_remove
FROM (
    SELECT
        brand_name,
        deatils,
        sizes,
        mrp,
        sell_price,
        discount,
        category,
        COUNT(*) AS occurrence_count
    FROM bronze.raw_fashion
    GROUP BY
        brand_name,
        deatils,
        sizes,
        mrp,
        sell_price,
        discount,
        category
    HAVING COUNT(*) > 1
) AS dupes;


/* 2A.8 SIZE PATTERN ANALYSIS
   Review common raw size formats before standardization.
*/

SELECT TOP 20
    sizes,
    COUNT(*) AS row_count
FROM bronze.raw_fashion
GROUP BY sizes
ORDER BY row_count DESC;


/* 2A.9 PRODUCT DETAILS SAMPLE
   Random sample of product descriptions for exploratory
   review of the raw text structure.
*/

SELECT TOP 20
    deatils
FROM bronze.raw_fashion
ORDER BY NEWID();


