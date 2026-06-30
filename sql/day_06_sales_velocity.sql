--1. Average Daily Sales Velocity per Product
    SELECT
        p.product_name,
        p.category,
        (SUM(st.quantity_sold) / 90) :: NUMERIC(10,2)   AS avg_daily_sales
    FROM sales_transactions st
    JOIN products p ON st.product_id = p.product_id
    WHERE st.sale_date >= (
        SELECT MAX(sale_date) 
        FROM sales_transactions) - INTERVAL '90 days'
    GROUP BY p.product_name, p.category
    ORDER BY avg_daily_sales DESC;
    

--2. Seasonal Sales Pattern
    SELECT
        p.product_name,
        p.category,
        TO_CHAR(st.sale_date, 'YYYY-MM')   AS month,
        SUM(st.quantity_sold)   AS total_qnt_sold
    FROM sales_transactions st
    JOIN products p ON st.product_id = p.product_id
    GROUP BY p.product_name, p.category, TO_CHAR(st.sale_date, 'YYYY-MM')
    ORDER BY p.product_name, TO_CHAR(st.sale_date, 'YYYY-MM') , total_qnt_sold;


--3. Month over Month Sales Growth by Category
    WITH monthly_sales_by_category AS (
        SELECT
            p.category,
            TO_CHAR(st.sale_date, 'YYYY-MM')    AS month,
            SUM(st.total_amount)    AS total_sales
        FROM sales_transactions st
        JOIN products p ON st.product_id = p.product_id
        GROUP BY p.category, month
    ),
        prev_month_sales AS (
        SELECT
            category,
            month,
            total_sales,
            LAG(total_sales, 1) OVER (PARTITION BY category ORDER BY month) AS pm_sales
        FROM monthly_sales_by_category)
    
    SELECT
        category,
        month,
        total_sales,
        pm_sales,
        ROUND(((total_sales - pm_sales)/NULLIF(pm_sales,0))*100,2)     AS growth_pct
    FROM prev_month_sales
    ORDER BY category, month      

    -- Finding category with highest MoM growth%
        WITH monthly_sales_by_category AS (
            SELECT
                p.category,
                TO_CHAR(st.sale_date, 'YYYY-MM')    AS month,
                SUM(st.total_amount)    AS total_sales
            FROM sales_transactions st
            JOIN products p ON st.product_id = p.product_id
            GROUP BY p.category, month
        ),
            prev_month_sales AS (
            SELECT
                category,
                month,
                total_sales,
                LAG(total_sales, 1) OVER (PARTITION BY category ORDER BY month) AS pm_sales
            FROM monthly_sales_by_category)
        
        SELECT
            category,
            month,
            total_sales,
            pm_sales,
            ROUND(((total_sales - pm_sales)/NULLIF(pm_sales,0))*100,2)     AS growth_pct
        FROM prev_month_sales
        ORDER BY growth_pct DESC NULLS LAST

    -- Finding best overall Month in terms of Total Revenue
        SELECT
                TO_CHAR(sale_date, 'YYYY-MM')    AS month,
                SUM(total_amount)    AS total_sales
            FROM sales_transactions
            GROUP BY month
            ORDER BY total_sales DESC
            LIMIT 5;

--4. Top 10 Fastest Moving Products
    SELECT
        p.product_name,
        p.category,
        SUM(st.quantity_sold)   AS total_units_sold,
        SUM(st.total_amount)    AS total_revenue
    FROM sales_transactions st
    JOIN products p ON st.product_id = p.product_id
    GROUP BY p.product_name, p.category
    ORDER BY total_units_sold DESC
    LIMIT 10;


--5. Bottom 10 Slowest Moving Products (Excluding Dead Stock)
    SELECT
        p.product_name,
        p.category,
        SUM(st.quantity_sold)   AS total_units_sold,
        SUM(st.total_amount)    AS total_revenue
    FROM sales_transactions st
    JOIN products p ON st.product_id = p.product_id
    WHERE st.product_id IN (
        SELECT DISTINCT product_id FROM sales_transactions
        WHERE sale_date >= (SELECT MAX(sale_date) FROM sales_transactions) - INTERVAL '90 days'
    )
        GROUP BY p.product_name, p.category
    ORDER BY total_units_sold ASC
    LIMIT 10;


--6. Revenue by Customer Type and Category
    SELECT
        st.customer_type,
        p.category,
        SUM(st.total_amount)    AS total_revenue,
        COUNT(*)    AS transaction_count
    FROM sales_transactions st
    JOIN products p ON st.product_id = p.product_id
    GROUP BY st.customer_type, p.category
    ORDER BY total_revenue DESC;