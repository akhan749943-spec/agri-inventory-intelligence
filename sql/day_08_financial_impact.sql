--1. Total Dead Stock Cost per Region
    SELECT
        w.region,
        COUNT(*)                                        AS dead_record,
        SUM(i.current_stock)                            AS dead_stock_units,
       ROUND(SUM(i.current_stock * p.unit_price)::NUMERIC, 2)  AS dead_stock_value_rs
    FROM inventory i
    JOIN products p ON i.product_id = p.product_id
    JOIN warehouses w ON i.warehouse_id = w.warehouse_id
    WHERE i.product_id NOT IN (
            SELECT
                DISTINCT product_id
            FROM sales_transactions
            WHERE sale_date >= (SELECT MAX(sale_date) FROM sales_transactions)
                    - INTERVAL '90 days'
                )
                AND i.current_stock > 0
    GROUP BY w.region
    ORDER BY dead_stock_units DESC;


--2. Revenue Lost Due to Stockouts Last Quarter : 
-- Use this logic: Lost Revenue = Days product was critical/zero × Avg Daily Sales × Unit Price

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
    backward_calculation AS (
        SELECT
            ads.product_id,
            -- 1. Calculate exact days spent in the danger zone last quarter
            ROUND(((ads.reorder_point - i.current_stock) / NULLIF(ads.avg_daily_sales, 0)), 1) AS days_critical,
            -- 2. Multiply those days by daily sales and price to get exact lost revenue
            ROUND((((ads.reorder_point - i.current_stock) / NULLIF(ads.avg_daily_sales, 0)) * ads.avg_daily_sales * ads.unit_price), 2) AS revenue_lost
        FROM avg_daily_sales ads
        JOIN inventory i ON ads.product_id = i.product_id
        WHERE i.current_stock < ads.reorder_point
    )
    SELECT 
        SUM(revenue_lost) AS total_historical_revenue_lost
    FROM backward_calculation;



--3. Carrying Cost of Excess Inventory
    WITH reference_date AS (
        SELECT MAX(sale_date) AS ref_date 
        FROM sales_transactions
    ),
    avg_daily_sales AS (
        SELECT
            st.product_id,
            st.warehouse_id,
            ROUND((SUM(st.quantity_sold)::NUMERIC / 90.0), 2) AS avg_daily_sales
        FROM sales_transactions st, reference_date rd
        WHERE st.sale_date >= rd.ref_date - INTERVAL '90 days'
        GROUP BY st.product_id, st.warehouse_id
    ),
    excess_inventory_costs AS (
        SELECT
            i.product_id,
            i.warehouse_id,
            -- The Financial Formula: (Total Value of Excess Stock) * 25%
            ((i.current_stock * p.unit_price) * 0.25) AS carrying_cost_rs
        FROM inventory i
        JOIN products p ON i.product_id = p.product_id
        JOIN avg_daily_sales ads 
            ON i.product_id = ads.product_id 
            AND i.warehouse_id = ads.warehouse_id
        -- The Filter: Must have active sales, but coverage is dangerously high
        WHERE ads.avg_daily_sales > 0 
        AND (i.current_stock / ads.avg_daily_sales) > 90
    )
    -- The Grand Total
    SELECT
        ROUND(SUM(carrying_cost_rs), 2) AS total_annual_carrying_cost
    FROM excess_inventory_costs;


--4. Recovery Amount if Dead Stock Cleared at 40% Discount
-- Use Formulas - Recovery Amount = Dead Stock Value × 0.60 & Loss Amount = Dead Stock Value × 0.40
    WITH dead_stock_value AS (
        SELECT
            ROUND(SUM(i.current_stock * p.unit_price)::NUMERIC, 2)  AS total_dead_stock_value_rs
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
    )
    SELECT
        total_dead_stock_value_rs,
        ROUND((total_dead_stock_value_rs * 0.60),2)     AS recovery_amount,
        ROUND((total_dead_stock_value_rs * 0.40),2)     AS loss_amount
    FROM dead_stock_value;



