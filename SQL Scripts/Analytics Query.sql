-- Module 1: Fast vs. Slow Moving Products

WITH weekly_sales AS (
    SELECT
        DATE_FORMAT(f.Date, '%Y-%u') AS YearWeek,
        f.Store_ID,
        f.Product_ID,
        SUM(f.Units_Sold) AS total_units_sold
    FROM Fact_Inventory f
    GROUP BY DATE_FORMAT(f.Date, '%Y-%u'), f.Store_ID, f.Product_ID
),

ranked_inventory AS (
    SELECT
        f.Store_ID,
        f.Product_ID,
        DATE_FORMAT(f.Date, '%Y-%u') AS YearWeek,
        f.Inventory_Level,
        ROW_NUMBER() OVER (
            PARTITION BY DATE_FORMAT(f.Date, '%Y-%u'), f.Store_ID, f.Product_ID
            ORDER BY f.Date DESC
        ) AS rn
    FROM Fact_Inventory f
),

inventory_end_of_week AS (
    SELECT
        YearWeek,
        Store_ID,
        Product_ID,
        Inventory_Level
    FROM ranked_inventory
    WHERE rn = 1
),

combined AS (
    SELECT
        ws.YearWeek,
        ws.Store_ID,
        ws.Product_ID,
        ws.total_units_sold,
        ie.Inventory_Level AS inventory_level_end_of_week,
        CASE 
            WHEN ws.total_units_sold > ie.Inventory_Level THEN 'Fast-Moving'
            WHEN ws.total_units_sold < ie.Inventory_Level THEN 'Slow-Moving'
            ELSE 'Balanced'
        END AS movement_category,
        ABS(ws.total_units_sold - ie.Inventory_Level) AS movement_gap
    FROM weekly_sales ws
    JOIN inventory_end_of_week ie
      ON ws.YearWeek = ie.YearWeek
     AND ws.Store_ID = ie.Store_ID
     AND ws.Product_ID = ie.Product_ID
)

SELECT *
FROM combined
ORDER BY YearWeek, Store_ID, movement_category, movement_gap DESC;


-- Module 2: ABC Analysis

WITH product_metrics AS (
    SELECT
        Store_ID,
        Product_ID,
        DATE_FORMAT(Date, '%Y-%m') AS Month,
        SUM(Units_Sold) AS total_units_sold,
        AVG(Price) AS avg_price,
        AVG(Inventory_Level) AS avg_inventory_level,
        SUM(Units_Sold * Price * (1 - Discount / 100)) AS total_revenue
    FROM Fact_Inventory
    GROUP BY Store_ID, Product_ID, DATE_FORMAT(Date, '%Y-%m')
),

revenue_with_total AS (
    SELECT *,
        SUM(total_revenue) OVER (PARTITION BY Store_ID, Month) AS total_store_month_revenue
    FROM product_metrics
),

ranked_revenue AS (
    SELECT *,
        ROUND(
            100.0 * SUM(total_revenue) OVER (
                PARTITION BY Store_ID, Month 
                ORDER BY total_revenue DESC
            ) / total_store_month_revenue,
            2
        ) AS cumulative_percent,
        SUM(total_revenue) OVER (
            PARTITION BY Store_ID, Month 
            ORDER BY total_revenue DESC
        ) AS cumulative_revenue
    FROM revenue_with_total
)

SELECT
    Store_ID,
    Month,
    Product_ID,
    total_revenue,
    ROUND(total_revenue / total_store_month_revenue * 100, 2) AS revenue_percentage,
    total_units_sold,
    ROUND(total_revenue / NULLIF(total_units_sold, 0), 2) AS avg_selling_price,
    ROUND(avg_inventory_level, 2) AS avg_inventory_level,
    cumulative_percent,
    CASE
        WHEN cumulative_percent <= 80 THEN 'A'
        WHEN cumulative_percent <= 95 THEN 'B'
        ELSE 'C'
    END AS abc_class
FROM ranked_revenue
ORDER BY Store_ID, Month, cumulative_percent;


-- Module 3: Rolling Reorder Alerts

