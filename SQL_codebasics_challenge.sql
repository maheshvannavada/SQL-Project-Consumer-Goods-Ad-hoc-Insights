use gdb023;
select * from dim_customer;
select * from dim_product;
select * from fact_gross_price;
select * from fact_manufacturing_cost;
select * from fact_pre_invoice_deductions;
select * from fact_sales_monthly;


### Q1) Provide the list of markets in which customer  "Atliq  Exclusive"  operates its business in the  APAC  region. 

select 
	distinct market, region from dim_customer
	where region = 'APAC' and customer = 'Atliq Exclusive';

 ### Q2) What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields, unique_products_2020, unique_products_2021, percent age_chg
 
WITH unique_products AS (
    SELECT fiscal_year, COUNT(DISTINCT product_code) AS unique_products 
    FROM fact_gross_price
    GROUP BY fiscal_year
)
SELECT 
    up_2020.unique_products AS unique_products_2020, 
    up_2021.unique_products AS unique_products_2021, 
    ROUND((up_2021.unique_products - up_2020.unique_products) / up_2020.unique_products * 100, 2) AS percentage_chg 
FROM 
    unique_products AS up_2020
    CROSS JOIN unique_products AS up_2021
WHERE 
    up_2020.fiscal_year = 2020
    AND up_2021.fiscal_year = 2021;

## Q3) Provide a report with all the unique product counts for each  segment  and sort them in descending order of product counts. The final output contains 2 fields,  segment product_count 
select segment, count(product_code) as product_count
	from dim_product
    group by segment
    order by product_count desc;

## Q4) Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? The final output contains these fields, segment, product_count_2020, product_count_2021, difference
WITH seg_product AS (
    SELECT p.segment, f.fiscal_year, COUNT(DISTINCT f.product_code) AS product_count 
    FROM dim_product as p 
    JOIN fact_gross_price as f on p.product_code = f.product_code
    group by p.segment, f.fiscal_year
)
SELECT sp_2020.segment,
	sp_2020.product_count as product_count_2020, 
    sp_2021.product_count as product_count_2021, 
    sp_2021.product_count - sp_2020.product_count as difference 
from seg_product as sp_2020 
	inner join
    seg_product as sp_2021
    on sp_2020.segment = sp_2021.segment 
    and sp_2020.fiscal_year = 2020
    and sp_2021.fiscal_year = 2021
order by difference desc;
    
## Q5) Get the products that have the highest and lowest manufacturing costs. The final output should contain these fields, product_code, product, manufacturing_cost

SELECT 
    m.product_code, 
    CONCAT(p.product, " (", p.variant, ")") AS product,
    m.manufacturing_cost
FROM 
    fact_manufacturing_cost AS m
JOIN 
    dim_product AS p 
    ON m.product_code = p.product_code
WHERE 
    m.manufacturing_cost = (SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost)
    OR m.manufacturing_cost = (SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost)
ORDER BY 
    m.manufacturing_cost DESC;

## Q6) Generate a report which contains the top 5 customers who received an  average high  pre_invoice_discount_pct  for the  fiscal  year 2021  and in the Indian  market.
select * from fact_pre_invoice_deductions;
select * from dim_customer;

select p.customer_code, c.customer, round(avg(p.pre_invoice_discount_pct), 4)  as average_discount_price
from fact_pre_invoice_deductions as p 
join dim_customer as c on p.customer_code = c.customer_code
where p.fiscal_year = 2021 and 
	c.market = 'India'
group by p.customer_code,c.customer
order by average_discount_price  desc
limit 5;

## Q7) Get the complete report of the Gross sales amount for the customer  “Atliq  Exclusive”  for each month  . This analysis helps to  get an idea of low and high-performing months and take strategic decisions. Month Year Gross sales Amount 
select * from fact_sales_monthly;
select * from dim_customer;
select * from fact_gross_price;

with customer_sales as (
select customer, monthname(date) as month, month(date) as month_number, year(date) as year, (sold_quantity * gross_price) as gross_sales
from fact_sales_monthly s join 
	fact_gross_price g on s.product_code = g.product_code
    join dim_customer c on s.customer_code = c.customer_code
where c.customer = 'Atliq Exclusive'
)
select month, year, concat(round(sum(gross_sales)/1000000, 2), 'M') as gross_sales_amount from customer_sales
group by month, year
order by year, month_number;

## Q8) In which quarter of 2020, got the maximum total_sold_quantity? The final output contains these fields sorted by the total_sold_quantity,Quarter , total_sold_quantity 
select * from fact_sales_monthly;
select * from fact_gross_price;


WITH quater_table AS (
  SELECT 
    date,
    QUARTER(date) AS quarter, 
    fiscal_year,
    sold_quantity 
  FROM 
    fact_sales_monthly
)
SELECT 
  CASE 
    WHEN quarter = 1 THEN 'Q1'
    WHEN quarter = 2 THEN 'Q2'
    WHEN quarter = 3 THEN 'Q3'
    WHEN quarter = 4 THEN 'Q4' 
  END AS quarter,
  ROUND(SUM(sold_quantity) / 1000000, 2) AS total_sold_quantity_in_millions 
FROM 
  quater_table
WHERE 
  fiscal_year = 2020
GROUP BY 
  quarter
ORDER BY 
  total_sold_quantity_in_millions DESC;


### Q9) Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution?  The final output  contains these fields, channel, gross_sales_mln ,percentage

select * from dim_customer;
select * from fact_sales_monthly;
select * from fact_gross_price;

WITH channel_table AS (
  SELECT 
    c.channel, 
    SUM(s.sold_quantity * g.gross_price) AS total_sales
  FROM 
    dim_customer c 
  JOIN 
    fact_sales_monthly s ON c.customer_code = s.customer_code
  JOIN 
    fact_gross_price g ON s.product_code = g.product_code
  WHERE 
    s.fiscal_year = '2021'
  GROUP BY 
    c.channel
)
SELECT 
  channel, 
  CONCAT(ROUND(total_sales / 1000000, 2), ' M') AS gross_sales,
  ROUND(total_sales / SUM(total_sales) OVER() * 100, 2) AS percentage
FROM 
  channel_table
ORDER BY 
  percentage DESC;

### Q 10) Get the Top 3 products in each division that have a high  total_sold_quantity in the fiscal_year 2021? The final output contains these fields,division , product_code, product  total_sold_quantity  rank_order
select * from dim_product;
select * from fact_sales_monthly;

with product_table as ( 
select p.division, p.product_code, p.product, sum(s.sold_quantity) as total_sold_quantity, 
rank () over( partition by  p.division order by sum(s.sold_quantity) ) as rank_order
from dim_product p
join fact_sales_monthly s on p.product_code = s.product_code
where s.fiscal_year = '2021'
group by p.division, p.product
)
select * from product_table
where rank_order in (1,2,3);
	
    