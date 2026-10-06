
/* =========================================================
   PHASE 5 - ADVANCED ANALYTICS
   Advanced analysis using window functions, ranking,
   and cumulative-share calculations against the gold
   star schema.
   ========================================================= */

USE FashionPortfolio;
GO


-- 5.1 Brand ranking within each category
--     Rank brands by catalog size within each product category.
--     DENSE_RANK assigns the same rank to tied brands.

SELECT
    c.product_type,
    b.brand_name,
    COUNT(*) AS product_count,
    DENSE_RANK() OVER (
        PARTITION BY c.product_type
        ORDER BY COUNT(*) DESC
    ) AS brand_rank_in_category
FROM gold.fact_products f
JOIN gold.dim_brand b    ON b.brand_id = f.brand_id
JOIN gold.dim_category c ON c.category_id = f.category_id
WHERE b.brand_name <> 'Unknown'
GROUP BY c.product_type, b.brand_name
ORDER BY c.product_type, brand_rank_in_category;


-- 5.2 Pareto analysis of brand concentration
--     Measure the cumulative share of the product catalog
--     represented by brands ranked by catalog size.

WITH brand_counts AS (
    SELECT
        b.brand_name,
        COUNT(*) AS product_count
    FROM gold.fact_products f
    JOIN gold.dim_brand b ON b.brand_id = f.brand_id
    WHERE b.brand_name <> 'Unknown'
    GROUP BY b.brand_name
),
ranked AS (
    SELECT
        brand_name,
        product_count,
        ROW_NUMBER() OVER (ORDER BY product_count DESC) AS brand_rank,
        SUM(product_count) OVER (ORDER BY product_count DESC
                                  ROWS UNBOUNDED PRECEDING) AS running_total,
        SUM(product_count) OVER () AS grand_total
    FROM brand_counts
)
SELECT
    brand_rank,
    brand_name,
    product_count,
    running_total,
    CAST(ROUND(100.0 * running_total / grand_total, 2) AS DECIMAL(5,2)) AS cumulative_pct_of_catalog
FROM ranked
ORDER BY brand_rank;


-- 5.3 Discount depth by price tier
--     Compare discount levels across Budget, Mid,
--     Premium, and Unknown price tiers.

SELECT
    price_tier,
    COUNT(*)                                              AS product_count,
    CAST(AVG(discount_pct_stated) AS DECIMAL(10,2))       AS avg_discount_pct,
    CAST(MIN(discount_pct_stated) AS DECIMAL(10,2))       AS min_discount_pct,
    CAST(MAX(discount_pct_stated)      AS DECIMAL(10,2))       AS max_discount_pct
FROM gold.fact_products
GROUP BY price_tier
ORDER BY
    CASE price_tier WHEN 'Budget' THEN 1 WHEN 'Mid' THEN 2 WHEN 'Premium' THEN 3 ELSE 4 END;


-- 5.4 Top discounted brand within each category
--     Identify the brand with the highest average stated
--     discount in each category.
--     Brands with fewer than five products are excluded
--     to reduce the impact of small samples.

WITH brand_discounts AS (
    SELECT
        c.product_type,
        b.brand_name,
        AVG(f.discount_pct_stated) AS avg_discount_pct,
        COUNT(*)                   AS product_count
    FROM gold.fact_products f
    JOIN gold.dim_brand b    ON b.brand_id = f.brand_id
    JOIN gold.dim_category c ON c.category_id = f.category_id
    WHERE b.brand_name <> 'Unknown'
    GROUP BY c.product_type, b.brand_name
    HAVING COUNT(*) >= 5   -- ignore brands with too few products to be meaningful
)
SELECT
    product_type,
    brand_name,
    avg_discount_pct,
    product_count
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY product_type
            ORDER BY avg_discount_pct DESC
        ) AS rn
    FROM brand_discounts
) ranked
WHERE rn = 1
ORDER BY avg_discount_pct DESC;


-- 5.5 Relative price position within category
--     Determine each product's percentile position based
--     on MRP relative to other products in the same category.
--     This supports relative pricing analysis across categories.

SELECT
    f.product_id,
    b.brand_name,
    c.product_type,
    f.mrp,
    CAST(ROUND(
        PERCENT_RANK() OVER (
            PARTITION BY c.product_type
            ORDER BY f.mrp
        ) * 100, 1
    ) AS DECIMAL(5,1)) AS price_percentile_in_category
FROM gold.fact_products f
JOIN gold.dim_brand b    ON b.brand_id = f.brand_id
JOIN gold.dim_category c ON c.category_id = f.category_id
WHERE f.mrp IS NOT NULL
ORDER BY c.product_type, price_percentile_in_category DESC;

