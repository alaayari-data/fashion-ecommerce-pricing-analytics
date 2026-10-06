
/* =========================================================
   PHASE 2 (PART B) - SILVER LAYER
   Cleans, standardizes, and structures data from
   bronze.raw_fashion based on issues identified during
   the bronze-layer profiling.
   ========================================================= */

USE FashionPortfolio;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
    EXEC('CREATE SCHEMA silver');
GO


/* =========================================================
   2B.1 DE-DUPLICATION
   Remove duplicate product records while preserving the
   original source index for traceability.

   source_row_id is the original Kaggle product index and
   is not guaranteed to be unique. It is therefore preserved
   as source_product_index rather than used as the primary key.

   A new unique product_id is generated for each deduplicated row.
   ========================================================= */

IF OBJECT_ID('tempdb..#deduped') IS NOT NULL
    DROP TABLE #deduped;

WITH deduplicated AS
(
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY 
                   brand_name,
                   deatils,
                   sizes,
                   mrp,
                   sell_price,
                   discount,
                   category
               ORDER BY source_row_id
           ) AS rn
    FROM bronze.raw_fashion
)
SELECT
    ROW_NUMBER() OVER (ORDER BY source_row_id) AS product_id,
    source_row_id AS source_product_index,
    brand_name,
    deatils,
    sizes,
    mrp,
    sell_price,
    discount,
    category
INTO #deduped
FROM deduplicated
WHERE rn = 1;


DECLARE @raw_count INT = (
    SELECT COUNT(*)
    FROM bronze.raw_fashion
);

DECLARE @deduped_count INT = (
    SELECT COUNT(*)
    FROM #deduped
);

PRINT CONCAT(
    'Raw rows: ', @raw_count,
    ' | After dedup: ', @deduped_count,
    ' | Duplicates removed: ', @raw_count - @deduped_count
);


/* =========================================================
   2B.2 BUILD SILVER.CLEAN_FASHION
   Convert raw fields into analytical data types and derive
   standardized product attributes and quality indicators.
   ========================================================= */

IF OBJECT_ID('silver.clean_fashion', 'U') IS NOT NULL
    DROP TABLE silver.clean_fashion;
GO


WITH parsed AS
(
    SELECT
        d.product_id,
        d.source_product_index,

        CASE
            WHEN d.brand_name IS NULL
              OR LOWER(TRIM(d.brand_name)) = 'nan'
              OR LOWER(TRIM(d.brand_name)) = ''
            THEN NULL
            ELSE LTRIM(RTRIM(LOWER(d.brand_name)))
        END AS brand_name,

        d.deatils AS product_details,

        LEFT(
            d.category,
            CHARINDEX('-', d.category) - 1
        ) AS product_type,

        RIGHT(
            d.category,
            LEN(d.category) - CHARINDEX('-', d.category)
        ) AS gender,

        TRY_CAST(
            LTRIM(
                RTRIM(
                    REPLACE(
                        REPLACE(d.mrp, 'Rs', ''),
                        CHAR(10),
                        ''
                    )
                )
            )
            AS DECIMAL(10,2)
        ) AS mrp,

        TRY_CAST(
            d.sell_price AS DECIMAL(10,2)
        ) AS sell_price,

        CASE
            WHEN LOWER(TRIM(d.discount)) = 'nan'
                THEN 0
            ELSE TRY_CAST(
                LEFT(
                    d.discount,
                    CHARINDEX('%', d.discount) - 1
                )
                AS DECIMAL(5,2)
            )
        END AS discount_pct_stated,

        /* Extract the first matching fabric keyword from product details */
        CASE
            WHEN LOWER(d.deatils) LIKE '%cotton%'     THEN 'Cotton'
            WHEN LOWER(d.deatils) LIKE '%polyester%'  THEN 'Polyester'
            WHEN LOWER(d.deatils) LIKE '%rayon%'      THEN 'Rayon'
            WHEN LOWER(d.deatils) LIKE '%viscose%'    THEN 'Viscose'
            WHEN LOWER(d.deatils) LIKE '%georgette%'  THEN 'Georgette'
            WHEN LOWER(d.deatils) LIKE '%chiffon%'    THEN 'Chiffon'
            WHEN LOWER(d.deatils) LIKE '%denim%'      THEN 'Denim'
            WHEN LOWER(d.deatils) LIKE '%silk%'       THEN 'Silk'
            WHEN LOWER(d.deatils) LIKE '%linen%'      THEN 'Linen'
            WHEN LOWER(d.deatils) LIKE '%crepe%'      THEN 'Crepe'
            WHEN LOWER(d.deatils) LIKE '%velvet%'     THEN 'Velvet'
            WHEN LOWER(d.deatils) LIKE '%net%'        THEN 'Net'
            WHEN LOWER(d.deatils) LIKE '%lace%'       THEN 'Lace'
            WHEN LOWER(d.deatils) LIKE '%satin%'      THEN 'Satin'
            WHEN LOWER(d.deatils) LIKE '%nylon%'      THEN 'Nylon'
            WHEN LOWER(d.deatils) LIKE '%wool%'       THEN 'Wool'
            ELSE 'Unspecified'
        END AS fabric

    FROM #deduped d
)