-- Net Financial Impact Summary
    WITH reference_date AS (
        SELECT MAX(sale_date) AS ref_date 
        FROM sales_transactions
    ),
    -- 1. DEAD STOCK ENGINE
    dead_stock AS (
        SELECT SUM(i.current_stock * p.unit_price) AS total_dead_stock_value
        FROM inventory i
        JOIN products p ON i.product_id = p.product_id
        WHERE i.product_id NOT IN (
            SELECT DISTINCT st.product_id
            FROM sales_transactions st
            CROSS JOIN reference_date rd
            WHERE st.sale_date >= rd.ref_date - INTERVAL '90 days'
        )
        AND i.current_stock > 0
    ),
    -- 2. REORDER COST ENGINE
    reorder_sales AS (
        SELECT 
            p.product_id,
            p.reorder_point,
            p.unit_price,
            ROUND((SUM(st.quantity_sold) / 90.0), 2) AS avg_daily_sales
        FROM sales_transactions st
        JOIN products p ON st.product_id = p.product_id
        CROSS JOIN reference_date rd
        WHERE st.sale_date >= rd.ref_date - INTERVAL '90 days'
        GROUP BY p.product_id, p.reorder_point, p.unit_price
    ),
    lead_days AS (
        SELECT DISTINCT 
            rs.product_id,
            rs.reorder_point,
            rs.unit_price,
            rs.avg_daily_sales,
            s.lead_time_days 
        FROM reorder_sales rs
        JOIN sales_transactions st ON rs.product_id = st.product_id
        JOIN suppliers s ON st.supplier_id = s.supplier_id
        WHERE s.reliability_score = (
            SELECT MAX(s2.reliability_score)
            FROM sales_transactions st2
            JOIN suppliers s2 ON st2.supplier_id = s2.supplier_id
            WHERE st2.product_id = rs.product_id
        )
    ),
    reorder_cost AS (
        SELECT SUM(CEIL(ld.avg_daily_sales * (ld.lead_time_days + 5)) * ld.unit_price) AS total_reorder_investment
        FROM lead_days ld
        JOIN inventory i ON ld.product_id = i.product_id
        WHERE i.current_stock < ld.reorder_point
    ),
    -- 3. CARRYING COST ENGINE
    carrying_sales AS (
        SELECT
            st.product_id,
            st.warehouse_id,
            ROUND((SUM(st.quantity_sold)::NUMERIC / 90.0), 2) AS avg_daily_sales
        FROM sales_transactions st
        CROSS JOIN reference_date rd
        WHERE st.sale_date >= rd.ref_date - INTERVAL '90 days'
        GROUP BY st.product_id, st.warehouse_id
    ),
    carrying_cost AS (
        SELECT SUM((i.current_stock * p.unit_price) * 0.25) AS total_carrying_cost
        FROM inventory i
        JOIN products p ON i.product_id = p.product_id
        JOIN carrying_sales cs 
            ON i.product_id = cs.product_id 
            AND i.warehouse_id = cs.warehouse_id
        WHERE cs.avg_daily_sales > 0 
        AND (i.current_stock / cs.avg_daily_sales) > 90
    )

    -- FINAL EXECUTIVE SUMMARY: Combining all engines and calculating the net position
    SELECT 
        ROUND(ds.total_dead_stock_value, 2) AS dead_stock_value_rs,
        ROUND(cc.total_carrying_cost, 2) AS annual_carrying_cost_rs,
        ROUND(rc.total_reorder_investment, 2) AS reorder_investment_needed_rs,
        ROUND((ds.total_dead_stock_value * 0.40), 2) AS recovery_value_rs,
        ROUND(((ds.total_dead_stock_value * 0.40) - rc.total_reorder_investment), 2) AS net_position_rs
    FROM dead_stock ds, reorder_cost rc, carrying_cost cc;