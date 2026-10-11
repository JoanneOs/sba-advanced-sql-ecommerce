USE ecommerce;

/* creating indexes to make searches faster */
CREATE INDEX idx_last_name ON customers(last_name);
CREATE INDEX idx_registration_date ON customers(registration_date);
CREATE INDEX idx_order_date ON orders(order_date);
CREATE INDEX idx_category ON products(category);

/* adding primary keys to identify each record */
ALTER TABLE customers ADD PRIMARY KEY (customer_id);
ALTER TABLE orders ADD PRIMARY KEY (order_id);
ALTER TABLE products ADD PRIMARY KEY (product_id);
ALTER TABLE orderdetails ADD PRIMARY KEY (order_detail_id);

/* connecting orders to customers */
ALTER TABLE orders
ADD FOREIGN KEY (customer_id) REFERENCES customers(customer_id);

/* connecting order details to orders and products */
ALTER TABLE orderdetails
ADD FOREIGN KEY (order_id) REFERENCES orders(order_id);

ALTER TABLE orderdetails
ADD FOREIGN KEY (product_id) REFERENCES products(product_id);

/* making sure product prices are greater than zero */
ALTER TABLE products
ADD CHECK (price > 0);

/* updating the order total when a new item is added */
DELIMITER &&
CREATE TRIGGER after_insert_orderdetails
AFTER INSERT ON orderdetails
FOR EACH ROW
BEGIN
    UPDATE orders
    SET total_amount = total_amount + (NEW.quantity * NEW.unit_price)
    WHERE order_id = NEW.order_id;
END &&
DELIMITER ;

/* updating the order total when an item is changed */
DELIMITER &&
CREATE TRIGGER after_update_orderdetails
AFTER UPDATE ON orderdetails
FOR EACH ROW
BEGIN
    UPDATE orders
    SET total_amount = total_amount - (OLD.quantity * OLD.unit_price)
    WHERE order_id = OLD.order_id;

    UPDATE orders
    SET total_amount = total_amount + (NEW.quantity * NEW.unit_price)
    WHERE order_id = NEW.order_id;
END &&
DELIMITER ;

/* creating a table to keep track of customer address changes */
CREATE TABLE AddressChangeLog (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT,
    old_address VARCHAR(500),
    new_address VARCHAR(500),
    change_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

/* saving the old and new address when a customer updates it */
DELIMITER &&
CREATE TRIGGER after_update_address
AFTER UPDATE ON customers
FOR EACH ROW
BEGIN
    IF NOT (
        OLD.address_street <=> NEW.address_street
        AND OLD.address_city <=> NEW.address_city
        AND OLD.address_state <=> NEW.address_state
        AND OLD.address_postal_code <=> NEW.address_postal_code
    ) THEN
        INSERT INTO AddressChangeLog (customer_id, old_address, new_address)
        VALUES (
            NEW.customer_id,
            CONCAT_WS(', ', OLD.address_street, OLD.address_city, OLD.address_state, OLD.address_postal_code),
            CONCAT_WS(', ', NEW.address_street, NEW.address_city, NEW.address_state, NEW.address_postal_code)
        );
    END IF;
END &&
DELIMITER ;

/* creating a view to see customer orders and product details together */
CREATE VIEW CustomerOrderDetailView AS
SELECT c.customer_id, c.first_name, c.last_name,
       o.order_id, od.product_id, od.quantity, od.unit_price
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN orderdetails od ON o.order_id = od.order_id;

/* checking the orders for customer 1 */
SELECT * FROM CustomerOrderDetailView
WHERE customer_id = 1;

/* finding the top 3 customers who spent the most */
SELECT c.customer_id, c.first_name, c.last_name,
       SUM(o.total_amount) AS total_spending
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_spending DESC
LIMIT 3;

/* finding the product category with the most items sold */
SELECT p.category, SUM(od.quantity) AS total_sold
FROM products p
JOIN orderdetails od ON p.product_id = od.product_id
GROUP BY p.category
ORDER BY total_sold DESC
LIMIT 1;

/* creating a view to see customers, orders, and products */
CREATE VIEW BusinessScenarioView AS
SELECT c.customer_id, c.first_name, c.last_name,
       o.order_id, p.product_name, p.category
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN orderdetails od ON o.order_id = od.order_id
JOIN products p ON od.product_id = p.product_id;

/* checking the view */
SELECT * FROM BusinessScenarioView;

/* adding customer email and order date to the view */
CREATE OR REPLACE VIEW BusinessScenarioView AS
SELECT c.customer_id, c.first_name, c.last_name,
       c.email, o.order_id, o.order_date,
       p.product_name, p.category
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN orderdetails od ON o.order_id = od.order_id
JOIN products p ON od.product_id = p.product_id;

/* checking the updated view */
SELECT * FROM BusinessScenarioView;

/* removing the view */
DROP VIEW BusinessScenarioView;

/* creating a table to keep track of product changes */
CREATE TABLE ProductAudit (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT,
    old_price DECIMAL(10, 2),
    new_price DECIMAL(10, 2),
    old_category VARCHAR(100),
    new_category VARCHAR(100),
    change_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

/* creating a trigger to record product price changes */
DELIMITER &&
CREATE TRIGGER trg_product_price_audit
AFTER UPDATE ON products
FOR EACH ROW
BEGIN
    IF OLD.price <> NEW.price THEN
        INSERT INTO ProductAudit (product_id, old_price, new_price)
        VALUES (NEW.product_id, OLD.price, NEW.price);
    END IF;
END &&
DELIMITER ;

/* removing the old trigger before creating the updated one */
DROP TRIGGER IF EXISTS trg_product_price_audit;

/* updating the trigger to track price and category changes */
DELIMITER &&
CREATE TRIGGER trg_product_audit
AFTER UPDATE ON products
FOR EACH ROW
BEGIN
    IF OLD.price <> NEW.price OR OLD.category <> NEW.category THEN
        INSERT INTO ProductAudit (product_id, old_price, new_price, old_category, new_category)
        VALUES (NEW.product_id, OLD.price, NEW.price, OLD.category, NEW.category);
    END IF;
END &&
DELIMITER ;

/* removing the trigger */
DROP TRIGGER IF EXISTS trg_product_audit;