SELECT
    product_id,
    source_product_index,
    brand_name,
    product_details,
    product_type,
    gender,
    mrp,
    sell_price,
    discount_pct_stated,

    /* Calculate discount percentage from MRP and selling price */
    CAST(
        ROUND(
            (mrp - sell_price)
            / NULLIF(mrp, 0) * 100,
            2
        )
        AS DECIMAL(5,2)
    ) AS discount_pct_computed,

    /* Flag significant differences between stated and computed discount */
    CASE
        WHEN ABS(
            discount_pct_stated
            -
            ROUND(
                (mrp - sell_price)
                / NULLIF(mrp, 0) * 100,
                2
            )
        ) > 2
        THEN 1
        ELSE 0
    END AS flag_discount_mismatch,

    /* Flag records where selling price exceeds MRP */
    CASE
        WHEN sell_price > mrp THEN 1
        ELSE 0
    END AS flag_price_anomaly,

    fabric

INTO silver.clean_fashion
FROM parsed;
GO


/* ---------------------------------------------------------
   Define product_id as the primary key.
   --------------------------------------------------------- */

ALTER TABLE silver.clean_fashion
ALTER COLUMN product_id INT NOT NULL;
GO

ALTER TABLE silver.clean_fashion
ADD CONSTRAINT pk_clean_fashion
PRIMARY KEY (product_id);
GO


/* =========================================================
   2B.3 BUILD SILVER.PRODUCT_SIZES
   Normalize multi-valued size fields into a one-to-many
   structure.

   Example:
   "Size:Large,Medium,Small" -> one row per size.

   Missing and invalid size values are excluded.
   ========================================================= */

IF OBJECT_ID('silver.product_sizes', 'U') IS NOT NULL
    DROP TABLE silver.product_sizes;
GO


WITH cte AS
(
    SELECT
        Cast(d.product_id as INT) as product_id,

        CASE
            WHEN TRIM(x.value) = 'X-Small'   THEN 'XS'
            WHEN TRIM(x.value) = 'XX-Small'  THEN 'XXS'
            WHEN TRIM(x.value) = 'X-Large'   THEN 'XL'
            WHEN TRIM(x.value) = 'XX-Large'  THEN 'XXL'
            WHEN TRIM(x.value) = 'XXX-Large' THEN 'XXXL'
            WHEN TRIM(x.value) = '4X-Large'  THEN '4XL'
            WHEN TRIM(x.value) = '5X-Large'  THEN '5XL'
            WHEN TRIM(x.value) = 'Small'     THEN 'S'
            WHEN TRIM(x.value) = 'Medium'    THEN 'M'
            WHEN TRIM(x.value) = 'Large'     THEN 'L'
            WHEN TRIM(x.value) like '%FRSZ%'      THEN 'FREE SIZE'
            ELSE TRIM(x.value)
        END AS standardized_size

    FROM #deduped d

    CROSS APPLY STRING_SPLIT(
        REPLACE(
            REPLACE(d.sizes, 'Size:', ''),
            '/',
            ','
        ),
        ','
    ) AS x

    WHERE TRIM(d.sizes) IS NOT NULL
      AND LTRIM(RTRIM(x.value)) NOT IN
          ('Nan', 'Error Size', '')
)


SELECT
    product_id,
    standardized_size AS size

INTO silver.product_sizes
FROM cte;
GO


/* ---------------------------------------------------------
   Define the foreign key relationship to clean_fashion.
   --------------------------------------------------------- */

ALTER TABLE silver.product_sizes
ADD CONSTRAINT fk_product_sizes_clean_fashion
FOREIGN KEY (product_id)
REFERENCES silver.clean_fashion(product_id);
GO


/* =========================================================
   2B.4 DATA QUALITY SUMMARY
   Summarize key data-quality indicators after the
   silver-layer transformations.
   ========================================================= */

SELECT
    (SELECT COUNT(*)
     FROM bronze.raw_fashion)
        AS raw_row_count,

    (SELECT COUNT(*)
     FROM silver.clean_fashion)
        AS silver_row_count,

    (SELECT COUNT(*)
     FROM silver.clean_fashion
     WHERE flag_discount_mismatch = 1)
        AS discount_mismatches,

    (SELECT COUNT(*)
     FROM silver.clean_fashion
     WHERE flag_price_anomaly = 1)
        AS price_anomalies,

    (SELECT COUNT(*)
     FROM silver.clean_fashion
     WHERE fabric = 'Unspecified')
        AS fabric_unresolved,

    (SELECT COUNT(*)
     FROM silver.clean_fashion
     WHERE brand_name IS NULL)
        AS brand_missing,

    (SELECT COUNT(DISTINCT product_id)
     FROM silver.product_sizes)
        AS products_with_sizes;

