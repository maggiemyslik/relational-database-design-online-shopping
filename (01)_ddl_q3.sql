/* 
--------------------------------------
CUSTOMER AND PAYMENT STRUCTURE
--------------------------------------
*/

-- Customer information and login details
CREATE TABLE customer
(
  email VARCHAR(80) NOT NULL,
  first_name VARCHAR(50) NOT NULL,
  last_name VARCHAR(50) NOT NULL,
  dob DATE NOT NULL,
  phone_number VARCHAR(20) NOT NULL,
  password VARCHAR(30) NOT NULL,
  PRIMARY KEY (email)
);

-- Customer addresses (1:N with customer)
CREATE TABLE customer_address
(
  address_id INT NOT NULL,
  name_at_address VARCHAR(100) NOT NULL,
  building_number VARCHAR(10) NOT NULL,
  street VARCHAR(100) NOT NULL,
  building_name VARCHAR(50),
  flat_number VARCHAR(10),
  post_code VARCHAR(12) NOT NULL,
  city VARCHAR(40) NOT NULL,
  country VARCHAR(40) NOT NULL,
  is_default_address BOOLEAN NOT NULL,
  customer_email VARCHAR(80) NOT NULL,
  PRIMARY KEY (address_id),
  FOREIGN KEY (customer_email) REFERENCES customer(email)
);

-- Payment methods (1:N with customer)
CREATE TABLE payment_method
(
  payment_method_id INT NOT NULL,
  is_default_method BOOLEAN NOT NULL,
  customer_email VARCHAR(80) NOT NULL,
  PRIMARY KEY (payment_method_id),
  FOREIGN KEY (customer_email) REFERENCES customer(email)
);

-- Gift card: subtype of payment_method
CREATE TABLE gift_card
(
  serial_number VARCHAR(32) NOT NULL,
  expiry_date DATE NOT NULL,
  current_balance NUMERIC(10,2) NOT NULL,
  total_amount NUMERIC(10,2) NOT NULL,
  payment_method_id INT NOT NULL,
  PRIMARY KEY (payment_method_id),
  FOREIGN KEY (payment_method_id) REFERENCES payment_method(payment_method_id),
  UNIQUE (serial_number)
);

-- Card: subtype of payment_method (debit or credit)
CREATE TABLE card
(
  card_number VARCHAR(19) NOT NULL,
  verification_code VARCHAR(4) NOT NULL,
  expiry_date DATE NOT NULL,
  name_on_card VARCHAR(80) NOT NULL,
  card_type VARCHAR(6) NOT NULL,
  payment_method_id INT NOT NULL,
  PRIMARY KEY (payment_method_id),
  FOREIGN KEY (payment_method_id) REFERENCES payment_method(payment_method_id)
);

/* 
--------------------------------------
SELLERS, PRODUCTS, AND CATEGORIES
--------------------------------------
*/

-- Registered sellers with business details
CREATE TABLE seller
(
  seller_id INT NOT NULL,
  business_name VARCHAR(80) NOT NULL,
  tax_id VARCHAR(30) NOT NULL,
  building_number VARCHAR(10) NOT NULL,
  street VARCHAR(100) NOT NULL,
  building_name VARCHAR(50),
  flat_number VARCHAR(10),
  post_code VARCHAR(12) NOT NULL,
  city VARCHAR(40) NOT NULL,
  country VARCHAR(40) NOT NULL,
  PRIMARY KEY (seller_id)
);

-- Product categories 
CREATE TABLE category
(
  category_id INT NOT NULL,
  category_name VARCHAR(50) NOT NULL,
  UNIQUE(category_name),
  PRIMARY KEY (category_id)
);

-- Product details including seller and category
CREATE TABLE product
(
  product_id INT NOT NULL,
  name VARCHAR(30) NOT NULL,
  colour VARCHAR(20) NOT NULL,
  height FLOAT,
  width FLOAT,
  depth FLOAT,
  unit_price NUMERIC(10,2) NOT NULL,
  stock INT NOT NULL,
  brand VARCHAR(50) NOT NULL,
  warranty_days INT NOT NULL,
  weight FLOAT NOT NULL,
  seller_id INT NOT NULL,
  category_id INT NOT NULL,
  PRIMARY KEY (product_id),
  FOREIGN KEY (seller_id) REFERENCES seller(seller_id),
  FOREIGN KEY (category_id) REFERENCES category(category_id)
);

/* 
--------------------------------------
CUSTOMER BASKETS AND ORDERS
--------------------------------------
*/

-- Basket (1:1 with customer)
CREATE TABLE basket
(
  basket_id INT NOT NULL,
  email VARCHAR(80) NOT NULL,
  PRIMARY KEY (basket_id),
  FOREIGN KEY (email) REFERENCES customer(email),
  UNIQUE (email)
);

