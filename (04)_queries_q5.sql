/* 
--------------------------------------
(5.1) CUSTOMER ORDER HISTORY
--------------------------------------
*/

-- (5.1.1) list of all products and quantities in an order 
CREATE VIEW order_products AS
SELECT 
    oi.order_number, 
    GROUP_CONCAT(p.name || ' x' || oi.quantity, '; ') AS product_list
FROM order_inventory AS oi
JOIN product AS p ON p.product_id = oi.product_id
GROUP BY oi.order_number;

-- (5.1) select all relevant attributes to display completed and processing orders  
SELECT 
    c.email, 
    c.first_name || ' ' || c.last_name AS customer_name, 
    co.order_number, 
    co.order_date, 
    op.product_list, 
    otc.total_after_discount AS grand_total, 
    ps.payment_status
FROM customer AS c
JOIN customer_order AS co ON c.email = co.customer_email
JOIN order_products AS op ON co.order_number = op.order_number 
JOIN order_total_cost AS otc ON otc.order_number = co.order_number
JOIN payment_transaction AS pm ON pm.order_number = co.order_number
JOIN payment_status AS ps ON pm.status_id = ps.status_id
WHERE ps.payment_status = 'completed' 
   OR ps.payment_status = 'processing';



/* 
--------------------------------------
(5.2) BASKET ANALYSIS
--------------------------------------
*/

-- (5.2.1) list of all products and quantities in a basket 
CREATE VIEW basket_products AS
SELECT 
    ib.basket_id, 
    GROUP_CONCAT(p.name || ' x' || ib.quantity, '; ') AS product_list
FROM in_basket AS ib
JOIN product AS p ON p.product_id = ib.product_id
GROUP BY ib.basket_id;

-- (5.2.2) giftcard remaining totals per customer 
CREATE VIEW gift_card_balance_per_customer AS
SELECT 
    c.email, 
    SUM(gc.current_balance) AS giftcard_balance
FROM customer AS c 
JOIN payment_method AS pm ON pm.customer_email = c.email
JOIN gift_card AS gc ON gc.payment_method_id = pm.payment_method_id
GROUP BY c.email;

-- (5.2.2) select all relevant attributes to display basket analysis 
SELECT 
    c.email, 
    c.first_name || " " || c.last_name AS customer_name, 
    c.dob AS birthday, 
    COALESCE(gcb.giftcard_balance, 0) AS giftcard_balance,
    bp.product_list AS products_in_basket
FROM customer AS c 
LEFT JOIN gift_card_balance_per_customer AS gcb ON c.email = gcb.email
JOIN basket AS b ON c.email = b.email
JOIN basket_products AS bp ON bp.basket_id = b.basket_id;



/* 
--------------------------------------
(5.3) TOP PRODUCTS BY REVENUE
--------------------------------------
*/

-- (5.3.1) average rating for each product 
CREATE VIEW average_product_rating AS
SELECT 
    product_id, 
    AVG(product_rating) AS average_rating
FROM review 
GROUP BY product_id;

-- (5.3.2) total number of units ordered per product
CREATE VIEW product_total_ordered AS
SELECT 
    product_id, 
    SUM(quantity) AS number_ordered
FROM order_inventory 
GROUP BY product_id;

-- (5.3.3) total number of units successfully returned per product
CREATE VIEW product_total_returned AS
SELECT 
    product_id, 
    SUM(quantity) AS number_returned
FROM return_inventory AS ri
JOIN product_return AS pr ON ri.return_number = pr.return_number
JOIN return_status AS rs ON pr.status_id = rs.status_id
WHERE rs.return_status = 'completed'
GROUP BY product_id;

-- (5.3.4) calculate return rate per product
CREATE VIEW product_return_rate AS
SELECT 
    pto.product_id, 
    (CAST(COALESCE(ptr.number_returned, 0) AS FLOAT) / pto.number_ordered) AS return_rate
FROM product_total_ordered AS pto
LEFT JOIN product_total_returned AS ptr ON pto.product_id = ptr.product_id;

-- (5.3.5) calculate total revenue per product
CREATE VIEW total_revenue_per_product AS 
SELECT 
    p.product_id, 
    (pto.number_ordered - COALESCE(ptr.number_returned, 0)) * p.unit_price AS total_revenue
