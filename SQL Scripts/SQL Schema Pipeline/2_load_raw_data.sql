LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/inventory_forecasting.csv'
INTO TABLE InventoryForecasting
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;