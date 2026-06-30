--1. Products Below Reorder Point Right Now
    SELECT
        p.product_name,
        p.category,
        w.city,
        i.current_stock,
        p.reorder_point,
        (i.current_stock - p.reorder_point) AS below_far
    FROM inventory i
    JOIN products p ON i.product_id = p.product_id
    JOIN warehouses w ON i.warehouse_id = w.warehouse_id
    WHERE (i.current_stock - p.reorder_point) < 0
    ORDER BY below_far ASC;


--2. Calculate Reorder Quantity for Each Critical Product
    /* For products below reorder point, calculate how much to order using this formula:
    Reorder Qty = (Avg Daily Sales × Lead Time from supplier) + Safety Stock
    Safety Stock = Avg Daily Sales × 5 (use 5 days as safety buffer for this project) */
    -- Query 2: Calculate Reorder Quantity for Each Critical Product
    WITH avg_daily_sales AS (
        SELECT 
            p.product_id,
            p.product_name,
            p.reorder_point,
            ROUND((SUM(st.quantity_sold) / 90.0), 2) AS avg_daily_sales
        FROM sales_transactions st
        JOIN products p ON st.product_id = p.product_id
        WHERE st.sale_date >= (SELECT MAX(sale_date) FROM sales_transactions) - INTERVAL '90 days'
        GROUP BY p.product_id, p.product_name, p.reorder_point
    ), 
    lead_days AS (
        -- DISTINCT added to prevent row explosion from multiple transactions with the same supplier
        SELECT DISTINCT 
            ads.product_id,
            ads.product_name,
            ads.reorder_point,
            ads.avg_daily_sales,
            s.lead_time_days
        FROM avg_daily_sales ads
        JOIN sales_transactions st ON ads.product_id = st.product_id
        JOIN suppliers s ON st.supplier_id = s.supplier_id
        WHERE s.reliability_score = (
            SELECT MAX(s2.reliability_score)
            FROM sales_transactions st2
            JOIN suppliers s2 ON st2.supplier_id = s2.supplier_id
            WHERE st2.product_id = ads.product_id
        )
    )
    SELECT
        ld.product_id,
        ld.product_name,
        i.warehouse_id,
        i.current_stock,
        ld.reorder_point,
        CEIL(ld.avg_daily_sales * 5) AS safety_stock_units,
        CEIL(ld.avg_daily_sales * (ld.lead_time_days + 5)) AS reorder_qnt
    FROM lead_days ld
    JOIN inventory i ON ld.product_id = i.product_id
    WHERE i.current_stock < ld.reorder_point;  

--3. Products That Will Stockout in Next 30 Days
    WITH avg_daily_sales AS (
        SELECT 
            product_id,
            ROUND((SUM(quantity_sold) / 90.0), 2) AS avg_daily_sales
        FROM sales_transactions
        WHERE sale_date >= (SELECT MAX(sale_date) FROM sales_transactions) - INTERVAL '90 days'
        GROUP BY product_id
    )
    SELECT 
        p.product_id,
        p.product_name,
        i.warehouse_id,
        i.current_stock,
        ads.avg_daily_sales,
        ROUND((i.current_stock / NULLIF(ads.avg_daily_sales, 0)), 1) AS days_until_stockout
    FROM inventory i
    JOIN products p ON i.product_id = p.product_id
    JOIN avg_daily_sales ads ON i.product_id = ads.product_id
    WHERE (i.current_stock / NULLIF(ads.avg_daily_sales, 0)) < 30
    ORDER BY days_until_stockout ASC;


--4. Supplier Lead Time Risk Analysis
    SELECT
        s.supplier_name,
        s.lead_time_days,
        s.reliability_score,
        COUNT(DISTINCT i.product_id)    AS product_currently_below_reorder_point
    FROM 
        suppliers s
    JOIN 
        sales_transactions st 
        ON s.supplier_id = st.supplier_id
    JOIN 
        products p 
        ON st.product_id = p.product_id
    JOIN 
        inventory i 
        ON p.product_id = i.product_id
    WHERE 
        i.current_stock < p.reorder_point
    GROUP BY 
        s.supplier_id,
        s.supplier_name,
        s.lead_time_days,
        s.reliability_score
    ORDER BY 
        product_currently_below_reorder_point DESC;


--5. Total Reorder Cost if Reordering All Critical Products Today
        -- Query 5: Total Reorder Cost if Reordering All Critical Products Today
    WITH avg_daily_sales AS (
        SELECT 
            p.product_id,
            p.product_name,
            p.reorder_point,
            p.unit_price,
            ROUND((SUM(st.quantity_sold) / 90.0), 2) AS avg_daily_sales
        FROM sales_transactions st
        JOIN products p ON st.product_id = p.product_id
        WHERE st.sale_date >= (SELECT MAX(sale_date) FROM sales_transactions) - INTERVAL '90 days'
        GROUP BY p.product_id, p.product_name, p.reorder_point, p.unit_price
    ), 
    lead_days AS (
        SELECT DISTINCT
            ads.product_id,
            ads.product_name,
            ads.reorder_point,
            ads.unit_price,
            ads.avg_daily_sales,
            s.lead_time_days 
        FROM avg_daily_sales ads
        JOIN sales_transactions st ON ads.product_id = st.product_id
        JOIN suppliers s ON st.supplier_id = s.supplier_id
        WHERE s.reliability_score = (
            SELECT MAX(s2.reliability_score)
            FROM sales_transactions st2
            JOIN suppliers s2 ON st2.supplier_id = s2.supplier_id
            WHERE st2.product_id = ads.product_id
        )
    ),
    reorder_calculations AS (
        SELECT
            ld.product_id,
            ((CEIL(ld.avg_daily_sales * (ld.lead_time_days + 5))) * ld.unit_price) AS reorder_cost_INR
        FROM lead_days ld
        JOIN inventory i ON ld.product_id = i.product_id
        WHERE i.current_stock < ld.reorder_point
    )
    SELECT 
        SUM(reorder_cost_INR) AS total_investment_needed
    FROM reorder_calculations;
