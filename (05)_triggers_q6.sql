-- ------------------------------------------------------------ 
-- BASIC TRIGGERS / DATA CHECKS 
-- ------------------------------------------------------------

-- exactly one default address per customer: flip others to 0
CREATE TRIGGER trg_addr_one_default_ai
AFTER INSERT ON customer_address
FOR EACH ROW
WHEN NEW.is_default_address = 1
BEGIN
  UPDATE customer_address
  SET is_default_address = 0
  WHERE customer_email = NEW.customer_email
    AND address_id <> NEW.address_id;
END;

CREATE TRIGGER trg_addr_one_default_au
AFTER UPDATE OF is_default_address ON customer_address
FOR EACH ROW
WHEN NEW.is_default_address = 1
BEGIN
  UPDATE customer_address
  SET is_default_address = 0
  WHERE customer_email = NEW.customer_email
    AND address_id <> NEW.address_id;
END;

-- exactly one default payment method per customer: flip others to 0 

CREATE TRIGGER trg_pm_one_default_ai
AFTER INSERT ON payment_method
FOR EACH ROW
WHEN NEW.is_default_method = 1
BEGIN
  UPDATE payment_method
  SET is_default_method = 0
  WHERE customer_email = NEW.customer_email
    AND payment_method_id <> NEW.payment_method_id;
END;

CREATE TRIGGER trg_pm_one_default_au
AFTER UPDATE OF is_default_method ON payment_method
FOR EACH ROW
WHEN NEW.is_default_method = 1
BEGIN
  UPDATE payment_method
  SET is_default_method = 0
  WHERE customer_email = NEW.customer_email
    AND payment_method_id <> NEW.payment_method_id;
END;

-- each discount is EITHER flat rate OR percent and in a valid range
CREATE TRIGGER trg_discount_shape_bi
BEFORE INSERT ON discount
FOR EACH ROW
WHEN NOT( (NEW.flat_amount IS NULL) <> (NEW.percent_off IS NULL) )
   OR (NEW.flat_amount IS NOT NULL AND NEW.flat_amount <= 0)
   OR (NEW.percent_off IS NOT NULL AND (NEW.percent_off <= 0 OR NEW.percent_off > 100))
BEGIN
  SELECT RAISE(ABORT, 'discount must be flat OR percent; flat_amount>0 or 0<percent_off<=100');
END;

CREATE TRIGGER trg_discount_shape_bu
BEFORE UPDATE ON discount
FOR EACH ROW
WHEN NOT( (NEW.flat_amount IS NULL) <> (NEW.percent_off IS NULL) )
   OR (NEW.flat_amount IS NOT NULL AND NEW.flat_amount <= 0)
   OR (NEW.percent_off IS NOT NULL AND (NEW.percent_off <= 0 OR NEW.percent_off > 100))
BEGIN
  SELECT RAISE(ABORT, 'discount must be flat OR percent; flat_amount>0 or 0<percent_off<=100');
END;

-- each quantity is positive (apply to every table that has quantity)
CREATE TRIGGER trg_inbasket_qty_pos_bi
BEFORE INSERT ON in_basket
FOR EACH ROW
WHEN NEW.quantity <= 0
BEGIN
  SELECT RAISE(ABORT, 'in_basket.quantity must be > 0');
END;

CREATE TRIGGER trg_inbasket_qty_pos_bu
BEFORE UPDATE OF quantity ON in_basket
FOR EACH ROW
WHEN NEW.quantity <= 0
BEGIN
  SELECT RAISE(ABORT, 'in_basket.quantity must be > 0');
END;

-- order_inventory
CREATE TRIGGER trg_oi_qty_pos_bi
BEFORE INSERT ON order_inventory
FOR EACH ROW
WHEN NEW.quantity <= 0
BEGIN
  SELECT RAISE(ABORT, 'order_inventory.quantity must be > 0');
END;

