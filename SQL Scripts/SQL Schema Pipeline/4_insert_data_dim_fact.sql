INSERT IGNORE INTO dim_Products(product_id, category)
SELECT DISTINCT product_id, category FROM inventory_forecasting;

INSERT IGNORE INTO dim_stores(store_id, region)
SELECT DISTINCT store_id, region FROM inventory_forecasting;

INSERT INTO fact_Inventory(
    date, store_id, product_id, region, 
    inventory_level, units_sold, units_ordered, 
    demand_forecast, Price, Discount, Competitor_Pricing
)
SELECT 
    date, store_id, product_id, region, 
    inventory_level, units_sold, units_ordered, 
    demand_forecast, Price, Discount, Competitor_Pricing
FROM Inventory_forecasting;

INSERT IGNORE INTO weather (
    date, store_id, region, weather_condition, holiday_promotion, seasonality
)
SELECT DISTINCT
    date, store_id, region, weather_condition, holiday_promotion, seasonality
FROM Inventory_forecasting;