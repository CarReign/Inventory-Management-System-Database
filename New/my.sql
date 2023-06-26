CREATE SCHEMA IF NOT EXISTS `inventory_system`;
USE `inventory_system`;

-- -------------------------  TABLES  ------------------------- --

DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS suppliers;
DROP TABLE IF EXISTS stocks;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS purchase_info;

CREATE TABLE IF NOT EXISTS categories (
    category_id INT NOT NULL AUTO_INCREMENT,
    category_name VARCHAR(50) NOT NULL,
    category_description VARCHAR(255) NOT NULL,
    PRIMARY KEY (category_id),
    UNIQUE (category_name)
);

CREATE TABLE IF NOT EXISTS suppliers (
    supplier_id INT NOT NULL AUTO_INCREMENT,
    supplier_name VARCHAR(50) NOT NULL,
    phone_number VARCHAR(11) NOT NULL,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS products (
    product_id INT NOT NULL AUTO_INCREMENT,
    category_id INT NOT NULL,
    product_name VARCHAR(50) NOT NULL,
    product_description VARCHAR(255) NOT NULL,
    PRIMARY KEY (product_id, category_id),
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

CREATE TABLE purchase_info (
    purchase_id INT NOT NULL AUTO_INCREMENT,
    product_id INT NOT NULL,
    supplier_id INT NOT NULL,
    purchase_date DATE NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    ordered_quantity INT NOT NULL,
    is_approved BOOLEAN NOT NULL DEFAULT FALSE,
    status VARCHAR(10) NOT NULL CHECK(status IN ('PENDING', 'COMPLETE', 'INCOMPLETE')) DEFAULT 'PENDING',
     -- (PENDING, COMPLETE, INCOMPLETE)
    PRIMARY KEY (purchase_id, product_id, supplier_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
);

CREATE TABLE IF NOT EXISTS stocks (
    stock_id INT NOT NULL AUTO_INCREMENT,
    purchase_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity_recieved INT NOT NULL,
    buy_price DOUBLE PRECISION NOT NULL,
    total_cost DOUBLE PRECISION NOT NULL,
    date_recieved DATE NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    expiration_date DATE ,
    PRIMARY KEY (stock_id, purchase_id, product_id),
    FOREIGN KEY (purchase_id) REFERENCES purchase_info(purchase_id),
    FOREIGN KEY (product_id) REFERENCES purchase_info(product_id)
);

-- -------------------------  VIEWS  ------------------------- --

CREATE OR REPLACE VIEW view_stocks 
AS SELECT 
    stocks.quantity AS `Stock Quantity`, 
    stocks.expiration_date AS `Stock Expiration Date`, 
    stocks.sell_price AS `Stock Selling Price`, 
    stocks.buy_price AS `Stock Buying Price`, 
    products.product_name AS `Product`,
    products.product_description AS `Product Description`,
    categories.category_name AS `Category`,
    categories.category_description AS `Category Description`,
    stocks.stock_id, 
    stocks.purchase_id, 
    stocks.product_id
FROM stocks
INNER JOIN products ON stocks.product_id = products.product_id
INNER JOIN categories ON products.category_id = categories.category_id;

CREATE OR REPLACE VIEW view_old_stocks
AS SELECT
    stocks.quantity AS `Stock Quantity`,
    stocks.expiration_date AS `Stock Expiration Date`,
    stocks.sell_price AS `Stock Selling Price`,
    stocks.buy_price AS `Stock Buying Price`,
    products.product_name AS `Product`,
    products.product_description AS `Product Description`,
    categories.category_name AS `Category`,
    categories.category_description AS `Category Description`,
    stocks.stock_id,
    stocks.purchase_id,
    stocks.product_id
FROM stocks
INNER JOIN products ON stocks.product_id = products.product_id
INNER JOIN categories ON products.category_id = categories.category_id
WHERE stocks.expiration_date < CURRENT_DATE;

CREATE OR REPLACE VIEW view_purchases
AS SELECT
    purchase_info.purchase_id AS `Purchase No`,
    purchase_info.product_id AS `Product ID`,
    purchase_info.supplier_id AS `Supplier ID`,
    purchase_info.purchase_date AS `Purchase Date`,
    purchase_info.ordered_quantity AS `Ordered Quantity`,
    purchase_info.is_approved AS `Is Approved`,
    purchase_info.status AS `Status`,
    products.product_name AS `Product`,
    products.product_description AS `Product Description`,
    categories.category_name AS `Category`,
    categories.category_description AS `Category Description`
FROM purchase_info
INNER JOIN products ON purchase_info.product_id = products.product_id
INNER JOIN categories ON products.category_id = categories.category_id;

CREATE OR REPLACE VIEW view_suppliers
AS SELECT 
    suppliers.supplier_id AS `Supplier ID`,
    suppliers.supplier_name AS `Supplier Name`,
    suppliers.phone_number AS `Phone Number`
FROM suppliers
INNER JOIN products ON suppliers.supplier_id = products.supplier_id
INNER JOIN categories ON products.category_id = categories.category_id
GROUP BY suppliers.supplier_id;

-- -------------------------  TRIGGERS  ------------------------- --

DROP TRIGGER IF EXISTS check_quantity;

DELIMITER //
CREATE TRIGGER IF NOT EXISTS check_quantity
-- check if the ordered quantity maches the quantity recieved
AFTER INSERT ON stocks
FOR EACH ROW
BEGIN
    IF (SELECT ordered_quantity FROM purchase_info WHERE purchase_id = NEW.purchase_id) != (SELECT quantity_recieved FROM stocks WHERE purchase_id = NEW.purchase_id) THEN
        UPDATE purchase_info SET status = 'INCOMPLETE' WHERE purchase_id = NEW.purchase_id;
    ELSE
        UPDATE purchase_info SET status = 'COMPLETE' WHERE purchase_id = NEW.purchase_id;
    END IF;
END //
DELIMITER ;

-- -------------------------  PROCEDURES  ------------------------- --

DROP PROCEDURE IF EXISTS add_category; -- done
DROP PROCEDURE IF EXISTS approve_purchase; -- done
DROP PROCEDURE IF EXISTS add_product; -- done
DROP PROCEDURE IF EXISTS add_supplier; -- done
DROP PROCEDURE IF EXISTS update_supplier; -- done
DROP PROCEDURE IF EXISTS add_purchase_product; -- done
DROP PROCEDURE IF EXISTS add_stock_details; -- 

DELIMITER //
CREATE PROCEDURE IF NOT EXISTS add_category(
    IN category_name VARCHAR(50),
    IN category_description VARCHAR(255)
)
BEGIN
    INSERT INTO categories(category_name, category_description)
    VALUES (category_name, category_description);
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE IF NOT EXISTS approve_purchase(
    IN purchase_id INT,
    IN product_id INT,
    IN supplier_id INT,
)
BEGIN
    -- check products and supplier exists
    IF (SELECT COUNT(*) FROM products WHERE product_id = product_id) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Product does not exist';
    END IF;

    IF (SELECT COUNT(*) FROM suppliers WHERE supplier_id = supplier_id) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Supplier does not exist';
    END IF;
    

    -- check if purchase is already approved
    IF (SELECT is_approved FROM purchase_info WHERE purchase_id = purchase_id AND product_id = product_id AND supplier_id = supplier_id) = TRUE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Purchase already approved';
    END IF;

    -- update
    UPDATE purchase_info
    SET is_approved = TRUE
    WHERE purchase_id = purchase_id AND product_id = product_id AND supplier_id = supplier_id;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE IF NOT EXISTS add_product(
    IN category_name INT,
    IN product_name VARCHAR(50),
    IN product_description VARCHAR(255)
)
BEGIN
    DECLARE category_id INT;

    -- check if category name exists
    IF (SELECT COUNT(*) FROM categories WHERE category_id = category_id) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Category does not exist';
    END IF;

    -- check if product name exists
    IF (SELECT COUNT(*) FROM products WHERE product_name = product_name) > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Product already exists';
    END IF;

    -- get category id
    SET category_id = (SELECT category_id FROM categories WHERE category_name = category_name);

    -- insert
    INSERT INTO products(category_id, product_name, product_description)

END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE IF NOT EXISTS add_supplier(
    IN supplier_name VARCHAR(50),
    IN phone_number VARCHAR(50)
)
BEGIN
    -- check if supplier name exists
    IF (SELECT COUNT(*) FROM view_suppliers WHERE view_suppliers.`Supplier Name` = supplier_name) > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Supplier already exists';
    END IF;

    -- insert
    INSERT INTO suppliers(supplier_name, phone_number)
    VALUES (supplier_name, phone_number);
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE IF NOT EXISTS update_supplier(
    IN supplier_id INT,
    IN supplier_name VARCHAR(50),
    IN phone_number VARCHAR(50)
)
BEGIN
    -- check if supplier id exists
    IF (SELECT COUNT(*) FROM view_suppliers WHERE view_suppliers.`Supplier Id` = supplier_id) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Supplier does not exist';
    END IF;

    -- update
    UPDATE suppliers
    SET supplier_name = supplier_name, phone_number = phone_number
    WHERE supplier_id = supplier_id;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE IF NOT EXISTS add_purchase_product(
    IN product_id INT,
    IN supplier_id INT,
    IN ordered_quantity INT,
    IN purchase_date DATE
)
BEGIN
    DECLARE final_purchase_date DATE;

    -- check if product id exists
    IF (SELECT COUNT(*) FROM products WHERE product_id = product_id) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Product does not exist';
    END IF;

    -- check if supplier id exists
    IF (SELECT COUNT(*) FROM view_suppliers WHERE view_suppliers.`Supplier Id` = supplier_id) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Supplier does not exist';
    END IF;

    -- if purchase date is null, set to current date
    IF purchase_date IS NULL THEN
        SET final_purchase_date = CURRENT_DATE;
    ELSE
        SET final_purchase_date = purchase_date;
    END IF;

    -- insert
    INSERT INTO purchase_info(product_id, supplier_id, ordered_quantity, purchase_date)
    VALUES (product_id, supplier_id, ordered_quantity, final_purchase_date);
END //
DELIMITER ;


DELIMITER //
CREATE PROCEDURE IF NOT EXISTS add_stock_details(
    IN product_id INT,
    IN purchase_id INT,
    IN quantity_recieved INT,
    IN buy_price DOUBLE PRECISION,
    IN total_cost DOUBLE PRECISION,
    IN expiration_date DATE,
    IN date_recieved DATE
)
BEGIN
    -- check if purchase id exists
    IF (SELECT COUNT(*) FROM view_purchases WHERE view_purchases.`Purchase Id` = purchase_id 
        AND view_purchases.`Product Id` = product_id AND view_purchases.`Supplier Id` = supplier_id
        AND view_purchases.`Supplier Id` = supplier_id) = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Purchase does not exist';
    END IF;

    -- check if product id exists
    IF (SELECT COUNT(*) FROM products WHERE product_id = product_id) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Product does not exist';
    END IF;

    -- insert into stock
    INSERT INTO stock(product_id, purchase_id, quantity_recieved, buy_price, total_cost, expiration_date, date_recieved)
    VALUES (product_id, purchase_id, quantity_recieved, buy_price, total_cost, expiration_date, date_recieved);
END //

-- -------------------------  FUNCTIONS  ------------------------- --

DROP FUNCTION IF EXISTS calculate_average_incomplete_deliveries; 
DROP FUNCTION IF EXISTS calculate_average_delivery_duration;

DELIMITER //
CREATE FUNCTION IF NOT EXISTS calculate_average_incomplete_deliveries(
    IN supplier_id INT
)
RETURNS DOUBLE PRECISION NOT DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE count_all_deliveries INT;
    DECLARE count_incomplete_deliveries INT;
    DECLARE average DOUBLE PRECISION;

    -- get count of all deliveries
    SET count_all_deliveries = (SELECT COUNT(*) FROM view_purchases WHERE view_purchases.`Is Approved` = TRUE
        AND view_purchases.`Supplier Id` = supplier_id);
    -- get count of all incomplete deliveries
    SET count_incomplete_deliveries = (SELECT COUNT(*) FROM view_purchases WHERE view_purchases.`Is Approved` = FALSE
        AND view_purchases.`Supplier Id` = supplier_id);

    -- calculate average
    SET average = count_incomplete_deliveries / count_all_deliveries;

    -- check if suppliers has any deliveries
    IF count_all_deliveries = 0 THEN
        SET average = 1;
    END IF;

    RETURN average;
END //
DELIMITER ;

DELIMITER //
CREATE FUNCTION IF NOT EXISTS calculate_average_delivery_duration(
    IN supplier_id INT
)
RETURNS DOUBLE PRECISION NOT DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE average DOUBLE PRECISION;

    -- get total count of deliveries
    SET count_all_deliveries = (SELECT COUNT(*) FROM view_purchases WHERE view_purchases.`Is Approved` = TRUE
        AND view_purchases.`Supplier Id` = supplier_id);

    -- get average delivery duration
    SET average = (SELECT AVG(DATEDIFF(view_purchases.`Date Recieved`, view_purchases.`Purchase Date`)) FROM view_purchases
        WHERE view_purchases.`Is Approved` = TRUE AND view_purchases.`Supplier Id` = supplier_id);
    
    RETURN average;
END //

-- -------------------------  VIEW  ------------------------- --

CREATE OR REPLACE VIEW view_supplier_performance_report
AS
SELECT 
    view_suppliers.`Supplier Id` AS `Supplier Id`,
    view_suppliers.`Supplier Name` AS `Supplier Name`,
    view_suppliers.`Phone Number` AS `Phone Number`,
    calculate_average_incomplete_deliveries(view_suppliers.`Supplier Id`) AS `Average Incomplete Deliveries`,
    CASE
        WHEN calculate_average_incomplete_deliveries(view_suppliers.`Supplier Id`) IS NULL THEN 'TO BE DETERMINED'
        WHEN calculate_average_incomplete_deliveries(view_suppliers.`Supplier Id`) > 0.5 THEN 'POOR'
        WHEN calculate_average_incomplete_deliveries(view_suppliers.`Supplier Id`) > 0.3 THEN 'GOOD'
        ELSE 'EXCELLENT'
    END AS `Delivery Completeness`,
    calculate_average_delivery_duration(view_suppliers.`Supplier Id`) AS `Average Delivery Duration`,
    CASE
        WHEN calculate_average_delivery_duration(view_suppliers.`Supplier Id`) IS NULL THEN 'TO BE DETERMINED'
        WHEN calculate_average_delivery_duration(view_suppliers.`Supplier Id`) > 30 THEN 'POOR'
        WHEN calculate_average_delivery_duration(view_suppliers.`Supplier Id`) > 15 THEN 'GOOD'
        ELSE 'EXCELLENT'
    END AS `Delivery Duration`
FROM view_suppliers;

-- -------------------------  USER  ------------------------- --

DROP ROLE IF EXISTS 'inventory manager';
DROP ROLE IF EXISTS 'inventory custodian';
DROP ROLE IF EXISTS 'inventory auditor';
DROP USER IF EXISTS 'Carren'@'%' IDENTIFIED BY 'CarrenMaeYongco0!';
DROP USER IF EXISTS 'Nina'@'%' IDENTIFIED BY 'NinaSebial0!';
DROP USER IF EXISTS 'Zaki'@'%' IDENTIFIED BY 'ZakiSarmiento0!';

GRANT SELECT, INSERT, UPDATE ON inventory_system.`suppliers` TO 'inventory manager';
GRANT UPDATE TO inventory_system.`purchase_info` TO 'inventory manager';
GRANT SELECT, INSERT ON inventory_system.`categories` TO 'inventory manager';
GRANT SELECT, INSERT ON inventory_system.`products` TO 'inventory manager';

GRANT SELECT ON inventory_system.`suppliers` TO 'inventory custodian';
GRANT SELECT, INSERT ON inventory_system.`purchase_info` TO 'inventory custodian';
GRANT SELECT, INSERT, UPDATE ON inventory_system.`stock` TO 'inventory custodian';

GRANT SELECT ON inventory_system.`suppliers` TO 'inventory auditor';