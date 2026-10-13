-- ------------------------------------------------------------
-- A. BASIC REFERENTIAL / EXISTENCE CHECKS 
-- ------------------------------------------------------------

-- A1. Baskets referencing non-existent customers 
SELECT b.*
FROM basket b
LEFT JOIN customer c ON c.email = b.email
WHERE c.email IS NULL;

-- A2. Payment methods referencing non-existent customers
SELECT pm.*
FROM payment_method pm
LEFT JOIN customer c ON c.email = pm.customer_email
WHERE c.email IS NULL;

-- A3. Products referencing non-existent seller/category
SELECT p.*
FROM product p
LEFT JOIN seller s ON s.seller_id = p.seller_id
LEFT JOIN category g ON g.category_id = p.category_id
WHERE s.seller_id IS NULL OR g.category_id IS NULL;

-- A4. In-basket rows referencing missing parents
SELECT ib.*
FROM in_basket ib
LEFT JOIN product p ON p.product_id = ib.product_id
LEFT JOIN basket  b ON b.basket_id  = ib.basket_id
WHERE p.product_id IS NULL OR b.basket_id IS NULL;

-- A5. Order_inventory rows referencing missing product/order
SELECT oi.*
FROM order_inventory oi
LEFT JOIN product        p  ON p.product_id      = oi.product_id
LEFT JOIN customer_order co ON co.order_number   = oi.order_number
WHERE p.product_id IS NULL OR co.order_number IS NULL;

-- A6. Reviews that somehow slipped past the composite FK (defensive)
SELECT r.*
FROM review r
LEFT JOIN order_inventory oi
  ON oi.product_id = r.product_id AND oi.order_number = r.order_number
WHERE oi.product_id IS NULL;

-- A7. Return_inventory rows referencing missing product/return
SELECT ri.*
FROM return_inventory ri
LEFT JOIN product        p  ON p.product_id       = ri.product_id
LEFT JOIN product_return pr ON pr.return_number   = ri.return_number
WHERE p.product_id IS NULL OR pr.return_number IS NULL;

-- A8. Delivery rows referencing missing address/status
SELECT d.*
FROM delivery d
LEFT JOIN customer_address a ON a.address_id = d.address_id
LEFT JOIN delivery_status  s ON s.status_id  = d.status_id
WHERE a.address_id IS NULL OR s.status_id IS NULL;

-- A9. Delivery_item must match an order line and a delivery id
SELECT di.*
FROM delivery_item di
LEFT JOIN order_inventory oi
  ON oi.order_number = di.order_number AND oi.product_id = di.product_id
LEFT JOIN delivery d ON d.tracking_number = di.tracking_number
WHERE oi.order_number IS NULL OR d.tracking_number IS NULL;

-- A10. Payment transactions: order & status must exist
SELECT pt.*
FROM payment_transaction pt
LEFT JOIN customer_order co ON co.order_number = pt.order_number
LEFT JOIN payment_status  ps ON ps.status_id   = pt.status_id
WHERE co.order_number IS NULL OR ps.status_id IS NULL;

-- A11. Payment details must refer to valid transaction & method
SELECT ptd.*
FROM payment_transaction_details ptd
LEFT JOIN payment_transaction pt ON pt.transaction_id   = ptd.transaction_id
LEFT JOIN payment_method      pm ON pm.payment_method_id = ptd.payment_method_id
WHERE pt.transaction_id IS NULL OR pm.payment_method_id IS NULL;

-- ------------------------------------------------------------
-- B. “ONE DEFAULT” RULES
-- ------------------------------------------------------------

-- B1. Each customer with addresses should have EXACTLY ONE default address.
SELECT customer_email,
       SUM(CASE WHEN is_default_address THEN 1 ELSE 0 END) AS default_count,
       COUNT(*) AS total_addresses
FROM customer_address
GROUP BY customer_email
HAVING SUM(CASE WHEN is_default_address THEN 1 ELSE 0 END) <> 1;

-- B2. Each customer with payment methods should have EXACTLY ONE default method.
SELECT customer_email,
       SUM(CASE WHEN is_default_method THEN 1 ELSE 0 END) AS default_count,
       COUNT(*) AS total_methods
FROM payment_method
GROUP BY customer_email
HAVING SUM(CASE WHEN is_default_method THEN 1 ELSE 0 END) <> 1;

-- ------------------------------------------------------------
-- C. SUBTYPE / MUTUAL EXCLUSIVITY
-- ------------------------------------------------------------

-- C1. Every payment_method must be in EXACTLY ONE of card or gift_card
WITH pm AS (
  SELECT pm.payment_method_id,
         CASE WHEN gc.payment_method_id IS NOT NULL THEN 1 ELSE 0 END AS is_gc,
         CASE WHEN c.payment_method_id  IS NOT NULL THEN 1 ELSE 0 END AS is_card
  FROM payment_method pm
  LEFT JOIN gift_card gc ON gc.payment_method_id = pm.payment_method_id
  LEFT JOIN card      c  ON c.payment_method_id  = pm.payment_method_id
)
SELECT *
FROM pm
WHERE (is_gc + is_card) <> 1;

