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
    product_category_id INT NOT NULL,
    product_name VARCHAR(50) NOT NULL,
    product_description VARCHAR(255) NOT NULL,
    PRIMARY KEY (product_id),
    FOREIGN KEY (product_category_id) REFERENCES categories(category_id)
);

CREATE TABLE purchase_info (
    purchase_no INT NOT NULL AUTO_INCREMENT,
    product_id INT NOT NULL,
    supplier_id INT NOT NULL,
    purchase_date DATE NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    ordered_quantity INT NOT NULL,
    PRIMARY KEY (purchase_no),
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
);

CREATE TABLE IF NOT EXISTS stocks (
    stock_id INT NOT NULL AUTO_INCREMENT,
    purchase_no INT NOT NULL,
    product_id INT NOT NULL,
    quantity_received INT NOT NULL,
    buy_price DOUBLE PRECISION NOT NULL,
    total_cost DOUBLE PRECISION NOT NULL,
    expiration_date DATE NOT NULL,
    date_received DATE NOT NULL DEFAULT (CURRENT_TIMESTAMP),
    PRIMARY KEY (stock_id)
);

-- -------------------------  VIEWS  ------------------------- --

CREATE VIEW IF NOT EXISTS view_stocks AS
SELECT
    stocks.quantity_received AS `Quantity Received`,
    stocks.buy_price AS `Buy Price`,
    stocks.total_cost AS `Total Cost`,
    stocks.expiration_date AS `Expiration Date`,
    stocks.date_received AS `Date Received`,
    products.product_name AS `Product`,
    products.product_description AS `Product Description`,
    categories.category_name AS `Category`,
    categories.category_description AS `Category Description`,
    stocks.stock_id AS `Stock Id`,
    stocks.purchase_no AS `Purchase #`,
    stocks.product_id AS `Product Id`,
FROM stocks
INNER JOIN products ON stocks.product_id = products.product_id
INNER JOIN categories ON products.product_category_id = categories.category_id;

-- -------------------------  TRIGGERS  ------------------------- --

-- -------------------------  PROCEDURES  ------------------------- --

-- -------------------------  FUNCTIONS  ------------------------- --


-- -------------------------  USERS  ------------------------- --
CREATE ROLE 'Inventory Manager';
CREATE ROLE 'Inventory Auditor';

CREATE USER 'CarrenMaeYongco'@'%' IDENTIFIED BY 'CarrenMaeYongco1!';
CREATE USER 'NinaRoseSebial'@'%' IDENTIFIED BY 'NinaRoseSebial1!';