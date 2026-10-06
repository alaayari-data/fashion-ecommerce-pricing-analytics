
/* =========================================================
   PHASE 6 (PREP) - REPORTING VIEW
   Creates a flat, denormalized reporting view on top of
   the gold star schema for Power BI consumption.

   The gold layer remains normalized for data integrity,
   while this view provides a simplified analytical structure.

   Grain: one row per product_id, matching gold.fact_products.
   ========================================================= */

USE FashionPortfolio;
GO


IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'rpt')
    EXEC('CREATE SCHEMA rpt');
GO


IF OBJECT_ID('rpt.vw_fashion_dashboard', 'V') IS NOT NULL
    DROP VIEW rpt.vw_fashion_dashboard;
GO


CREATE VIEW rpt.vw_fashion_dashboard AS
SELECT
    f.product_id,
    b.brand_name,
    c.product_type,
    c.gender,
    fab.fabric,
    f.mrp,
    f.sell_price,
    f.discount_pct_stated,
    f.discount_pct_computed,
    f.price_tier,
    f.flag_discount_mismatch,
    f.flag_price_anomaly
FROM gold.fact_products f
JOIN gold.dim_brand b    ON b.brand_id = f.brand_id
JOIN gold.dim_category c ON c.category_id = f.category_id
JOIN gold.dim_fabric fab ON fab.fabric_id = f.fabric_id;
GO


/* =========================================================
   REPORTING VIEW VALIDATION
   Verify that the reporting view preserves the same
   row count as gold.fact_products.
   ========================================================= */

SELECT
    (SELECT COUNT(*) FROM gold.fact_products)       AS fact_rows,
    (SELECT COUNT(*) FROM rpt.vw_fashion_dashboard) AS view_rows;

