
# Fashion E-Commerce Pricing & Discount Analytics

A SQL + Power BI portfolio project built on a messy, real-world Kaggle fashion dataset (30,785 rows). The goal: turn raw, inconsistent scraped data into a clean warehouse and a one-page dashboard that actually says something.

## Dataset

The dataset used in this project is sourced from Kaggle:

[Kaggle — E-commerce Dataset](https://www.kaggle.com/datasets/mehrajalomtapadar/e-commerce-dataset?utm_source=chatgpt.com)

## What's in here

```text
sql/        bronze -> profiling -> silver -> gold -> EDA -> advanced analytics -> reporting view
python/     bronze load script (handles embedded newlines in the raw CSV)
dataset/    the original Kaggle CSV
powerbi/    the .pbix and a build plan
screenshots/  the final dashboard
```

## Architecture

Built as a medallion pipeline in SQL Server:

* **Bronze** — the CSV loaded exactly as-is, no cleaning, for traceability
* **Silver** — cleaned and typed: prices parsed out of `"Rs\n1699"`-style text, discounts extracted from `"50% off"`, category split into type + gender, fabric pulled from free-text descriptions, sizes normalized into their own table
* **Gold** — a proper star schema (`fact_products` + `dim_brand`, `dim_category`, `dim_fabric`), with a data-driven price tier (Budget/Mid/Premium) based on percentile cutoffs, not arbitrary thresholds
* **Reporting view** — one flat, pre-joined view sitting on top of gold, for anyone who wants everything in one place without writing the joins

Python was used only where it earned its place: the raw file has quoted fields with embedded newlines (`Rs\n1699`), which plain `BULK INSERT` handles badly. Pandas parses it correctly, so Python loads bronze; everything else is SQL.

## Data quality — what I found and what I did about it

* **938 exact duplicate rows** (≈3.05% of the raw file) — removed. Not because the rate was small, but because a duplicate row double-counts a product in any aggregate; the low rate is just a reassuring sign the rest of the data is reasonably clean.
* **~24% of products have no MRP recorded.** Kept as genuine `NULL`, not zero — a missing price isn't the same claim as a free product, and treating it as `0` would quietly drag down every price-based average.
* **`'Nan'` and `'Error Size'` in the sizes field** are source-system sentinels, not real values — excluded from the sizes table rather than inserted as fake data.
* **Size abbreviations were inconsistent** (`XL` and `X-Large` meant the same thing, written two ways) — standardized so they don't fragment into separate values.
* **Color extraction was dropped entirely.** It relied on guessing a product's color from the last few words of its description, which broke badly on perfumes, jewelry, and watches (returning SKUs and ml volumes instead of colors). Rather than patch around it, I cut the feature — a deliberate call that a weak signal isn't worth the risk of shipping something misleading.
* **Fabric is only meaningful for clothing categories.** Watches, Jewellery, and Fragrance correctly show "Unspecified" fabric — that's not missing data, it's the right answer for products that don't have one.

## Key findings

**1. Discount depth is flat across price tiers.**
Budget (45.4%), Mid (43.8%), and Premium (44.4%) are discounted almost identically — under a 2-point spread. There's no sign of targeting cheap items harder to drive volume, or expensive items harder to clear stock. One sharp side note: the ~6,750 products with missing price data also show *exactly* 0% discount with zero variance — not a coincidence, but a single data gap showing up in two fields at once.

**2. The brand base has a long tail, not a concentrated core.**
The top 15 of 274 brands (5.5%) account for 36.4% of the catalog — more spread out than a classic 80/20 pattern. It takes roughly 100 brands to reach 80% coverage. At the other end, 39 brands (14% of the list) have exactly one product each — several are recognizable luxury names (Gucci, Burberry, Versace) likely carried for catalog breadth rather than volume.

**3. Category price points vary enormously, and averages can be misleading.**
Watches average ₹9,521 — 7.5x Lingerie&Nightwear's ₹1,268, the cheapest category. But Watches' own range (₹1,395–32,995) is so wide that "average" barely describes it; it spans accessible to ultra-luxury within one category. Lingerie&Nightwear, by contrast, is consistently cheap — both its average and its range stay tight.

**4. Price and discount depth are only weakly related.**
Correlation across categories: -0.35 — weak. The cheapest category isn't the most discounted (Lingerie&Nightwear sits mid-pack at 41.8%), and the most discounted category (Indianwear, 50.6%) isn't the cheapest. The one real pattern is at the extremes: Watches and Fragrance, the two priciest categories, are also the two least discounted — premium categories seem somewhat protected from markdowns, but price doesn't predict discount depth anywhere else in the catalog.

