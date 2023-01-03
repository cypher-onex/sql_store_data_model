CREATE VIEW sales_by_customer AS 
SELECT
	c.customer_id,
    c.first_name,
    SUM(invoice_total) AS total_sales
FROM customers c
JOIN invoices i USING (customer_id)
GROUP BY customer_id, name;





CREATE VIEW customers_balance AS 
	SELECT 
    c.customer_id,
    c.first_name,
    SUM(invoice_total -payment_total)
FROM customers c
JOIN invoices i USING (customer_id)
GROUP BY customer_id, first_name;





CREATE VIEW invoices_with_balance AS
SELECT
	invoice_id,
    number,
    customer_id,
    invoice_total,
    payment_total,
    invoice_total - payment_total AS balance,
    invoice_date,
    due_date,
    payment_date
FROM invoices
WHERE (invoice_total - payment_total) > 0;





DROP PROCEDURE IF EXISTS select_customers_with_phone_numbers;
DELIMITER $$
CREATE PROCEDURE select_customers_with_phone_numbers()
BEGIN
	SELECT
		CONCAT(first_name, ' ', last_name) AS customer,
		COALESCE(phone, 'Uknown') AS phone
	FROM customers;
	END $$
DELIMITER ;





DROP PROCEDURE IF EXISTS select_orders_and_shippers;
DELIMITER $$
CREATE PROCEDURE select_orders_and_shippers()
BEGIN
	SELECT
		order_id,
		IFNULL(shipper_id, '...'),
		COALESCE(shipper_id, comments, 'Not assigned') AS shipper
	FROM orders;
END $$
DELIMITER ;





DROP PROCEDURE IF EXISTS find_actvie_and_archived_orders
DELIMITER $$
CREATE PROCEDURE find_actvie_or_archived_orders()
BEGIN
	SELECT
		order_id,
		order_date,
		IF(
			YEAR(order_date) = YEAR(NOT()),
			'Active',
			'Archived') AS category
	FROM orders;
END $$
DELIMITER ;





DROP PROCEDURE IF EXISTS find_orders_fequecy;
DELIMITER $$
CREATE PROCEDURE find_orders_fequecy()
BEGIN
	SELECT
		product_id,
		name,
		COUNT(*) AS orders,
		IF(COUNT(*) >1, 'Many times', 'Once') AS frequency
	FROM products
	JOIN order_items USING (product_id)
	GROUP BY product_id, name;
END $$
DELIMITER ;






DELIMITER $$
CREATE PROCEDURE get_invoices_by_customer
(
	customer_id INT
)
BEGIN
	SELECT *
    FROM invoices i
    WHERE i.customer_id = customer_id;
END $$
DELIMITER ;





DROP PROCEDURE IF EXISTS get_customers_by_state;
DELIMITER $$
CREATE PROCEDURE get_ccusomers_by_state
(
	state CHAR(2)
)
BEGIN
	SELECT * FROM customers c
    WHERE c.state = IFNULL(state, c.state);
END$$
DELIMITER ;





DROP PROCEDURE IF EXISTS get_payments;
DELIMITER $$
CREATE PROCEDURE get_payments
(
	customer_id INT,
    payment_method_id TINYINT
)
BEGIN
	SELECT *
    FROM payments p
    WHERE p.customer_id = IFNULL(customer_id, p.customer_id) AND
		  p.payment_method = 
				IFNULL(payment_method_id, p.payment_method);
END$$
DELIMITER ;





DROP PROCEDURE IF EXISTS make_payment
DELIMITER $$
CREATE PROCEDURE make_payment
(
	invoice_id INT,
    payment_amount DECIMAL(9, 2),
    payment_date DATE
)
BEGIN
	IF payment_amount <= 0 THEN
		SIGNAL SQLSTATE '2203';
			SET MESSAGE_TEXT = 'Invalid payment amount';
	END IF;
    
	UPDATE invoices i
    SET
		i.payment_total = payment_amount,
        i.payment_date = payment_date
	WHERE i.invoice_id = invoice_id;
END$$
DELIMITER ;





DROP PROCEDURE IF EXISTS get_unpaid_invoices_for_customer;
DELIMITER $$
CREATE PROCEDURE get_unpaid_invoices_for_customer
(
	customer_id INT,
    OUT invoices_count INT,
    OUT invoices_total DECIMAL(9, 2)
)
BEGIN
	SELECT COUNT(*), SUM(invoice_total)
    INTO invoices_count, invoices_total
    FROM invoices i
    WHERE i.customer_id = customer_id
		AND payment_total = 0;
END$$
DELIMITER ;





DROP PROCEDURE IF EXISTS get_risk_factor;
DELIMITER $$
CREATE PROCEDURE get_risk_factor ()
BEGIN
	DECLARE risk_factore DECIMAL(9, 2) DEFAULT 0;
    DECLARE invoices_total DECIMAL(9, 2);
    DECLARE invoices_count INT;
    
    SELECT COUNT(*), SUM(invoice_total)
    INTO invoices_count, invoices_total
    FROM invoices;
    
    SET risk_factor = invoices_total / invoices_count * 5;
    
    SELECT risk_factor;
END $$
DELIMITER ;
    




DELIMITER $$
CREATE FUNCTION get_risk_factor_for_customer
(
		customer_id INT
)
RETURNS INTEGER
READS SQL DATA
BEGIN
	DECLARE risk_factore DECIMAL(9, 2) DEFAULT 0;
    DECLARE invoices_total DECIMAL(9, 2);
    DECLARE invoices_count INT;
    
    SELECT COUNT(*), SUM(invoice_total)
    INTO invoices_count, invoices_total
    FROM invoices
    WHERE i.customer_id = customer_id;
    
    SET risk_factor = invoices_total / invoices_count * 5;
    
    RETURN IFNULL(risk_factor, 0);
END $$
DELIMITER ;





CREATE TABLE payments_audit
(
	customer_id        INT NOT NULL,
    date             DATE NOT NULL,
    amount           DECIMAL(9, 2) NOT NULL,
    action_type      VARCHAR(50) NOT NULL,
    action_date      DATETIME NOT NULL
);





DROP TRIGGER IF EXISTS payments_after_insert;
DELIMITER $$
CREATE TRIGGER payments_after_insert
	AFTER INSERT ON payments
    FOR EACH ROW
BEGIN
	UPDATE invoices
    SET payment_total = payment_total + NEW.amount
    WHERE invoices_id = NEW.invoice_id;
    
    INSERT INTO payments_audit
    VALUES (NEW.customer_id, NEW.date, NEW.amount, 'Insert', NOW());
END $$
DELIMITER ;





DROP TRIGGER IF EXISTS payments_after_delete;
DELIMITER $$
CREATE TRIGGER payments_after_delete
	AFTER DELETE ON payments
    FOR EACH ROW
BEGIN
	UPDATE invoices
    SET payment_total = payment_total - OLD.amount
    WHERE invoice_id = OLD.invoice_id;

    INSERT INTO payments_audit
    VALUES (OLD.customer_id, OLD.date, OLD.amount, 'Delete', NOW());
END $$
DELIMITER ;





DELIMITER $$
CREATE EVENT yearly_delet_stale_audit_rows
ON SCHEDULE
	EVERY 1 YEAR STARTS '2022-01-01' ENDS '2029-01-01'
DO BEGIN
	DELETE FROM payments_audit
    WHERE action_date < NOW() - INTERVAL 1 YEAR;
END $$
DELIMITER ;