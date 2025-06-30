CREATE TABLE dim_Products (
    Product_ID VARCHAR(10) PRIMARY KEY,
    Category VARCHAR(50)
);

CREATE TABLE dim_Stores(
    store_id VARCHAR(10),
    region VARCHAR(50),
    PRIMARY KEY (store_id, region)
);

CREATE TABLE fact_Inventory (
    Date DATE,
    Store_ID VARCHAR(10),
    Product_ID VARCHAR(10),
    region VARCHAR(50),
    Inventory_Level INT,
    Units_Sold INT,
    Units_Ordered INT,
    Demand_Forecast FLOAT,
    Price FLOAT,
    Discount INT,
    Competitor_Pricing FLOAT,
    FOREIGN KEY (store_id, region) REFERENCES dim_Stores(store_id, region),
    FOREIGN KEY (product_id) REFERENCES dim_Products(product_id)
);

CREATE TABLE Weather(
    date DATE,
    store_id VARCHAR(10),
    region VARCHAR(50),
    weather_condition VARCHAR(20),
    holiday_promotion BOOLEAN,
    seasonality VARCHAR(20),
    PRIMARY KEY (date, store_id, region),
    FOREIGN KEY (store_id, region) REFERENCES dim_Stores(store_id, region)
);