
SET search_path = 'inventory_system';

DROP TABLE IF EXISTS stocks;
DROP TABLE IF EXISTS purchase_info;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS suppliers;
DROP TABLE IF EXISTS categories;

CREATE TABLE IF NOT EXISTS categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL,
    category_description VARCHAR(255) NOT NULL,
    UNIQUE (category_name)
);

CREATE TABLE IF NOT EXISTS suppliers (
    supplier_id SERIAL PRIMARY KEY,
    supplier_name VARCHAR(50) NOT NULL,
    phone_number VARCHAR(11) NOT NULL
);

CREATE TABLE IF NOT EXISTS products (
    product_id SERIAL PRIMARY KEY,
    category_id INT NOT NULL,
    product_name VARCHAR(50) NOT NULL,
    product_description VARCHAR(255) NOT NULL,
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

CREATE TABLE IF NOT EXISTS purchase_info (
    purchase_id SERIAL PRIMARY KEY,
    product_id INT NOT NULL,
    supplier_id INT NOT NULL,
    purchase_date DATE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ordered_quantity INT NOT NULL,
    is_approved BOOLEAN NOT NULL DEFAULT FALSE,
    status VARCHAR(10) NOT NULL CHECK(status IN ('PENDING', 'COMPLETE', 'INCOMPLETE')) DEFAULT 'PENDING',
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
);

CREATE TABLE IF NOT EXISTS stocks (
    stock_id SERIAL PRIMARY KEY,
    purchase_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity_received INT NOT NULL,
    buy_price DOUBLE PRECISION NOT NULL,
    total_cost DOUBLE PRECISION NOT NULL,
    date_received DATE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expiration_date DATE,
    FOREIGN KEY (purchase_id) REFERENCES purchase_info(purchase_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- -------------------------------------------------- VIEW

CREATE OR REPLACE VIEW view_stocks AS
SELECT
    stocks.quantity AS "Stock Quantity",
    stocks.expiration_date AS "Stock Expiration Date",
    stocks.sell_price AS "Stock Selling Price",
    stocks.buy_price AS "Stock Buying Price",
    products.product_name AS "Product",
    products.product_description AS "Product Description",
    categories.category_name AS "Category",
    categories.category_description AS "Category Description",
    stocks.stock_id,
    stocks.purchase_id,
    stocks.product_id
FROM stocks
INNER JOIN products ON stocks.product_id = products.product_id
INNER JOIN categories ON products.category_id = categories.category_id;

CREATE OR REPLACE VIEW view_old_stocks AS
SELECT
    stocks.quantity AS "Stock Quantity",
    stocks.expiration_date AS "Stock Expiration Date",
    stocks.sell_price AS "Stock Selling Price",
    stocks.buy_price AS "Stock Buying Price",
    products.product_name AS "Product",
    products.product_description AS "Product Description",
    categories.category_name AS "Category",
    categories.category_description AS "Category Description",
    stocks.stock_id,
    stocks.purchase_id,
    stocks.product_id
FROM stocks
INNER JOIN products ON stocks.product_id = products.product_id
INNER JOIN categories ON products.category_id = categories.category_id
WHERE stocks.expiration_date < CURRENT_DATE;

CREATE OR REPLACE VIEW view_purchases AS
SELECT
    purchase_info.purchase_id AS "Purchase No",
    purchase_info.product_id AS "Product ID",
    purchase_info.supplier_id AS "Supplier ID",
    purchase_info.purchase_date AS "Purchase Date",
    purchase_info.ordered_quantity AS "Ordered Quantity",
    purchase_info.is_approved AS "Is Approved",
    purchase_info.status AS "Status",
    products.product_name AS "Product",
    products.product_description AS "Product Description",
    categories.category_name AS "Category",
    categories.category_description AS "Category Description"
FROM purchase_info
INNER JOIN products ON purchase_info.product_id = products.product_id
INNER JOIN categories ON products.category_id = categories.category_id;

CREATE OR REPLACE VIEW view_suppliers AS
SELECT
    suppliers.supplier_id AS "Supplier ID",
    suppliers.supplier_name AS "Supplier Name",
    suppliers.phone_number AS "Phone Number"
FROM suppliers
INNER JOIN products ON suppliers.supplier_id = products.supplier_id
INNER JOIN categories ON products.category_id = categories.category_id
GROUP BY suppliers.supplier_id;

-- TRIGGERS

CREATE OR REPLACE FUNCTION check_quantity()
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT ordered_quantity FROM purchase_info WHERE purchase_id = NEW.purchase_id) != (SELECT quantity_received FROM stocks WHERE purchase_id = NEW.purchase_id) THEN
        UPDATE purchase_info SET status = 'INCOMPLETE' WHERE purchase_id = NEW.purchase_id;
    ELSE
        UPDATE purchase_info SET status = 'COMPLETE' WHERE purchase_id = NEW.purchase_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_quantity
AFTER INSERT ON stocks
FOR EACH ROW
EXECUTE FUNCTION check_quantity();

-- PROCEDURES

CREATE OR REPLACE PROCEDURE add_category(
    IN category_name VARCHAR(50),
    IN category_description VARCHAR(255)
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO categories(category_name, category_description)
    VALUES (category_name, category_description);
END;
$$;

CREATE OR REPLACE PROCEDURE approve_purchase(
    IN purchase_id INT,
    IN product_id INT,
    IN supplier_id INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- check products and supplier exist
    IF NOT EXISTS (SELECT 1 FROM products WHERE product_id = approve_purchase.product_id) THEN
        RAISE EXCEPTION 'Product does not exist';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM suppliers WHERE supplier_id = approve_purchase.supplier_id) THEN
        RAISE EXCEPTION 'Supplier does not exist';
    END IF;

    -- check if purchase is already approved
    IF (SELECT is_approved FROM purchase_info WHERE purchase_id = approve_purchase.purchase_id AND product_id = approve_purchase.product_id AND supplier_id = approve_purchase.supplier_id) THEN
        RAISE EXCEPTION 'Purchase already approved';
    END IF;

    -- update
    UPDATE purchase_info
    SET is_approved = TRUE
    WHERE purchase_id = approve_purchase.purchase_id AND product_id = approve_purchase.product_id AND supplier_id = approve_purchase.supplier_id;
END;
$$;

CREATE OR REPLACE PROCEDURE add_product(
    IN category_id INT,
    IN product_name VARCHAR(50),
    IN product_description VARCHAR(255)
)
LANGUAGE plpgsql
AS $$
DECLARE
    existing_category_count INT;
BEGIN
    -- check if category exists
    SELECT COUNT(*) INTO existing_category_count
    FROM categories
    WHERE category_id = category_id;

    IF existing_category_count = 0 THEN
        RAISE EXCEPTION 'Category does not exist';
    END IF;

    -- check if product name exists
    IF EXISTS (SELECT 1 FROM products WHERE product_name = add_product.product_name) THEN
        RAISE EXCEPTION 'Product already exists';
    END IF;

    -- insert product
    INSERT INTO products(category_id, product_name, product_description)
    VALUES (category_id, product_name, product_description);
END;
$$;

CREATE OR REPLACE PROCEDURE add_supplier(
    IN supplier_name VARCHAR(50),
    IN phone_number VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- check if supplier name exists
    IF EXISTS (SELECT 1 FROM view_suppliers WHERE "Supplier Name" = add_supplier.supplier_name) THEN
        RAISE EXCEPTION 'Supplier already exists';
    END IF;

    -- insert supplier
    INSERT INTO suppliers(supplier_name, phone_number)
    VALUES (supplier_name, phone_number);
END;
$$;

CREATE OR REPLACE PROCEDURE update_supplier(
    IN supplier_id INT,
    IN supplier_name VARCHAR(50),
    IN phone_number VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- check if supplier id exists
    IF NOT EXISTS (SELECT 1 FROM view_suppliers WHERE "Supplier ID" = update_supplier.supplier_id) THEN
        RAISE EXCEPTION 'Supplier does not exist';
    END IF;

    -- update supplier
    UPDATE suppliers
    SET supplier_name = update_supplier.supplier_name, phone_number = update_supplier.phone_number
    WHERE supplier_id = update_supplier.supplier_id;
END;
$$;

CREATE OR REPLACE PROCEDURE add_purchase_product(
    IN product_id INT,
    IN supplier_id INT,
    IN ordered_quantity INT,
    IN purchase_date DATE
)
LANGUAGE plpgsql
AS $$
DECLARE
    final_purchase_date DATE;
BEGIN
    -- check if product id exists
    IF NOT EXISTS (SELECT 1 FROM products WHERE product_id = add_purchase_product.product_id) THEN
        RAISE EXCEPTION 'Product does not exist';
    END IF;

    -- check if supplier id exists
    IF NOT EXISTS (SELECT 1 FROM view_suppliers WHERE "Supplier ID" = add_purchase_product.supplier_id) THEN
        RAISE EXCEPTION 'Supplier does not exist';
    END IF;

    -- if purchase date is null, set to current date
    IF purchase_date IS NULL THEN
        final_purchase_date := CURRENT_DATE;
    ELSE
        final_purchase_date := purchase_date;
    END IF;

    -- insert purchase
    INSERT INTO purchase_info(product_id, supplier_id, ordered_quantity, purchase_date)
    VALUES (product_id, supplier_id, ordered_quantity, final_purchase_date);
END;
$$;

CREATE OR REPLACE PROCEDURE add_stock_details(
    IN product_id INT,
    IN purchase_id INT,
    IN quantity_received INT,
    IN buy_price DOUBLE PRECISION,
    IN total_cost DOUBLE PRECISION,
    IN expiration_date DATE,
    IN date_received DATE
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- check if purchase exists
    IF NOT EXISTS (SELECT 1 FROM view_purchases WHERE "Purchase No" = add_stock_details.purchase_id 
        AND "Product ID" = add_stock_details.product_id AND "Supplier ID" = add_stock_details.supplier_id) THEN
        RAISE EXCEPTION 'Purchase does not exist';
    END IF;

    -- check if product exists
    IF NOT EXISTS (SELECT 1 FROM products WHERE product_id = add_stock_details.product_id) THEN
        RAISE EXCEPTION 'Product does not exist';
    END IF;

    -- insert into stocks
    INSERT INTO stocks(product_id, purchase_id, quantity_received, buy_price, total_cost, expiration_date, date_received)
    VALUES (product_id, purchase_id, quantity_received, buy_price, total_cost, expiration_date, date_received);
END;
$$;

-- FUNCTIONS

CREATE OR REPLACE FUNCTION calculate_average_incomplete_deliveries(
    supplier_id INT
)
RETURNS DOUBLE PRECISION
AS $$
DECLARE
    count_all_deliveries INT;
    count_incomplete_deliveries INT;
    average DOUBLE PRECISION;
BEGIN
    -- get count of all deliveries
    SELECT COUNT(*) INTO count_all_deliveries
    FROM view_purchases
    WHERE "Is Approved" = TRUE
        AND "Supplier ID" = supplier_id;

    -- get count of all incomplete deliveries
    SELECT COUNT(*) INTO count_incomplete_deliveries
    FROM view_purchases
    WHERE "Is Approved" = FALSE
        AND "Supplier ID" = supplier_id;

    -- calculate average
    IF count_all_deliveries = 0 THEN
        average := 1;
    ELSE
        average := count_incomplete_deliveries::DOUBLE PRECISION / count_all_deliveries::DOUBLE PRECISION;
    END IF;

    RETURN average;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION calculate_average_delivery_duration(
    supplier_id INT
)
RETURNS DOUBLE PRECISION
AS $$
DECLARE
    average DOUBLE PRECISION;
BEGIN
    -- get average delivery duration
    SELECT AVG(EXTRACT(DAY FROM ("Date Recieved" - "Purchase Date"))) INTO average
    FROM view_purchases
    WHERE "Is Approved" = TRUE
        AND "Supplier ID" = supplier_id;

    RETURN average;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION calculate_average_delivery_duration(
    supplier_id INT
)
RETURNS DOUBLE PRECISION
AS $$
DECLARE
    average DOUBLE PRECISION;
    count_all_deliveries INT;
BEGIN
    -- get total count of deliveries
    SELECT COUNT(*) INTO count_all_deliveries
    FROM view_purchases
    WHERE "Is Approved" = TRUE
        AND "Supplier Id" = supplier_id;

    -- get average delivery duration
    SELECT AVG(EXTRACT(DAY FROM ("Date Recieved" - "Purchase Date"))) INTO average
    FROM view_purchases
    WHERE "Is Approved" = TRUE
        AND "Supplier Id" = supplier_id;

    RETURN average;
END;
$$
LANGUAGE plpgsql;

-- VIEWS

CREATE OR REPLACE VIEW view_supplier_performance_report AS
SELECT 
    view_suppliers."Supplier Id" AS "Supplier Id",
    view_suppliers."Supplier Name" AS "Supplier Name",
    view_suppliers."Phone Number" AS "Phone Number",
    calculate_average_incomplete_deliveries(view_suppliers."Supplier Id") AS "Average Incomplete Deliveries",
    CASE
        WHEN calculate_average_incomplete_deliveries(view_suppliers."Supplier Id") IS NULL THEN 'TO BE DETERMINED'
        WHEN calculate_average_incomplete_deliveries(view_suppliers."Supplier Id") > 0.5 THEN 'POOR'
        WHEN calculate_average_incomplete_deliveries(view_suppliers."Supplier Id") > 0.3 THEN 'GOOD'
        ELSE 'EXCELLENT'
    END AS "Delivery Completeness",
    calculate_average_delivery_duration(view_suppliers."Supplier Id") AS "Average Delivery Duration",
    CASE
        WHEN calculate_average_delivery_duration(view_suppliers."Supplier Id") IS NULL THEN 'TO BE DETERMINED'
        WHEN calculate_average_delivery_duration(view_suppliers."Supplier Id") > 30 THEN 'POOR'
        WHEN calculate_average_delivery_duration(view_suppliers."Supplier Id") > 15 THEN 'GOOD'
        ELSE 'EXCELLENT'
    END AS "Delivery Duration"
FROM view_suppliers;

-- USERS