-- Items currently in each basket (1:N with product)
CREATE TABLE in_basket
(
  quantity INT NOT NULL,
  product_id INT NOT NULL,
  basket_id INT NOT NULL,
  PRIMARY KEY (product_id, basket_id),
  FOREIGN KEY (product_id) REFERENCES product(product_id),
  FOREIGN KEY (basket_id) REFERENCES basket(basket_id)
);

-- Discount codes (fixed rate or percent subtypes)
CREATE TABLE discount
(
  discount_code INT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  percent_discount_value INT,
  fixed_discount_value NUMERIC(10,2),
  PRIMARY KEY (discount_code)
);

-- Orders placed by customers
CREATE TABLE customer_order
(
  order_number INT NOT NULL,
  order_date DATE NOT NULL,
  customer_email VARCHAR(80) NOT NULL,
  applied_discount_code INT,
  PRIMARY KEY (order_number),
  FOREIGN KEY (customer_email) REFERENCES customer(email),
  FOREIGN KEY (applied_discount_code) REFERENCES discount(discount_code)
);

-- Items included in each order (1:N with order)
CREATE TABLE order_inventory
(
  quantity INT NOT NULL,
  vat_per_unit NUMERIC(10,2) NOT NULL,
  fees_per_unit NUMERIC(10,2) NOT NULL,
  shipping_per_unit NUMERIC(10,2) NOT NULL,
  product_id INT NOT NULL,
  order_number INT NOT NULL,
  PRIMARY KEY (product_id, order_number),
  FOREIGN KEY (product_id) REFERENCES product(product_id),
  FOREIGN KEY (order_number) REFERENCES customer_order(order_number)
);

-- Product reviews written (1:1 with product per order)
CREATE TABLE review
(
  review_number INT NOT NULL,
  product_rating INT NOT NULL,
  review_date DATE NOT NULL,
  review_text VARCHAR(250) NOT NULL,
  order_number INT NOT NULL,
  product_id INT NOT NULL,
  PRIMARY KEY (review_number),
  FOREIGN KEY (product_id, order_number) REFERENCES order_inventory(product_id, order_number),
  UNIQUE (product_id, order_number)
);

/* 
--------------------------------------
RETURNS, DELIVERIES, AND PAYMENTS
--------------------------------------
*/

-- Possible return statuses 
CREATE TABLE return_status
(
  status_id INT NOT NULL,
  return_status VARCHAR(20) NOT NULL,
  PRIMARY KEY (status_id)
);

-- Return requests for orders
CREATE TABLE product_return
(
  return_number INT NOT NULL,
  start_date DATE NOT NULL,
  due_date DATE NOT NULL,
  return_fee NUMERIC(10,2) NOT NULL,
  status_id INT NOT NULL,
  order_number INT NOT NULL,
  PRIMARY KEY (return_number),
  FOREIGN KEY (order_number) REFERENCES customer_order(order_number),
  FOREIGN KEY (status_id) REFERENCES return_status(status_id)
);

-- Items included in each return
CREATE TABLE return_inventory
(
  quantity INT NOT NULL,
  return_number INT NOT NULL,
  product_id INT NOT NULL,
  PRIMARY KEY (return_number, product_id),
  FOREIGN KEY (return_number) REFERENCES product_return(return_number),
  FOREIGN KEY (product_id) REFERENCES product(product_id)
);

-- Delivery status tracking 
CREATE TABLE delivery_status
(
  status_id INT NOT NULL,
  delivery_status VARCHAR(20) NOT NULL,
  PRIMARY KEY (status_id)
);

-- Delivery specs for orders
CREATE TABLE delivery
(
  tracking_number INT NOT NULL,
  status_id INT NOT NULL,
  delivery_date DATE NOT NULL,
  address_id INT NOT NULL,
  PRIMARY KEY (tracking_number),
  FOREIGN KEY (address_id) REFERENCES customer_address(address_id),
  FOREIGN KEY (status_id) REFERENCES delivery_status(status_id)
);

-- Items included in each delivery (mixed parcels allowed)
CREATE TABLE delivery_item 
(
  quantity        INT NOT NULL,
  tracking_number INT NOT NULL,
  product_id      INT NOT NULL,
  order_number    INT NOT NULL,
  PRIMARY KEY (tracking_number, order_number, product_id),
  FOREIGN KEY (tracking_number) REFERENCES delivery (tracking_number),
  FOREIGN KEY (product_id, order_number) REFERENCES order_inventory (product_id, order_number)
);

-- Payment statuses
CREATE TABLE payment_status
(
  status_id INT NOT NULL,
  payment_status VARCHAR(20) NOT NULL,
  PRIMARY KEY (status_id)
);