WITH Rolling_Sales AS (
    SELECT
        Product_ID,
        Store_ID,
        Date,
        Units_Sold,
        Inventory_Level,
        AVG(Units_Sold) OVER (
            PARTITION BY Product_ID, Store_ID
            ORDER BY Date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS Reorder_Point
    FROM Fact_Inventory
)
SELECT 
    Date,
    Product_ID,
    Store_ID,
    Inventory_Level,
    ROUND(Reorder_Point, 2) AS Recommended_Reorder_Threshold,
    CASE 
        WHEN Inventory_Level <= Reorder_Point THEN 'Reorder Now'
        ELSE 'Sufficient Stock'
    END AS Status
FROM Rolling_Sales;


-- Module 4: Estimated Reorder Point Forecasting

SELECT
    Product_ID,
    Store_ID,
    Date,
    ROUND(AVG(Units_Sold) OVER (
        PARTITION BY Product_ID, Store_ID
        ORDER BY Date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS Estimated_Reorder_Point
FROM Fact_Inventory
ORDER BY Product_ID, Store_ID, Date;


-- Module 5: Category Performance Summary

SELECT
    Category,
    COUNT(DISTINCT f.Product_ID) AS unique_products,
    SUM(Units_Sold) AS total_units_sold,
    ROUND(SUM(Units_Sold * Price * (1 - Discount / 100)), 2) AS total_revenue,
    SUM(Inventory_Level) AS current_inventory_units,
    ROUND(AVG(Inventory_Level), 2) AS avg_inventory_level,
    ROUND(
        SUM(Units_Sold * Price * (1 - Discount / 100)) / NULLIF(SUM(Units_Sold), 0),
        2
    ) AS avg_selling_price,
    ROUND(SUM(Units_Sold) / NULLIF(AVG(Inventory_Level), 0), 2) AS inventory_turnover_ratio,
    SUM(CASE WHEN Units_Sold > Inventory_Level THEN 1 ELSE 0 END) AS stockout_count
FROM Fact_Inventory f
JOIN dim_products dp
ON f.Product_ID = dp.Product_ID
GROUP BY Category
ORDER BY Category, total_revenue DESC;


-- Module 6: Competitive Pricing Strategy

SELECT 
    f.Product_ID,
    dp.Category,
    ROUND(AVG(Price), 2) AS avg_our_price,
    ROUND(AVG(Competitor_Pricing), 2) AS avg_competitor_price,
    ROUND(AVG(Price - Competitor_Pricing), 2) AS avg_price_gap,
    ROUND(AVG(Units_Sold), 2) AS avg_units_sold,
    ROUND(AVG(Demand_Forecast), 2) AS avg_demand_forecast,
    CASE 
        WHEN AVG(Price) > AVG(Competitor_Pricing) AND AVG(Units_Sold) < AVG(Demand_Forecast)
            THEN 'Consider Markdown'
        WHEN AVG(Price) < AVG(Competitor_Pricing) AND AVG(Units_Sold) > AVG(Demand_Forecast)
            THEN 'Consider Price Increase'
        ELSE 'Keep Price'
    END AS pricing_action
FROM Fact_Inventory f
JOIN dim_products dp
ON f.Product_ID = dp.Product_ID
GROUP BY Product_ID, Category
ORDER BY avg_price_gap DESC;


-- Module 7: Stock Coverage and Risk Classification

WITH stock_coverage AS (
    SELECT 
        f.Product_ID,
        dp.Category,
        ROUND(SUM(Inventory_Level) / NULLIF(AVG(Units_Sold), 0), 2) AS stock_coverage_days
    FROM Fact_Inventory f
    JOIN dim_products dp ON f.Product_ID = dp.Product_ID
    GROUP BY Product_ID, Category
),

stockout_stats AS (
    SELECT 
        f.Product_ID,
        dp.Category,
        COUNT(*) AS total_entries,
        SUM(CASE WHEN Units_Sold > Inventory_Level THEN 1 ELSE 0 END) AS stockout_events,
        ROUND(100.0 * SUM(CASE WHEN Units_Sold > Inventory_Level THEN 1 ELSE 0 END) / COUNT(*), 2) AS stockout_rate
    FROM Fact_Inventory f
    JOIN dim_products dp ON f.Product_ID = dp.Product_ID
    GROUP BY Product_ID, Category
)

SELECT
    sc.Product_ID,
    sc.Category,
    sc.stock_coverage_days,
    ss.stockout_rate,
    ss.stockout_events,
    ss.total_entries,
    CASE 
        WHEN ss.stockout_rate > 50 THEN 'High Risk'
        WHEN ss.stockout_rate BETWEEN 20 AND 50 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS risk_of_lost_sales
FROM stock_coverage sc
JOIN stockout_stats ss
  ON sc.Product_ID = ss.Product_ID AND sc.Category = ss.Category
ORDER BY risk_of_lost_sales DESC, stockout_rate DESC;


-- Module 8: Forecast Accuracy and Sales Insights

SELECT 
    f.Product_ID,
    dp.Category,
    ROUND(AVG(Demand_Forecast), 2) AS avg_forecast,
    ROUND(AVG(Units_Sold), 2) AS avg_actual_sales,
    SUM(Units_Sold) AS total_actual_sales,
    ROUND(SUM(Demand_Forecast),2) AS total_forecast,
    ROUND(AVG(Units_Sold - Demand_Forecast), 2) AS forecast_error,
    ROUND(100 * AVG(ABS(Units_Sold - Demand_Forecast)) / NULLIF(AVG(Demand_Forecast), 0), 2) AS forecast_accuracy,
    ROUND(AVG(Inventory_Level), 2) AS avg_inventory_level,
    MIN(f.Date) AS first_sale_date,
    MAX(f.Date) AS last_sale_date,
    COUNT(*) AS data_points,
    SUM(CASE WHEN Units_Sold > Inventory_Level THEN 1 ELSE 0 END) AS stockout_events,
    ROUND(SUM(Units_Sold * f.Price * (1 - f.Discount / 100)), 2) AS total_revenue
FROM Fact_Inventory f
JOIN dim_products dp ON f.Product_ID = dp.Product_ID
GROUP BY dp.Category, f.Product_ID
ORDER BY forecast_accuracy DESC;
