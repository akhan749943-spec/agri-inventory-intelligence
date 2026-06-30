-- INVENTORY HEALTH
    -- Total Stock Value per Category
        SELECT
            p.category,
            COUNT(p.product_id)                     AS total_products,
            SUM(i.current_stock)                    AS total_units,
            SUM(i.current_stock * p.unit_price)     AS stock_value_rs
        FROM inventory i
        JOIN products p ON i.product_id = p.product_id
        GROUP BY p.category
        ORDER BY stock_value_rs DESC;

    -- Dead Stock Detection : Products with Zero sales in last 90 days
        SELECT
            p.product_id,
            p.product_name,
            p.category,
            w.city,
            w.region,
            i.current_stock,
            (i.current_stock * p.unit_price) :: NUMERIC(10,2)     AS stock_value_rs,
            CURRENT_DATE - i.last_restocked_date         AS days_since_restocked
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
        ORDER BY stock_value_rs DESC;

        --  Total Rupee value of dead stock
        SELECT
            SUM((i.current_stock * p.unit_price) :: NUMERIC(10,2))    AS stock_value_rs
        FROM inventory i
        JOIN products p ON i.product_id = p.product_id
        WHERE i.product_id NOT IN (
                SELECT
                    DISTINCT product_id
                FROM sales_transactions
                WHERE sale_date >= (SELECT MAX(sale_date) FROM sales_transactions)
                    - INTERVAL '90 days'
                )
                AND i.current_stock > 0;


    -- Overstocked Warehouses
        SELECT
            w.warehouse_name,
            w.city,
            w.region,
            w.capacity_units,
            SUM(i.current_stock)    AS current_total_stock,
            SUM(i.current_stock) - w.capacity_units     AS overflow_units,
            (SUM(i.current_stock) :: NUMERIC / w.capacity_units * 100) :: NUMERIC(10,2)      AS capacity_used_pct
        FROM inventory i 
        JOIN warehouses w ON i.warehouse_id = w.warehouse_id
        GROUP BY w.warehouse_id, w.city, w.region, w.capacity_units
        ORDER BY capacity_used_pct DESC;


    -- Stock Coverage Ratio : How many days of stock does each product have left:
        WITH reference_date AS (
            SELECT MAX(sale_date) AS ref_date
            FROM sales_transactions
        ),
        avg_daily_sales AS (
            SELECT
                st.product_id,
                st.warehouse_id,
                (SUM(quantity_sold) :: NUMERIC / 90) :: NUMERIC(10,2) AS avg_daily_sales
            FROM sales_transactions st, reference_date rd
            WHERE st.sale_date >= rd.ref_date - INTERVAL '90 days'
            GROUP BY st.product_id, st.warehouse_id
        )
        
        SELECT
            p.product_name,
            p.category,
            w.city,
            i.current_stock,
            COALESCE(ads.avg_daily_sales, 0) AS avg_daily_sales,
            CASE
                WHEN COALESCE(ads.avg_daily_sales, 0) = 0
                    THEN 999
                    ELSE ROUND(i.current_stock / ads.avg_daily_sales)
                END AS coverage_days
        FROM inventory i
        JOIN products p ON i.product_id = p.product_id
        JOIN warehouses w ON i.warehouse_id = w.warehouse_id
        LEFT JOIN avg_daily_sales ads 
            ON ads.product_id   = i.product_id
            AND ads.warehouse_id = i.warehouse_id
        ORDER BY coverage_days DESC;

        -- Coverage ratio by category

        WITH reference_date AS (
            SELECT MAX(sale_date) AS ref_date FROM sales_transactions
        ),
        avg_daily_sales AS (
            SELECT
                st.product_id,
                st.warehouse_id,
                ROUND(SUM(st.quantity_sold)::NUMERIC / 90, 2) AS avg_daily_sales
            FROM sales_transactions st, reference_date rd
            WHERE st.sale_date >= rd.ref_date - INTERVAL '90 days'
            GROUP BY st.product_id, st.warehouse_id
        ),
        coverage AS (
            SELECT
                p.category,
                i.current_stock,
                ads.avg_daily_sales,
                CASE
                    WHEN COALESCE(ads.avg_daily_sales, 0) = 0 THEN 999
                    ELSE ROUND(i.current_stock / ads.avg_daily_sales)
                END AS coverage_days
            FROM inventory i
            JOIN products p ON i.product_id = p.product_id
            LEFT JOIN avg_daily_sales ads
                ON ads.product_id   = i.product_id
                AND ads.warehouse_id = i.warehouse_id
        )
        SELECT
            category,
            ROUND(AVG(coverage_days), 0) AS avg_coverage_days,
            MIN(coverage_days)            AS min_coverage,
            MAX(coverage_days)            AS max_coverage
        FROM coverage
        GROUP BY category
        ORDER BY avg_coverage_days DESC;


    -- Dangerously Overstocked Products : Products with more than 180 days of coverage:
        -- Store reference date as a variable
            WITH reference_date AS (
                SELECT MAX(sale_date) AS ref_date
                FROM sales_transactions
            ),
            avg_daily_sales AS (
                SELECT
                    st.product_id,
                    st.warehouse_id,
                    ROUND(SUM(st.quantity_sold)::NUMERIC / 90, 2) AS avg_daily_sales
                FROM sales_transactions st, reference_date rd
                WHERE st.sale_date >= rd.ref_date - INTERVAL '90 days'
                GROUP BY st.product_id, st.warehouse_id
            )
            SELECT
                p.product_name,
                p.category,
                w.city,
                i.current_stock,
                COALESCE(ads.avg_daily_sales, 0) AS avg_daily_sales,
                CASE
                    WHEN COALESCE(ads.avg_daily_sales, 0) = 0
                    THEN 999
                    ELSE ROUND(i.current_stock / ads.avg_daily_sales)
                END AS coverage_days,
                CASE
                    WHEN COALESCE(ads.avg_daily_sales, 0) = 0 THEN '☠️ Dead Stock'
                    WHEN ROUND(i.current_stock / ads.avg_daily_sales) > 180 THEN '🔴 Dangerously Overstocked'
                    WHEN ROUND(i.current_stock / ads.avg_daily_sales) > 90  THEN '🟡 Excess Stock'
                    WHEN ROUND(i.current_stock / ads.avg_daily_sales) < 15  THEN '🔴 Critical - Reorder Now'
                    WHEN ROUND(i.current_stock / ads.avg_daily_sales) < 30  THEN '🟡 Low Stock'
                    ELSE '🟢 Healthy'
                END AS stock_status
            FROM inventory i
            JOIN products p   ON i.product_id   = p.product_id
            JOIN warehouses w ON i.warehouse_id = w.warehouse_id
            LEFT JOIN avg_daily_sales ads
                ON ads.product_id   = i.product_id
                AND ads.warehouse_id = i.warehouse_id
            ORDER BY coverage_days DESC;


        -- Worst Coverage by Category
        WITH reference_date AS (
            SELECT MAX(sale_date) AS ref_date FROM sales_transactions
        ),
        avg_daily_sales AS (
            SELECT
                st.product_id,
                st.warehouse_id,
                ROUND(SUM(st.quantity_sold)::NUMERIC / 90, 2) AS avg_daily_sales
            FROM sales_transactions st, reference_date rd
            WHERE st.sale_date >= rd.ref_date - INTERVAL '90 days'
            GROUP BY st.product_id, st.warehouse_id
        ),
        coverage AS (
            SELECT
                p.category,
                i.current_stock,
                ads.avg_daily_sales,
                CASE
                    WHEN COALESCE(ads.avg_daily_sales, 0) = 0 THEN 999
                    ELSE ROUND(i.current_stock / ads.avg_daily_sales)
                END AS coverage_days
            FROM inventory i
            JOIN products p ON i.product_id = p.product_id
            LEFT JOIN avg_daily_sales ads
                ON ads.product_id   = i.product_id
                AND ads.warehouse_id = i.warehouse_id
        )
        SELECT
            category,
            ROUND(AVG(coverage_days), 0) AS avg_coverage_days,
            MIN(coverage_days)            AS min_coverage,
            MAX(coverage_days)            AS max_coverage
        FROM coverage
        GROUP BY category
        ORDER BY avg_coverage_days DESC;