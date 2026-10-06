
/* =========================================================
   PHASE 4 - EXPLORATORY DATA ANALYSIS
   Business-focused analysis performed against the gold
   star schema.

   Each query addresses a specific analytical question
   and can be executed independently.
   ========================================================= */

USE FashionPortfolio;
GO


-- 4.1 Catalog size and price range by category
--     Assess product assortment size and MRP distribution
--     across product categories.

SELECT
    c.product_type,
    COUNT(*)                         AS product_count,
    ROUND(AVG(f.mrp),2)                      AS avg_mrp,
    MIN(f.mrp)                       AS min_mrp,
    MAX(f.mrp)                       AS max_mrp
FROM gold.fact_products f
JOIN gold.dim_category c ON c.category_id = f.category_id
GROUP BY c.product_type
ORDER BY product_count DESC;


-- 4.2 Discount depth by category
--     Compare average and observed discount levels
--     across product categories.

SELECT
    c.product_type,
    CAST(AVG(f.discount_pct_stated)  AS  DECIMAL(10,2))  AS avg_discount_pct,
    MIN(f.discount_pct_stated) AS min_discount_pct,
    MAX(f.discount_pct_stated) AS max_discount_pct
FROM gold.fact_products f
JOIN gold.dim_category c ON c.category_id = f.category_id
GROUP BY c.product_type
ORDER BY avg_discount_pct DESC;


-- 4.3 Price tier distribution by category
--     Analyze the distribution of products across the
--     price tiers defined in the gold layer.

SELECT
    c.product_type,
    f.price_tier,
    COUNT(*) AS product_count
FROM gold.fact_products f
JOIN gold.dim_category c ON c.category_id = f.category_id
GROUP BY c.product_type, f.price_tier
ORDER BY c.product_type, f.price_tier;


-- 4.4 Top 15 brands by catalog size
--     Identify brands with the largest product assortment,
--     excluding the 'Unknown' bucket.

SELECT TOP 15
    b.brand_name,
    COUNT(*)                   AS product_count,
    ROUND(AVG(f.discount_pct_stated),2) AS avg_discount_pct
FROM gold.fact_products f
JOIN gold.dim_brand b ON b.brand_id = f.brand_id
WHERE b.brand_name <> 'Unknown'
GROUP BY b.brand_name
ORDER BY product_count DESC;


-- 4.5 Fabric distribution
--     Analyze fabric distribution within clothing categories.
--     Watches, Jewellery, and Fragrance are excluded because
--     fabric is not a relevant product attribute for these categories.

SELECT
    fab.fabric,
    COUNT(*) AS product_count
FROM gold.fact_products f
JOIN gold.dim_fabric fab   ON fab.fabric_id = f.fabric_id
JOIN gold.dim_category c   ON c.category_id = f.category_id
WHERE c.product_type IN ('Westernwear', 'Indianwear', 'Lingerie&Nightwear')
GROUP BY fab.fabric
ORDER BY product_count DESC;


-- 4.6 Data quality exception review
--     Inspect products with discount mismatches or price anomalies,
--     together with their brand and category context.

SELECT TOP 20
    f.product_id,
    b.brand_name,
    c.product_type,
    f.mrp,
    f.sell_price,
    f.discount_pct_stated,
    f.discount_pct_computed,
    f.flag_discount_mismatch,
    f.flag_price_anomaly
FROM gold.fact_products f
JOIN gold.dim_brand b    ON b.brand_id = f.brand_id
JOIN gold.dim_category c ON c.category_id = f.category_id
WHERE f.flag_discount_mismatch = 1 OR f.flag_price_anomaly = 1
ORDER BY f.flag_price_anomaly DESC, f.product_id;


-- 4.7 Size coverage by category
--     Measure the number of distinct sizes offered and the
--     number of products with available size information.

SELECT
    c.product_type,
    COUNT(DISTINCT ps.size)                         AS distinct_sizes_offered,
    COUNT(DISTINCT f.product_id)                     AS products_with_size_data
FROM gold.fact_products f
JOIN gold.dim_category c  ON c.category_id = f.category_id
JOIN silver.product_sizes ps ON ps.product_id = f.product_id
GROUP BY c.product_type
ORDER BY products_with_size_data DESC;


-- 4.8 Price tier completeness
--     Verify the distribution of price tiers and identify
--     products assigned to 'Unknown' because MRP was NULL.

SELECT price_tier, COUNT(*) AS product_count
FROM gold.fact_products
GROUP BY price_tier
ORDER BY product_count DESC;