CREATE TRIGGER trg_oi_qty_pos_bu
BEFORE UPDATE OF quantity ON order_inventory
FOR EACH ROW
WHEN NEW.quantity <= 0
BEGIN
  SELECT RAISE(ABORT, 'order_inventory.quantity must be > 0');
END;

-- return_inventory
CREATE TRIGGER trg_ri_qty_pos_bi
BEFORE INSERT ON return_inventory
FOR EACH ROW
WHEN NEW.quantity <= 0
BEGIN
  SELECT RAISE(ABORT, 'return_inventory.quantity must be > 0');
END;

CREATE TRIGGER trg_ri_qty_pos_bu
BEFORE UPDATE OF quantity ON return_inventory
FOR EACH ROW
WHEN NEW.quantity <= 0
BEGIN
  SELECT RAISE(ABORT, 'return_inventory.quantity must be > 0');
END;

-- delivery_item
CREATE TRIGGER trg_di_qty_pos_bi
BEFORE INSERT ON delivery_item
FOR EACH ROW
WHEN NEW.quantity <= 0
BEGIN
  SELECT RAISE(ABORT, 'delivery_item.quantity must be > 0');
END;

CREATE TRIGGER trg_di_qty_pos_bu
BEFORE UPDATE OF quantity ON delivery_item
FOR EACH ROW
WHEN NEW.quantity <= 0
BEGIN
  SELECT RAISE(ABORT, 'delivery_item.quantity must be > 0');
END;

--- product weight and dimensions must be positive (when provided) */
CREATE TRIGGER trg_product_dims_bi
BEFORE INSERT ON product
FOR EACH ROW
WHEN (NEW.weight IS NOT NULL AND NEW.weight <= 0)
   OR (NEW.depth  IS NOT NULL AND NEW.depth  <= 0)
   OR (NEW.width  IS NOT NULL AND NEW.width  <= 0)
   OR (NEW.height IS NOT NULL AND NEW.height <= 0)
BEGIN
  SELECT RAISE(ABORT, 'product weight/depth/width/height must be > 0 when set');
END;

CREATE TRIGGER trg_product_dims_bu
BEFORE UPDATE ON product
FOR EACH ROW
WHEN (NEW.weight IS NOT NULL AND NEW.weight <= 0)
   OR (NEW.depth  IS NOT NULL AND NEW.depth  <= 0)
   OR (NEW.width  IS NOT NULL AND NEW.width  <= 0)
   OR (NEW.height IS NOT NULL AND NEW.height <= 0)
BEGIN
  SELECT RAISE(ABORT, 'product weight/depth/width/height must be > 0 when set');
END;

-- ------------------------------------------------------------ 
-- QUESTION 6. BUSINESS LOGIC AND DB CONSISTENCY TRIGGERS 
-- ------------------------------------------------------------

-- Block orders that exceed stock 
CREATE TRIGGER check_stock_before_order
BEFORE INSERT ON order_inventory
FOR EACH ROW
BEGIN
  SELECT
    CASE
      WHEN (SELECT stock FROM product WHERE product_id = NEW.product_id) < NEW.quantity
      THEN RAISE(ABORT, 'Not enough stock for this product.')
    END;
END;

-- Decrease stock when a product is ordered
CREATE TRIGGER update_stock_after_order
AFTER INSERT ON order_inventory
FOR EACH ROW
BEGIN
  UPDATE product
     SET stock = stock - NEW.quantity
   WHERE product_id = NEW.product_id;
END;

-- Increase stock when a return is completed
CREATE TRIGGER update_stock_after_return_item
AFTER INSERT ON return_inventory
FOR EACH ROW
WHEN EXISTS (
  SELECT 1
  FROM product_return pr
  WHERE pr.return_number = NEW.return_number
    AND pr.status_id = 3       -- completed
)
BEGIN
  UPDATE product
     SET stock = stock + NEW.quantity
   WHERE product_id = NEW.product_id;
END;