-- C2. Discount must be either percent OR fixed (exactly one non-NULL)
SELECT d.*
FROM discount d
WHERE (CASE WHEN percent_discount_value IS NOT NULL THEN 1 ELSE 0 END) +
      (CASE WHEN fixed_discount_value   IS NOT NULL THEN 1 ELSE 0 END) <> 1;

-- ------------------------------------------------------------
-- D. VALUE RANGES / DOMAIN LOGIC
-- ------------------------------------------------------------

-- D1. Review ratings must be integers 0..5
SELECT r.*
FROM review r
WHERE r.product_rating < 0 OR r.product_rating > 5;

-- D2. Prices, fees, shipping, VAT must be non-negative
SELECT p.*
FROM product p
WHERE p.unit_price < 0 OR p.weight <= 0 OR p.stock < 0;

SELECT oi.*
FROM order_inventory oi
WHERE oi.vat_per_unit < 0 OR oi.fees_per_unit < 0 OR oi.shipping_per_unit < 0 OR oi.quantity <= 0;

-- D3. Discount ranges
SELECT d.*
FROM discount d
WHERE (percent_discount_value IS NOT NULL AND (percent_discount_value < 0 OR percent_discount_value > 100))
   OR (fixed_discount_value   IS NOT NULL AND fixed_discount_value   < 0);

-- D4. Gift card balances: 0 <= current_balance <= total_amount
SELECT gc.*
FROM gift_card gc
WHERE gc.current_balance < 0 OR gc.current_balance > gc.total_amount;

-- ------------------------------------------------------------
-- E. BUSINESS RULES ACROSS TABLES
-- ------------------------------------------------------------

-- E1. Returned quantity must be <= purchased quantity (by order & product)
SELECT ri.return_number, pr.order_number, ri.product_id,
       ri.quantity AS returned_qty, oi.quantity AS ordered_qty
FROM return_inventory ri
JOIN product_return pr ON pr.return_number = ri.return_number
LEFT JOIN order_inventory oi
  ON oi.order_number = pr.order_number AND oi.product_id = ri.product_id
WHERE oi.quantity IS NULL OR ri.quantity > oi.quantity;

-- E2. Discounts applied must be valid on the order_date
SELECT co.order_number, co.order_date, co.applied_discount_code, d.start_date, d.end_date
FROM customer_order co
JOIN discount d ON d.discount_code = co.applied_discount_code
WHERE co.order_date < d.start_date OR co.order_date > d.end_date;

-- E3. Orders must have at least one line item
SELECT co.*
FROM customer_order co
LEFT JOIN order_inventory oi ON oi.order_number = co.order_number
GROUP BY co.order_number
HAVING COUNT(oi.product_id) = 0;

-- E4. Baskets should contain at least one item 
SELECT b.*
FROM basket b
LEFT JOIN in_basket i ON i.basket_id = b.basket_id
GROUP BY b.basket_id
HAVING COUNT(i.product_id) = 0;

-- ------------------------------------------------------------
-- F. DUPLICATES / UNIQUENESS 
-- ------------------------------------------------------------

-- F1. Duplicate reviews per (product_id, order_number) (should be none; UNIQUE exists)
SELECT product_id, order_number, COUNT(*) AS cnt
FROM review
GROUP BY product_id, order_number
HAVING COUNT(*) > 1;

-- F2. Multiple baskets per email (should be none; UNIQUE(email) exists)
SELECT email, COUNT(*) AS baskets
FROM basket
GROUP BY email
HAVING COUNT(*) > 1;

-- F3. Multiple default addresses flagged above; here’s the same for methods, see B2.

-- ------------------------------------------------------------
-- G. QUALITY CHECKS
-- ------------------------------------------------------------

-- G1. Sellers with no products
SELECT s.*
FROM seller s
LEFT JOIN product p ON p.seller_id = s.seller_id
GROUP BY s.seller_id
HAVING COUNT(p.product_id) = 0;

-- G2. Categories with no products
SELECT c.*
FROM category c
LEFT JOIN product p ON p.category_id = c.category_id
GROUP BY c.category_id
HAVING COUNT(p.product_id) = 0;

-- G3. Products never ordered
SELECT p.*
FROM product p
LEFT JOIN order_inventory oi ON oi.product_id = p.product_id
GROUP BY p.product_id
HAVING COUNT(oi.order_number) = 0;

-- G4. Orders with shipments but no payment completed 
SELECT DISTINCT di.order_number
FROM delivery_item di
LEFT JOIN payment_transaction pt ON pt.order_number = di.order_number
LEFT JOIN payment_status ps ON ps.status_id = pt.status_id
GROUP BY di.order_number
HAVING SUM(CASE WHEN LOWER(ps.payment_status) = 'completed' THEN 1 ELSE 0 END) = 0;


