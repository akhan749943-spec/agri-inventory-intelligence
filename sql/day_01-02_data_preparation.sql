-- Creating Table 01 "warehouse"
DROP TABLE IF EXISTS warehouses;
CREATE TABLE IF NOT EXISTS warehouses(
	warehouse_id 		SERIAL PRIMARY KEY,
    warehouse_name 		VARCHAR(100) NOT NULL,
    city 				VARCHAR(50) NOT NULL,
    region 				VARCHAR(50) NOT NULL,
    capacity_units 		INT			NOT NULL
);

-- Creating Table 02 "products"
DROP TABLE IF EXISTS products;
CREATE TABLE IF NOT EXISTS products(
	product_id 			SERIAL PRIMARY KEY,
    product_name 		VARCHAR(150) 	NOT NULL,
    category 			VARCHAR(50) 	NOT NULL,
    sub_category 		VARCHAR(50) 	NOT NULL,
    unit_price 			NUMERIC(10,2) 	NOT NULL,
    unit_of_measure 	VARCHAR(20) 	NOT NULL,
    shelf_life_months 	INT,
    reorder_point 		INT 			NOT NULL,
    max_stock_level 	INT 			NOT NULL	
);


-- Creating Table 03 "suppliers"
DROP TABLE IF EXISTS suppliers;
CREATE TABLE IF NOT EXISTS suppliers(
	supplier_id 			SERIAL PRIMARY KEY,
    supplier_name 			VARCHAR(100) 	NOT NULL,
    city 					VARCHAR(50) 	NOT NULL,
    region 					VARCHAR(50) 	NOT NULL,
    lead_time_days 			INT 			NOT NULL,
    reliability_score 		NUMERIC(10,2) 	NOT NULL
);

-- Creating Table 04 "inventory"
DROP TABLE IF EXISTS inventory;
CREATE TABLE IF NOT EXISTS inventory(
    inventory_id 			SERIAL PRIMARY KEY,
    product_id 				INT REFERENCES products(product_id),
    warehouse_id 			INT REFERENCES warehouses(warehouse_id),
    current_stock 			INT NOT NULL,
    last_restocked_date 	DATE,
    expiry_date 			DATE
);

-- Creating Table 05 "sales_transactions"
DROP TABLE IF EXISTS sales_transactions;
CREATE TABLE IF NOT EXISTS sales_transactions(
    transaction_id 		SERIAL PRIMARY KEY,
    product_id 			INT REFERENCES products(product_id),
    warehouse_id 		INT REFERENCES warehouses(warehouse_id),
    supplier_id 		INT REFERENCES suppliers(supplier_id),
    sale_date 			DATE 			NOT NULL,
    quantity_sold 		INT 			NOT NULL,
    unit_price_sold 	NUMERIC(10,2) 	NOT NULL,
    total_amount 		NUMERIC(10,2) 	NOT NULL,
    customer_type 		VARCHAR(30) 	NOT NULL
);

-- VERIFYING ALL TABELS CREATED
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

-- VERIFYING ALL FOREIGN KEYS
SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name  AS referenced_table,
    ccu.column_name AS referenced_column
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
ORDER BY tc.table_name;

-- Loading files to tables
--1. warehouse data
COPY warehouses(warehouse_id, warehouse_name, city, region, capacity_units)
FROM 'E:\Data Analystics\PROJECTS FOR PORTFOLIO\PROJECT 02_Agri-Supply Inventory Intelligence\Data\warehouses.csv'
DELIMITER ','
CSV HEADER;


--2. supplier data
COPY suppliers(supplier_id, supplier_name, city, region, lead_time_days, reliability_score)
FROM 'E:\Data Analystics\PROJECTS FOR PORTFOLIO\PROJECT 02_Agri-Supply Inventory Intelligence\Data\suppliers.csv'
DELIMITER ','
CSV HEADER;


--3. products data
COPY products(product_id, product_name, category, sub_category, unit_price, unit_of_measure, shelf_life_months, reorder_point, max_stock_level)
FROM 'E:\Data Analystics\PROJECTS FOR PORTFOLIO\PROJECT 02_Agri-Supply Inventory Intelligence\Data\products.csv'
DELIMITER ','
CSV HEADER;


--4. inventory data
COPY inventory(inventory_id, product_id, warehouse_id, current_stock, last_restocked_date, expiry_date)
FROM 'E:\Data Analystics\PROJECTS FOR PORTFOLIO\PROJECT 02_Agri-Supply Inventory Intelligence\Data\inventory.csv'
DELIMITER ','
CSV HEADER;


--4. sales_transactions data
COPY sales_transactions(transaction_id, product_id, warehouse_id, supplier_id, sale_date, quantity_sold, unit_price_sold, total_amount, customer_type)
FROM 'E:\Data Analystics\PROJECTS FOR PORTFOLIO\PROJECT 02_Agri-Supply Inventory Intelligence\Data\sales_transactions.csv'
DELIMITER ','
CSV HEADER;


-- Verifying
SELECT 'warehouses' AS table_name,         COUNT(*) AS rows FROM warehouses
UNION ALL
SELECT 'suppliers',                        COUNT(*) FROM suppliers
UNION ALL
SELECT 'products',                         COUNT(*) FROM products
UNION ALL
SELECT 'inventory',                        COUNT(*) FROM inventory
UNION ALL
SELECT 'sales_transactions',               COUNT(*) FROM sales_transactions;

SELECT * FROM sales_transactions;
SELECT * FROM warehouses;


SELECT
    s.supplier_name,
    ROUND(SUM(i.current_stock * p.unit_price)::NUMERIC, 2) AS dead_stock_value_rs
FROM inventory i
JOIN products p ON i.product_id = p.product_id
JOIN sales_transactions st ON st.product_id = i.product_id
JOIN suppliers s ON st.supplier_id = s.supplier_id
WHERE i.product_id NOT IN (
    SELECT DISTINCT product_id FROM sales_transactions
    WHERE sale_date >= (SELECT MAX(sale_date) FROM sales_transactions) - INTERVAL '90 days'
)
AND i.current_stock > 0
GROUP BY s.supplier_name
ORDER BY dead_stock_value_rs DESC;