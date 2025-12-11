--=====================================
-- The last layer (dimensions & fact)
--=====================================


-- online retail (fact table)

if OBJECT_ID('fact_online_retail','v') is not null
	drop view fact_online_retail;
go
	create or alter view fact_online_retail as (
		select
			invoice as order_id,
			customer_id,
			stock_code as product_id,
			invoice_date,
			quantity,
			price,
			price * quantity as sales
		from cleaned_online_retail
		)



-- Customer Dimension

create or alter view dim_customers as

with base as (
	select
		customer_id,
		country,
		invoice,
		invoice_date,
		quantity,
		price,
		(
		select
			max(invoice_date)
		from cleaned_online_retail
		) as max_date
	from cleaned_online_retail
	)

, aggregation AS (
    SELECT
        customer_id,
        country,
        MAX(invoice_date) AS last_order,
        COUNT(DISTINCT invoice) AS frequency,
        SUM(quantity * price) AS monetary,
        MAX(max_date) AS max_date   
    FROM base
    GROUP BY customer_id, country
)

, rfm as (
	select
		customer_id,
		country,
		DATEDIFF(day,last_order,max_date) as recency,
		frequency,
		monetary
	from aggregation
	)

, scoring AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency DESC) AS R_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS F_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS M_score,

		CASE
            WHEN NTILE(5) OVER (ORDER BY recency desc) = 5 THEN 'Very Recent'
            WHEN NTILE(5) OVER (ORDER BY recency desc) = 4 THEN 'Recent'
            WHEN NTILE(5) OVER (ORDER BY recency desc) = 3 THEN 'Moderate'
            WHEN NTILE(5) OVER (ORDER BY recency desc) = 2 THEN 'Old'
            ELSE 'Very Old'
        END AS recency_segment,
        CASE
            WHEN NTILE(5) OVER (ORDER BY frequency ASC) = 5 THEN 'Very Frequent'
            WHEN NTILE(5) OVER (ORDER BY frequency ASC) = 4 THEN 'Frequent'
            WHEN NTILE(5) OVER (ORDER BY frequency ASC) = 3 THEN 'Moderate'
            WHEN NTILE(5) OVER (ORDER BY frequency ASC) = 2 THEN 'Infrequent'
            ELSE 'Rare'
        END AS frequency_segment,
        CASE
            WHEN NTILE(5) OVER (ORDER BY monetary ASC) = 5 THEN 'Very High'
            WHEN NTILE(5) OVER (ORDER BY monetary ASC) = 4 THEN 'High'
            WHEN NTILE(5) OVER (ORDER BY monetary ASC) = 3 THEN 'Medium'
            WHEN NTILE(5) OVER (ORDER BY monetary ASC) = 2 THEN 'Low'
            ELSE 'Very Low'
        END AS monetary_segment
    FROM rfm
)

SELECT
    customer_id,
    country,
    recency,
    frequency,
    monetary,
    R_score,
    F_score,
    M_score,
    CASE
        WHEN R_score = 5 AND F_score >= 4 AND M_score >= 4 THEN 'Champion'
        WHEN R_score >= 4 AND F_score >= 3 THEN 'Loyal'
        WHEN R_score >= 3 AND F_score >= 2 THEN 'Potential'
        WHEN R_score <= 2 AND F_score <= 2 THEN 'At Risk'
        ELSE 'Others'
    END AS customer_segment,
	recency_segment,
	frequency_segment,
	monetary_segment
FROM scoring;	


--check customer view

select * from dim_customers
order by customer_segment;


-- Product Dimension

CREATE or alter VIEW dim_products AS

WITH product_agg AS (
    SELECT
        stock_code AS product_id,
        description,
        SUM(quantity * price) AS total_sales,
        SUM(quantity) AS total_quantity,
        AVG(price) AS average_price
    FROM cleaned_online_retail
    GROUP BY stock_code, description
),

product_scoring AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY total_sales asc) AS sales_score
    FROM product_agg
)

SELECT
    product_id,
    description,
    total_sales,
    total_quantity,
    average_price,
    CASE
        WHEN sales_score = 5 THEN 'Best Seller'
        WHEN sales_score = 4 THEN 'High Seller'
        WHEN sales_score = 3 THEN 'Medium Seller'
        WHEN sales_score = 2 THEN 'Low Seller'
        ELSE 'Rarely Sold'
    END AS product_segment
FROM product_scoring;


-- check product view

select * from dim_products;
