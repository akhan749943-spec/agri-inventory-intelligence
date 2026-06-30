-- ==== DATA VERIFICATION ==== --
-- NULL Checks
    -- Checking nulls in inventory
SELECT 
    COUNT(*) FILTER (WHERE product_id is NULL)          AS null_product_id,
    COUNT(*) FILTER (WHERE warehouse_id is NULL)        AS null_warehouse_id,
    COUNT(*) FILTER (WHERE current_stock IS NULL)      AS null_current_stock,
    COUNT(*) FILTER (WHERE last_restocked_date IS NULL)AS null_restock_date,
    COUNT(*) FILTER (WHERE expiry_date IS NULL)        AS null_expiry_date
FROM inventory;

-- Checking nulls in sales_transactions
SELECT 
    COUNT(*) FILTER (WHERE product_id is NULL)          AS null_product_id,
    COUNT(*) FILTER (WHERE sale_date is NULL)          AS null_sales_date,
    COUNT(*) FILTER (WHERE quantity_sold IS NULL)            AS null_qnt,
    COUNT(*) FILTER (WHERE total_amount IS NULL)           AS null_amt
FROM sales_transactions;

-- Basic Counts & Ranges
    -- Products by category
    SELECT category, COUNT(*) as product_count
    FROM products
    GROUP BY category
    ORDER BY product_count;

    -- Stock range in inventory
    SELECT
        MIN(current_stock) as min_stock,
        MAX(current_stock) as max_stock,
        AVG(current_stock) :: NUMERIC(10,2) as avg_stock,
        SUM(current_stock) as total_units_in_stocks
    FROM inventory;

    -- Sales date range and total transactions
    SELECT
        MIN(sale_date) as first_sale,
        MAX(sale_date) as last_sale,
        COUNT(*) as total_transactions,
        SUM(total_amount) as total_revenue
    FROM sales_transactions;

    -- Supplier reliability range
    SELECT
        MIN(reliability_score) as min_reliability,
        MAX(reliability_score) as max_reliability,
        AVG(reliability_score) :: NUMERIC(10,2) as avg_reliability,
        MIN(lead_time_days) as fastest_supplier,
        MAX(lead_time_days) as slowest_supplier
    FROM suppliers;

    -- Warehouse capacity overview
    SELECT
        region,
        COUNT(*) AS warehouse_count,
        SUM(capacity_units) AS total_capacity,
        AVG(capacity_units) :: NUMERIC(10,2) as avg_capacity
    FROM warehouses
    GROUP BY region
    ORDER BY total_capacity DESC;

-- TESTING JOINs
    --JOIN 1: Products with their current inventory levels
    SELECT
        p.product_name,
        p.category,
        w.city,
        w.region,
        i.current_stock,
        i.last_restocked_date
    FROM inventory i
    JOIN products p ON i.product_id = p.product_id
    JOIN warehouses w ON i.warehouse_id = w.warehouse_id
    ORDER BY p.category, w.region
    LIMIT 20;

    --JOIN 2: Sales with product and warehouse details
    SELECT
        st.sale_date,
        p.product_name,
        p.category,
        w.city,
        st.quantity_sold,
        st.total_amount,
        st.customer_type
    FROM sales_transactions st
    JOIN products p ON st.product_id = p.product_id
    JOIN warehouses w ON st.warehouse_id = w.warehouse_id
    ORDER BY sale_date DESC
    LIMIT 20;

    -- JOIN 3: All 5 tables together
    SELECT
        p.product_name,
        p.category,
        w.city,
        s.supplier_name,
        s.lead_time_days,
        i.current_stock,
        st.sale_date,
        st.quantity_sold
    FROM sales_transactions st
    JOIN products p ON st.product_id = p.product_id
    JOIN warehouses w ON st.warehouse_id = w.warehouse_id
    JOIN suppliers s ON st.supplier_id = s.supplier_id
    JOIN inventory i ON i.product_id = st.product_id
                    AND i.warehouse_id = st.warehouse_id
    ORDER BY sale_date DESC
    LIMIT 10;


-- 5 Exploration Queries
    -- Q1: How many distinct products are being sold?
    SELECT
        COUNT(DISTINCT product_id) AS products_with_sales
    FROM sales_transactions;

    -- Q2: Which customer type generates most revenue?
    SELECT
        customer_type,
        SUM(total_amount) AS total_revenue,
        COUNT(*) AS total_transactions,
        AVG(total_amount) :: NUMERIC(10,2) AS avg_order_value
    FROM sales_transactions
    GROUP BY customer_type
    ORDER BY total_revenue DESC;

    -- Q3: Which warehouse has most inventory items?
    SELECT
        w.city,
        w.region,
        COUNT(*) AS inventory_items,
        SUM(i.current_stock) AS total_stock_units
    FROM warehouses w
    JOIN inventory i ON w.warehouse_id = i.warehouse_id
    GROUP BY w.city, w.region
    ORDER BY total_stock_units DESC;

    -- Q4: What is the price range across categories?
    SELECT
        category,
        MIN(unit_price) AS min_price,
        MAX(unit_price) AS max_price,
        AVG(unit_price) :: NUMERIC(10,2) AS avg_price
    FROM products
    GROUP BY category
    ORDER BY avg_price DESC;

    -- Q5: Which month had highest sales?
    SELECT
        TO_CHAR(sale_date, 'YYYY-MM') AS month,
        COUNT(*) AS transaction,
        SUM(quantity_sold) AS units_sold,
        SUM(total_amount) AS revenue
    FROM sales_transactions
    GROUP BY TO_CHAR(sale_date, 'YYYY-MM')
    ORDER BY revenue DESC
    LIMIT 5;


-- Confirm dead stock is now real
    SELECT COUNT(DISTINCT product_id) AS products_with_no_recent_sales
    FROM inventory
    WHERE product_id NOT IN (
        SELECT DISTINCT product_id
        FROM sales_transactions
        WHERE sale_date >= (SELECT MAX(sale_date) 
                        FROM sales_transactions) 
                        - INTERVAL '90 days'
    );