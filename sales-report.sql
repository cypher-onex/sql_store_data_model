-- Sales Report
SELECT
	'First half of 2019' AS date_range,
    SUM(ivoice_total) AS total_sales,
    SUM(payment_total) AS total_payments,
    SUM(invoice_total - payment_total) AS what_we_expect
FROM invoices
WHERE invoice_date
	BETWEEN '2019-01-01' AND '2019-06-30'
UNION
SELECT
	'Second half of 2019' AS date_range,
    SUM(ivoice_total) AS total_sales,
    SUM(payment_total) AS total_payments,
    SUM(invoice_total - payment_total) AS what_we_expect
FROM invoices
WHERE invoice_date
	BETWEEN '2019-06-30' AND '2019-12-31'
UNION
SELECT
	'First half of 2019' AS date_range,
    SUM(ivoice_total) AS total_sales,
    SUM(payment_total) AS total_payments,
    SUM(invoice_total - payment_total) AS what_we_expect
FROM invoices;





-- Sales report by state and city
SELECT
	state,
    city,
    SUM(invoice_total) AS total_sales
FROM invoices i
JOIN customers USING (customer_id)
WHERE invoice_date >= '2019-07-01'
GROUP BY state, city;


    


-- Find products that have never been ordered
SELECT * 
FROM products
WHERE product_id NOT IN (
	SELECT DISTINCT product_id
    FROM order_itmes
);





-- Find customers with at least two invoices
SELECT *
FROM customers
WHERE customers_id = ANY (
	SELECT customers_id
    FROM invoices
	GROUP BY customer_id
    HAVING COUNT(*) >= 2
);
    




-- Find invoices that are larger than the
-- customer's average invoice amount
SELECT *
FROM invoices i
WHERE invoice_total > (
	SELECT AVG(invoice_total)
    FROM invoicres
    WHERE customer_id = i.customer_id
);