FROM product_total_ordered AS pto
LEFT JOIN product_total_returned AS ptr 
    ON pto.product_id = ptr.product_id 
JOIN product AS p 
    ON pto.product_id = p.product_id;

-- (5.3) select all relevant attributes and display the top performing products per category
WITH ranked AS (
  SELECT
    c.category_id,
    c.category_name,
    p.product_id,
    p.name,
    trp.total_revenue,
    RANK() OVER (
      PARTITION BY c.category_id
      ORDER BY trp.total_revenue DESC
    ) AS category_rank
  FROM total_revenue_per_product AS trp
  JOIN product  AS p ON p.product_id  = trp.product_id
  JOIN category AS c ON c.category_id = p.category_id
)
SELECT
  r.category_name,
  r.product_id,
  r.name,
  r.category_rank,
  r.total_revenue,
  apr.average_rating,
  prr.return_rate
FROM ranked AS r
LEFT JOIN average_product_rating AS apr ON apr.product_id = r.product_id
LEFT JOIN product_return_rate    AS prr ON prr.product_id = r.product_id
WHERE r.category_rank <= 3
ORDER BY r.category_id, r.category_rank, r.total_revenue DESC;
 

/* 
--------------------------------------
(5.4) MONTHLY SALES ANALYSIS
--------------------------------------
*/

-- (5.4.1) Paid orders only
CREATE VIEW paid_orders AS
SELECT
    co.order_number,
    co.order_date,
    otc.total_after_discount AS order_total
FROM customer_order AS co
JOIN order_total_cost AS otc ON otc.order_number = co.order_number
JOIN payment_transaction AS pt ON pt.order_number = co.order_number
JOIN payment_status AS ps ON pt.status_id = ps.status_id
WHERE ps.payment_status = 'completed';

-- (5.4.2) Monthly gross sales
CREATE VIEW monthly_gross_sales AS
SELECT
    strftime('%Y',  order_date) AS year,
    strftime('%m',  order_date) AS month,
    strftime('%Y-%m', order_date) AS year_month,
    SUM(order_total) AS gross_sales
FROM paid_orders
GROUP BY year_month;

-- (5.4.3) Monthly refund totals
CREATE VIEW monthly_confirmed_refunds AS
SELECT
    strftime('%Y', pr.start_date) AS year,
    strftime('%m',  pr.start_date) AS month,
    strftime('%Y-%m', pr.start_date) AS year_month,
    SUM(rt.refund_amount) AS refunds_confirmed
FROM product_return AS pr
JOIN refund_total   AS rt ON rt.return_number = pr.return_number
JOIN return_status  AS rs ON rs.status_id     = pr.status_id
WHERE rs.return_status = 'completed'
GROUP BY year, month, year_month;

-- (5.4.4) Monthly net sales (after refunds)
CREATE VIEW monthly_net_sales AS
SELECT
    g.year,
    g.month,
    g.year_month,
    ROUND(g.gross_sales - COALESCE(r.refunds_confirmed, 0), 2) AS net_sales
FROM monthly_gross_sales AS g
LEFT JOIN monthly_confirmed_refunds AS r ON r.year_month = g.year_month;
  
  -- (5.4) Display monthly sales trends
WITH ranked AS (
    SELECT year, month, year_month, net_sales,
     LAG(net_sales) OVER (ORDER BY year_month) AS prev_net_sales
    FROM monthly_net_sales
)

SELECT year, month, net_sales,
    CASE
        WHEN prev_net_sales > 0
            THEN ROUND( (net_sales - prev_net_sales) * 1.0 / prev_net_sales * 100, 2 )
        ELSE NULL
    END AS growth_percent,
	
    -- 3 month moving average of net sales
    ROUND( AVG(net_sales) OVER (
             ORDER BY year_month
             ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
          ), 2 ) AS moving_3_month_avg,
		  
    -- cumulative sales
    ROUND( SUM(net_sales) OVER (
             ORDER BY year_month
          ), 2 ) AS cumulative_sales
		  
FROM ranked
ORDER BY year_month;



