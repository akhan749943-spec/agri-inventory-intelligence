-- DEAD STOCK ANALYSIS

-- Reference Date
SELECT MAX(sale_date) AS reference_date
FROM sales_transactions;

-- Total Dead Stock Value by Category
    -- Finding dead stock products first:
    SELECT
        DISTINCT product_id
    FROM sales_transactions
    WHERE sale_date >= (
        SELECT
            MAX(sale_date)
        FROM sales_transactions)
        - INTERVAL '90 days'

    -- Getting dead stock with category and value:
        SELECT
            p.category,
            COUNT(*)                                                AS dead_record,
            SUM(i.current_stock)                                    AS total_dead_units,
            ROUND(SUM(i.current_stock * p.unit_price)::NUMERIC, 2)  AS dead_stock_value_rs
        FROM inventory i
        JOIN products p ON i.product_id = p.product_id
        WHERE i.product_id NOT IN (
                SELECT
                    DISTINCT product_id
                FROM sales_transactions
                WHERE sale_date >= (SELECT MAX(sale_date) FROM sales_transactions)
                    - INTERVAL '90 days'
                )
                AND i.current_stock > 0
        GROUP BY p.category
        ORDER BY dead_stock_value_rs DESC;


-- Which Supplier's Products Become Dead Stock Most?
    SELECT
        s.supplier_name,
        s.reliability_score,
        COUNT(DISTINCT i.product_id)    AS dead__products,
        (SUM(i.current_stock * p.unit_price)) :: NUMERIC   AS dead_stock_value_rs
    FROM inventory i
    JOIN products p ON i.product_id = p.product_id
    JOIN sales_transactions st ON st.product_id = i.product_id
    JOIN suppliers s ON st.supplier_id = s.supplier_id
    WHERE i.product_id NOT IN(
        SELECT DISTINCT product_id FROM sales_transactions
        WHERE sale_date >= (SELECT MAX(sale_date) FROM sales_transactions) - INTERVAL '90 days'
        )
        AND i.current_stock > 0
    GROUP BY s.supplier_id, s.reliability_score
    ORDER BY dead_stock_value_rs DESC;


-- Which Warehouse Has Highest Dead Stock?
    SELECT
        w.warehouse_name,
        w.city,
        w.region,
        COUNT(*)        AS dead_stock_items,
        SUM(i.current_stock)    AS total_dead_units,
        (SUM(i.current_stock * p.unit_price)) :: NUMERIC    AS dead_stock_value_rs
    FROM inventory i
    JOIN products p ON i.product_id = p.product_id
    JOIN warehouses w ON i.warehouse_id = w.warehouse_id
    WHERE i.product_id NOT IN(
        SELECT DISTINCT product_id FROM sales_transactions
        WHERE sale_date >= (
            SELECT MAX(sale_date) FROM sales_transactions)
            - INTERVAL '90 Days'
        )
        AND i.current_stock > 0
    GROUP BY  w.region, w.warehouse_name, w.city
    ORDER BY dead_stock_value_rs DESC;


-- What % of Total Inventory is Dead Stock?     Formula = Dead Stock Value / Total Inventory Value * 100
    SELECT
        ROUND(
            SUM(
                CASE
                    WHEN i.product_id NOT IN (
                        SELECT product_id FROM sales_transactions
                        WHERE sale_date >= (
                            SELECT MAX(sale_date) FROM sales_transactions) 
                            - INTERVAL '90 Days'
                    )
                THEN (i.current_stock * p.unit_price)
                ELSE 0
            END) :: NUMERIC /
            NULLIF(SUM(i.current_stock * p.unit_price),0) * 100
        ,2)     AS dead_stock_pct_of_total
    FROM inventory i
    JOIN products p ON i.product_id = p.product_id;


-- Products Sitting Longest Without a Sale
    SELECT
        p.product_name,
        p.category,
        w.city,
        i.current_stock,
        (i.current_stock * p.unit_price) :: NUMERIC(10,1)   AS stock_value_rs,
        i.last_restocked_date,
        (SELECT MAX(sale_date) 
        FROM sales_transactions) - i.last_restocked_date    AS days_sitting
    FROM inventory i
    JOIN products p ON i.product_id = p.product_id
    JOIN warehouses w ON i.warehouse_id = w.warehouse_id
    WHERE i.product_id NOT IN(
        SELECT product_id FROM sales_transactions
        WHERE sale_date >= (SELECT MAX(sale_date)
                            FROM sales_transactions) - INTERVAL '90 days'
    )
    AND i.current_stock > 0
    ORDER BY days_sitting DESC
    LIMIT 10;