-- Payment transactions per order
CREATE TABLE payment_transaction
(
  transaction_id INT NOT NULL,
  payment_date DATE NOT NULL,
  status_id INT NOT NULL,
  order_number INT NOT NULL,
  PRIMARY KEY (transaction_id),
  FOREIGN KEY (order_number) REFERENCES customer_order(order_number),
  FOREIGN KEY (status_id) REFERENCES payment_status(status_id)
);

-- Payment method details per transaction
CREATE TABLE payment_transaction_details
(
  amount NUMERIC(10,2) NOT NULL,
  transaction_id INT NOT NULL,
  payment_method_id INT NOT NULL,
  PRIMARY KEY (transaction_id, payment_method_id),
  FOREIGN KEY (transaction_id) REFERENCES payment_transaction(transaction_id),
  FOREIGN KEY (payment_method_id) REFERENCES payment_method(payment_method_id)
);

/* 
--------------------------------------
VIEWS FOR DERRIVED ATTRIBUTES OR QUICK ACCESS
--------------------------------------
*/

-- Total cost of all items currently in each basket
CREATE VIEW basket_subtotal AS
SELECT b.basket_id, b.email, SUM(i.quantity * p.unit_price)AS basket_total
FROM basket AS b
JOIN in_basket AS i ON b.basket_id = i.basket_id 
JOIN product AS p ON p.product_id = i.product_id
GROUP BY b.basket_id, b.email;

-- Seller rating based on all product reviews
CREATE VIEW seller_rating AS
SELECT s.seller_id, AVG(r.product_rating)
FROM seller AS s
JOIN product AS p ON s.seller_id = p.seller_id 
JOIN review AS r ON p.product_id = r.product_id
GROUP BY s.seller_id;

-- Subtotal per order before discounts
CREATE VIEW order_total_pre_discount AS 
SELECT oi.order_number, 
    SUM((p.unit_price + oi.fees_per_unit + oi.vat_per_unit + oi.shipping_per_unit) * oi.quantity) AS total_price
FROM order_inventory AS oi 
JOIN product AS p ON oi.product_id  = p.product_id
GROUP BY oi.order_number;

-- Final order cost after applying discount
CREATE VIEW order_total_cost AS
SELECT opd.order_number, opd.total_price AS subtotal,
    CASE
	    WHEN co.applied_discount_code IS NULL              
              THEN opd.total_price
        WHEN d.percent_discount_value IS NOT NULL 
             THEN opd.total_price * (1 - d.percent_discount_value / 100.0)
        WHEN d.fixed_discount_value IS NOT NULL 
             THEN MAX(opd.total_price - d.fixed_discount_value, 0)
        ELSE opd.total_price
    END AS total_after_discount
FROM order_total_pre_discount AS opd
JOIN customer_order AS co ON co.order_number = opd.order_number
LEFT JOIN discount AS d ON co.applied_discount_code = d.discount_code;

-- Total refund amount per return, minus any fees
CREATE VIEW refund_total AS
SELECT pr.return_number,
    CASE
        WHEN SUM(p.unit_price * ri.quantity) - COALESCE(pr.return_fee, 0) < 0
            THEN 0
        ELSE ROUND(SUM(p.unit_price * ri.quantity) - COALESCE(pr.return_fee, 0), 2)
    END AS refund_amount
FROM return_inventory AS ri
JOIN product         AS p  ON p.product_id = ri.product_id
JOIN product_return  AS pr ON pr.return_number = ri.return_number
GROUP BY pr.return_number;

-- Total parcel weight per delivery
CREATE VIEW parcel_weight AS 
SELECT di.tracking_number, SUM(p.weight * di.quantity) AS total_weight 
FROM delivery_item AS di 
JOIN product AS p ON di.product_id = p.product_id
GROUP BY di.tracking_number;

-- Customer loyalty tier based on cumulative spend
CREATE VIEW customer_loyalty AS
SELECT co.customer_email, SUM(otc.total_after_discount) as total_spent, 
CASE
    WHEN SUM(otc.total_after_discount) >= 2000 THEN 'Platinum'
    WHEN SUM(otc.total_after_discount) >= 500 THEN 'Gold'
    WHEN SUM(otc.total_after_discount) >= 100 THEN 'Silver'
    WHEN SUM(otc.total_after_discount) > 0 THEN 'Bronze'
    ELSE 'New'
  END AS loyalty_status
FROM order_total_cost as otc
JOIN customer_order AS co ON co.order_number = otc.order_number 
GROUP BY customer_email;

-- Products with no remaining stock
CREATE VIEW out_of_stock AS
SELECT product_id 
FROM product
WHERE stock <= 0;

