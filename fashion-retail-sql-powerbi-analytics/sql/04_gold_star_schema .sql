
/* =========================================================
   PHASE 3 - GOLD LAYER
   Builds the analytical star schema from silver.clean_fashion.

   Fact table grain:
   One row per product_id.
   ========================================================= */

USE FashionPortfolio;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
    EXEC('create schema gold');
GO


/* =========================================================
   3.1 DIM_BRAND
   Store distinct brands and provide an 'Unknown' member
   for products with missing brand information.
   ========================================================= */

IF OBJECT_ID('gold.dim_brand', 'U') IS NOT NULL DROP TABLE gold.dim_brand;
GO

CREATE TABLE gold.dim_brand (
    brand_id   INT IDENTITY(1,1) PRIMARY KEY,
    brand_name VARCHAR(200) NOT NULL UNIQUE
);
GO

INSERT INTO gold.dim_brand (brand_name) VALUES ('Unknown');

INSERT INTO gold.dim_brand (brand_name)
SELECT DISTINCT brand_name
FROM silver.clean_fashion
WHERE brand_name IS NOT NULL;
GO


/* =========================================================
   3.2 DIM_CATEGORY
   Store unique product type and gender combinations.
   ========================================================= */

IF OBJECT_ID('gold.dim_category', 'U') IS NOT NULL DROP TABLE gold.dim_category;
GO

CREATE TABLE gold.dim_category (
    category_id  INT IDENTITY(1,1) PRIMARY KEY,
    product_type VARCHAR(100) NOT NULL,
    gender       VARCHAR(50)  NOT NULL,
    CONSTRAINT uq_category UNIQUE (product_type, gender)
);
GO

INSERT INTO gold.dim_category (product_type, gender)
SELECT DISTINCT product_type, gender
FROM silver.clean_fashion;
GO


/* =========================================================
   3.3 DIM_FABRIC
   Store distinct standardized fabric values.
   'Unspecified' is retained as a valid dimension member
   for products where no fabric could be identified.
   ========================================================= */

IF OBJECT_ID('gold.dim_fabric', 'U') IS NOT NULL DROP TABLE gold.dim_fabric;
GO

CREATE TABLE gold.dim_fabric (
    fabric_id INT IDENTITY(1,1) PRIMARY KEY,
    fabric    VARCHAR(50) NOT NULL UNIQUE
);
GO

INSERT INTO gold.dim_fabric (fabric)
SELECT DISTINCT fabric
FROM silver.clean_fashion;
GO


/* =========================================================
   3.4 FACT_PRODUCTS
   Product-level fact table with foreign keys to the
   brand, category, and fabric dimensions.

   Price tiers are based on the 33rd and 66th percentiles
   of MRP, providing data-driven price segmentation.
   ========================================================= */

IF OBJECT_ID('gold.fact_products', 'U') IS NOT NULL DROP TABLE gold.fact_products;
GO

WITH price_cutoffs AS (
    SELECT
        PERCENTILE_CONT(0.33) WITHIN GROUP (ORDER BY mrp) OVER () AS p33,
        PERCENTILE_CONT(0.66) WITHIN GROUP (ORDER BY mrp) OVER () AS p66
    FROM silver.clean_fashion
    WHERE mrp IS NOT NULL
),
cutoffs_single AS (
    SELECT DISTINCT p33, p66 FROM price_cutoffs
),
tiered AS (
    SELECT
        cf.*,
        CASE
            WHEN cf.mrp IS NULL THEN 'Unknown'
            WHEN cf.mrp <= c.p33 THEN 'Budget'
            WHEN cf.mrp <= c.p66 THEN 'Mid'
            ELSE 'Premium'
        END AS price_tier
    FROM silver.clean_fashion cf
    CROSS JOIN cutoffs_single c
)
SELECT
    t.product_id,
    COALESCE(b.brand_id, ub.brand_id) AS brand_id,
    cat.category_id,
    fab.fabric_id,
    t.mrp,
    t.sell_price,
    t.discount_pct_stated,
    t.discount_pct_computed,
    t.flag_discount_mismatch,
    t.flag_price_anomaly,
    t.price_tier
INTO gold.fact_products
FROM tiered t
LEFT JOIN gold.dim_brand b   ON b.brand_name = t.brand_name
LEFT JOIN gold.dim_brand ub  ON ub.brand_name = 'Unknown' AND t.brand_name IS NULL
JOIN gold.dim_category cat   ON cat.product_type = t.product_type AND cat.gender = t.gender
JOIN gold.dim_fabric fab     ON fab.fabric = t.fabric;
GO


/* ---------------------------------------------------------
   Define primary and foreign key constraints.
   --------------------------------------------------------- */

ALTER TABLE gold.fact_products ADD CONSTRAINT pk_fact_products PRIMARY KEY (product_id);
ALTER TABLE gold.fact_products ADD CONSTRAINT fk_fact_brand    FOREIGN KEY (brand_id)    REFERENCES gold.dim_brand(brand_id);
ALTER TABLE gold.fact_products ADD CONSTRAINT fk_fact_category FOREIGN KEY (category_id) REFERENCES gold.dim_category(category_id);
ALTER TABLE gold.fact_products ADD CONSTRAINT fk_fact_fabric   FOREIGN KEY (fabric_id)   REFERENCES gold.dim_fabric(fabric_id);
GO


/* =========================================================
   3.5 DATA MODEL VALIDATION
   Verify that the fact table preserves the silver-layer
   row count and that required foreign keys are populated.
   ========================================================= */

SELECT
    (SELECT COUNT(*) FROM silver.clean_fashion) AS silver_rows,
    (SELECT COUNT(*) FROM gold.fact_products) AS fact_rows,
    (SELECT COUNT(*)
     FROM gold.fact_products
     WHERE brand_id IS NULL) AS null_brand_fk;

