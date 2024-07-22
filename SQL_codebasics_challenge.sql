#Codebasics SQL Project

use gdb023;
select * from dim_customer;
select * from dim_product;
select * from fact_gross_price;
select * from fact_manufacturing_cost;
select * from fact_pre_invoice_deductions;
select * from fact_sales_monthly;


### Q1) Provide the list of markets in which customer  "Atliq  Exclusive"  operates its business in the  APAC  region. 

SELECT DISTINCT market,
                region
FROM   dim_customer
WHERE  region = 'APAC'
       AND customer = 'Atliq Exclusive'; 
       
------------------------------------------------------------------------------------------------------------------------------------------------

 ### Q2) What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields, unique_products_2020, unique_products_2021, percent age_chg
 
WITH unique_products
     AS (SELECT fiscal_year,
                Count(DISTINCT product_code) AS unique_products
         FROM   fact_gross_price
         GROUP  BY fiscal_year)
SELECT up_2020.unique_products AS unique_products_2020,
       up_2021.unique_products AS unique_products_2021,
       Round(( up_2021.unique_products - up_2020.unique_products ) /
             up_2020.unique_products
             * 100, 2)         AS percentage_chg
FROM   unique_products AS up_2020
       CROSS JOIN unique_products AS up_2021
WHERE  up_2020.fiscal_year = 2020
       AND up_2021.fiscal_year = 2021; 

------------------------------------------------------------------------------------------------------------------------------------------------

## Q3) Provide a report with all the unique product counts for each  segment  and sort them in descending order of product counts. The final output contains 2 fields,  segment product_count 

SELECT segment,
       Count(product_code) AS product_count
FROM   dim_product
GROUP  BY segment
ORDER  BY product_count DESC; 

------------------------------------------------------------------------------------------------------------------------------------------------

## Q4) Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? The final output contains these fields, segment, product_count_2020, product_count_2021, difference
WITH seg_product
     AS (SELECT p.segment,
                f.fiscal_year,
                Count(DISTINCT f.product_code) AS product_count
         FROM   dim_product AS p
                JOIN fact_gross_price AS f
                  ON p.product_code = f.product_code
         GROUP  BY p.segment,
                   f.fiscal_year)
SELECT sp_2020.segment,
       sp_2020.product_count   AS product_count_2020,
       sp_2021.product_count   AS product_count_2021,
       sp_2021.product_count - sp_2020.product_count AS difference
FROM   seg_product AS sp_2020
       INNER JOIN seg_product AS sp_2021
               ON sp_2020.segment = sp_2021.segment
                  AND sp_2020.fiscal_year = 2020
                  AND sp_2021.fiscal_year = 2021
ORDER  BY difference DESC; 

------------------------------------------------------------------------------------------------------------------------------------------------

###Q5) Get the products that have the highest and lowest manufacturing costs. The final output should contain these fields, product_code, product, manufacturing_cost

SELECT m.product_code,
       Concat(p.product, "(", p.variant, ")") AS product,
       m.manufacturing_cost
FROM   fact_manufacturing_cost AS m
       JOIN dim_product AS p
         ON m.product_code = p.product_code
WHERE  m.manufacturing_cost = (SELECT Min(manufacturing_cost)
                               FROM   fact_manufacturing_cost)
        OR m.manufacturing_cost = (SELECT Max(manufacturing_cost)
                                   FROM   fact_manufacturing_cost)
ORDER  BY m.manufacturing_cost DESC; 

------------------------------------------------------------------------------------------------------------------------------------------------

###Q6) Generate a report which contains the top 5 customers who received an  average high  pre_invoice_discount_pct  for the  fiscal  year 2021  and in the Indian  market.

SELECT p.customer_code,
       c.customer,
       Round(Avg(p.pre_invoice_discount_pct), 4) AS average_discount_price
FROM   fact_pre_invoice_deductions AS p
       JOIN dim_customer AS c
         ON p.customer_code = c.customer_code
WHERE  p.fiscal_year = 2021
       AND c.market = 'India'
GROUP  BY p.customer_code,
          c.customer
ORDER  BY average_discount_price DESC
LIMIT  5; 

------------------------------------------------------------------------------------------------------------------------------------------------

###Q7) Get the complete report of the Gross sales amount for the customer  “Atliq  Exclusive”  for each month  . This analysis helps to  get an idea of low and high-performing months and take strategic decisions. Month Year Gross sales Amount 


WITH customer_sales
     AS (SELECT customer,
                Monthname(date)                 AS month,
                Month(date)                     AS month_number,
                Year(date)                      AS year,
                ( sold_quantity * gross_price ) AS gross_sales
         FROM   fact_sales_monthly s
                JOIN fact_gross_price g
                  ON s.product_code = g.product_code
                JOIN dim_customer c
                  ON s.customer_code = c.customer_code
         WHERE  c.customer = 'Atliq Exclusive')
SELECT month,
       year,
       Concat(Round(Sum(gross_sales) / 1000000, 2), 'M') AS gross_sales_amount
FROM   customer_sales
GROUP  BY month,
          year
ORDER  BY year,
          month_number; 
          
------------------------------------------------------------------------------------------------------------------------------------------------

###Q8) In which quarter of 2020, got the maximum total_sold_quantity? The final output contains these fields sorted by the total_sold_quantity,Quarter , total_sold_quantity 


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

------------------------------------------------------------------------------------------------------------------------------------------------


###Q9) Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution?  The final output  contains these fields, channel, gross_sales_mln ,percentage

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
  
------------------------------------------------------------------------------------------------------------------------------------------------

###Q10) Get the Top 3 products in each division that have a high  total_sold_quantity in the fiscal_year 2021? The final output contains these fields,division , product_code, product  total_sold_quantity  rank_order

WITH product_table
     AS (SELECT p.division,
                p.product_code,
                p.product,
                Sum(s.sold_quantity)                AS total_sold_quantity,
                Rank ()
                  OVER(
                    partition BY p.division
                    ORDER BY Sum(s.sold_quantity) ) AS rank_order
         FROM   dim_product p
                JOIN fact_sales_monthly s
                  ON p.product_code = s.product_code
         WHERE  s.fiscal_year = '2021'
         GROUP  BY p.division,
                   p.product)
SELECT *
FROM   product_table
WHERE  rank_order IN ( 1, 2, 3 ); 
	
    