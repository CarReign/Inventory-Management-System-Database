CREATE DATABASE inventory_man_system;
USE inventory_man_system;


DROP TABLE IF EXISTS stocks;
CREATE TABLE `stocks` (
  `product_id` INT NOT NULL,
  `quantity` int NOT NULL
  FOREIGN KEY (`category_id`) REFERENCES categories(`category_id`)
);

INSERT INTO `stocks` 
VALUES 
	('1',146),
	('2',100),
    ('3',202);


DROP TABLE IF EXISTS suppliers;
CREATE TABLE `suppliers` (
  `supplier_id` int NOT NULL AUTO_INCREMENT,
  `fullname` varchar(45) NOT NULL,
  `mobile_number` varchar(20) NOT NULL,
  PRIMARY KEY (`supplier_id`)
);

INSERT INTO `suppliers` 
VALUES 
	(1,'sup1','1800560001'),
    (2,'sup2','1800560041'),
    (3,'sup3','6546521234');


DROP TABLE IF EXISTS brands;
CREATE TABLE `brands` (
  `brand_id` int NOT NULL AUTO_INCREMENT,
  `brand_name` varchar(45) NOT NULL,
  PRIMARY KEY (`brand_id`)
);

INSERT INTO `brands` 
VALUES 
	(1,'brand1'),
    (2,'brand2'),
    (3,'brand3');


DROP TABLE IF EXISTS categories;
CREATE TABLE `categories` (
  `category_id` int NOT NULL AUTO_INCREMENT,
  `category_name` varchar(45) NOT NULL,
  PRIMARY KEY (`category_id`)
);

INSERT INTO `categories` 
VALUES 
	(1,'category1'),
    (2,'category2'),
    (3,'category3');
    

DROP TABLE IF EXISTS products;
CREATE TABLE `products` (
  `product_id` int NOT NULL AUTO_INCREMENT,
  `product_name` varchar(45) NOT NULL,
  `buy_price` DECIMAL(25,2) NOT NULL,
  `sell_price` DECIMAL(25,2) NOT NULL,
  `brand_id` INT NOT NULL,
  `category_id` INT NOT NULL,
  PRIMARY KEY (`product_id`),
  FOREIGN KEY (`brand_id`) REFERENCES brands(`brand_id`),
  FOREIGN KEY (`category_id`) REFERENCES categories(`category_id`)
);

INSERT INTO `products` 
VALUES 
	(1,'prod1',85000,90000,'1', '1'),
    (2,'prod2',70000,72000,'2', '1'),
    (3,'prod3',60000,64000,'3','1');


DROP TABLE IF EXISTS purchase_info;
CREATE TABLE `purchase_info` (
  `purchase_id` int NOT NULL AUTO_INCREMENT,
  `product_id` int NOT NULL,
  `supplier_id` int NOT NULL,
  `date` DATE NOT NULL,
  `quantity` int NOT NULL,
  `totalcost` DECIMAL(25,2) NOT NULL,
  PRIMARY KEY (`purchase_ID`),
  FOREIGN KEY (`product_id`) REFERENCES products(`product_id`),
  FOREIGN KEY (`supplier_id`) REFERENCES suppliers(`supplier_id`)
);

INSERT INTO `purchase_info` 
VALUES 
	(1,1,1,'2023-05-11',10,850000),
    (2,2,1,'2023-05-14',20,34000),
    (3,3,3,'2023-05-16',5,300000);


DROP TABLE IF EXISTS sales_info;
CREATE TABLE `sales_info` (
  `sales_id` int NOT NULL AUTO_INCREMENT,
  `date` DATE NOT NULL,
  `product_id` INT NOT NULL,
  `quantity` int NOT NULL,
  `revenue` DECIMAL(25,2) NOT NULL,
  PRIMARY KEY (`sales_id`),
  FOREIGN KEY (`product_id`) REFERENCES products(`product_id`)
);

INSERT INTO `sales_info` 
VALUES 
	(1,'2023-05-17','1',3,270000),
    (2,'2023-05-20','2',2,144000),
    (3,'2023-05-25','2',1,64000);


DROP TABLE IF EXISTS users;
CREATE TABLE `users` (
  `user_id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(45) NOT NULL,
  `moobile_number` varchar(20) NOT NULL,
  `username` varchar(20) NOT NULL,
  `password` varchar(200) NOT NULL,
  PRIMARY KEY (`user_id`)
);

INSERT INTO `users` 
VALUES 
	(1,'user1','9650786717','u1','user1'),
    (2,'user2','9660654785','u2','user2'),
    (3,'user3','9876543210','u3','user3'),
    (4,'user4','1122334455','u4','user4');




-- stored procedures


DELIMITER //

CREATE PROCEDURE add_new_product_purchase(
    IN product_name VARCHAR(45),
    IN buy_price DECIMAL(25, 2),
    IN sell_price DECIMAL(25, 2),
    IN brand_id INT,
    IN category_id INT,
    IN purchase_date DATE,
    IN purchase_quantity INT,
    IN purchase_totalcost DECIMAL(25, 2),
    IN supplier_id INT
)
BEGIN
    DECLARE product_id INT;
    
    -- Add product to products table
    INSERT INTO products (product_name, buy_price, sell_price, brand_id, category_id)
    VALUES (product_name, buy_price, sell_price, brand_id, category_id);
    
    -- Get the newly inserted product_id
    SET product_id = LAST_INSERT_ID();
    
    -- Add purchase details to purchase_info table
    INSERT INTO purchase_info (product_id, supplier_id, date, quantity, totalcost)
    VALUES (product_id, supplier_id, purchase_date, purchase_quantity, purchase_totalcost);
    
    -- Add new row to stocks table
    INSERT INTO stocks (product_id, quantity)
    VALUES (product_id, purchase_quantity);
END //

DELIMITER ;



DELIMITER //

CREATE PROCEDURE get_low_stock_products(IN minimum_quantity INT)
BEGIN
    SELECT p.product_id, p.product_name, s.quantity
    FROM products p
    INNER JOIN stocks s ON p.product_id = s.product_id
    WHERE s.quantity < minimum_quantity;
END //

DELIMITER ;


DELIMITER //

CREATE PROCEDURE get_product_sales()
BEGIN
  SELECT p.product_id, p.product_name, SUM(s.revenue) AS total_sales
  FROM products p
  INNER JOIN sales_info s ON p.product_id = s.product_id
  GROUP BY p.product_id, p.product_name;
  
END //
DELIMITER ;


-- triggers

DELIMITER //

CREATE TRIGGER update_buy_price_trigger
AFTER INSERT ON purchase_info
FOR EACH ROW
BEGIN
  DECLARE new_buy_price DECIMAL(25,2);
  
  SELECT NEW.totalcost / NEW.quantity INTO new_buy_price;
  
  UPDATE products
  SET buy_price = new_buy_price
  WHERE product_id = NEW.product_id
    AND EXISTS (
      SELECT *
      FROM purchase_info
      WHERE product_id = NEW.product_id
        AND supplier_id = NEW.supplier_id
        AND purchase_id <> NEW.purchase_id
    );
END //

DELIMITER ;



DELIMITER //

CREATE TRIGGER calculate_revenue_trigger
BEFORE INSERT ON sales_info
FOR EACH ROW
BEGIN
  DECLARE sell_price DECIMAL(25,2);
  DECLARE quantity INT;
  
  SELECT products.sell_price INTO sell_price
  FROM products
  WHERE products.product_id = NEW.product_id;
  
  SET quantity = NEW.quantity;
  SET NEW.revenue = sell_price * quantity;
END //

DELIMITER ;



DELIMITER //
CREATE TRIGGER reduce_stock_on_sales_insert
AFTER INSERT ON sales_info
FOR EACH ROW
BEGIN
    -- Reduce stock quantity when new sales record is inserted
    UPDATE stocks
    SET quantity = quantity - NEW.quantity
    WHERE product_id = NEW.product_id;
END //
DELIMITER ;



DELIMITER //
CREATE TRIGGER add_stock_on_purchase_insert
AFTER INSERT ON purchase_info
FOR EACH ROW
BEGIN
    -- Add stock quantity when new purchase record is inserted
    UPDATE stocks
    SET quantity = quantity + NEW.quantity
    WHERE product_id = NEW.product_id;
END //
DELIMITER ;



-- functions

DELIMITER //
CREATE FUNCTION check_product_availability(product_name VARCHAR(100))
RETURNS VARCHAR(50)
READS SQL DATA
BEGIN
    DECLARE available VARCHAR(50);
    DECLARE stock_quantity INT;
    SELECT s.quantity INTO stock_quantity
    FROM stocks s
    INNER JOIN products p ON s.product_id = p.product_id
    WHERE p.product_name = product_name;
    IF stock_quantity > 0 THEN
        SET available = 'Available';
    ELSE
        SET available = 'Out of Stock';
    END IF;
    RETURN available;
END //
DELIMITER ;


DELIMITER //
CREATE FUNCTION calculate_total_sales(start_date DATE, end_date DATE)
RETURNS DECIMAL(10, 2)
READS SQL DATA
BEGIN
    DECLARE total DECIMAL(10, 2);
    SELECT SUM(revenue) INTO total
    FROM sales_info
    WHERE `date` BETWEEN start_date AND end_date;
    
    IF total IS NULL THEN
        SET total = 0.00;
    END IF;
    
    RETURN total;
END //
DELIMITER ;


-- VIEWS

CREATE VIEW `view_product_details` AS
SELECT
    p.product_name,
    b.brand_name,
    c.category_name,
    p.sell_price,
    s.quantity
FROM
    products p
    JOIN brands b ON p.brand_id = b.brand_id
    JOIN categories c ON p.category_id = c.category_id
    JOIN stocks s ON p.product_id = s.product_id;


CREATE VIEW count_products_per_brand AS
SELECT
    b.brand_id,
    b.brand_name,
    COUNT(p.product_id) AS product_count
FROM
    brands b
    LEFT JOIN products p ON b.brand_id = p.brand_id
GROUP BY
    b.brand_id,
    b.brand_name;






-- users and roles



CREATE USER 'carren'@'localhost' IDENTIFIED BY 'CarrenMae05!';
CREATE ROLE 'it_administrator';
set default role 'it_administrator' to 'carren'@'localhost'; 
GRANT 'it_administrator' to 'carren'@'localhost'; 
grant CREATE USER ON *.* TO 'it_administrator'@'%'
GRANT SELECT, INSERT, UPDATE, DELETE ON inventory_man_system.users TO 'it_administrator'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON inventory_man_system.suppliers TO 'it_administrator'@'%';
-- to grant tom
GRANT CREATE USER, RELOAD, PROCESS, SHUTDOWN, GRANT OPTION ON *.* TO 'it_administrator'@'%';
GRANT SUPER, REPLICATION CLIENT, REPLICATION SLAVE ON *.* TO 'it_administrator'@'%';


CREATE USER 'mae'@'localhost' IDENTIFIED BY 'CarrenMae05!';
CREATE ROLE 'sales_manager';
set default role 'sales_manager' to 'mae'@'localhost'; 
GRANT SELECT, INSERT, UPDATE, DELETE ON inventory_man_system.sales_info TO 'sales_manager'@'%';
-- to check if granted tom
GRANT EXECUTE ON procedure inventory_man_system.get_product_sales TO 'sales_manager'@'%';
GRANT EXECUTE ON FUNCTION inventory_man_system.check_product_availability TO 'sales_manager'@'%';
GRANT EXECUTE ON FUNCTION inventory_man_system.calculate_total_sales TO 'sales_manager'@'%';


CREATE USER 'labrias'@'localhost' IDENTIFIED BY 'CarrenMae05!';
CREATE ROLE 'purchasing_manager';
set default role 'purchasing_manager' to 'labrias'@'localhost';
GRANT USAGE ON *.* TO `labrias`@`localhost`;
GRANT SELECT, INSERT, UPDATE, DELETE ON inventory_man_system.purchase_info TO 'purchasing_manager'@'%';
-- to check if granted tom
GRANT EXECUTE ON procedure inventory_man_system.add_new_product_with_purchase_and_quantity TO 'purchasing_manager'@'%';
GRANT EXECUTE ON procedure inventory_man_system.get_low_stock_products TO 'purchasing_manager'@'%';


CREATE USER 'yongco'@'localhost' IDENTIFIED BY 'CarrenMae05!';
CREATE ROLE 'inventory_manager';
set default role 'inventory_manager' to 'yongco'@'localhost'; 
-- grants for inventory_manager role
GRANT SELECT, INSERT, UPDATE, DELETE ON inventory_man_system.products TO 'inventory_manager'@'%';
GRANT SELECT, INSERT, UPDATE ON inventory_man_system.stocks TO 'inventory_manager'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON inventory_man_system.brands TO 'inventory_manager'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON inventory_man_system.categories TO 'inventory_manager'@'%';
GRANT SELECT ON inventory_man_system.count_products_per_brand TO 'inventory_manager'@'%';
GRANT SELECT ON inventory_man_system.view_product_details TO 'inventory_manager'@'%';


-- add tom
DELIMITER //

CREATE PROCEDURE add_sales(
  IN sales_date DATE,
  IN product_id INT,
  IN sales_quantity INT
  
)
BEGIN
  INSERT INTO sales_info (`date`, `product_id`, `quantity`)
  VALUES (sales_date, product_id, sales_quantity);
END //

DELIMITER ;

GRANT EXECUTE ON procedure inventory_man_system.add_sales TO 'sales_manager'@'%';


GRANT SELECT, INSERT, UPDATE, DELETE ON inventory_man_system.products TO 'yongco'@'localhost';
GRANT SELECT, INSERT, UPDATE ON inventory_man_system.stocks TO 'yongco'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON inventory_man_system.brands TO 'yongco'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON inventory_man_system.categories TO 'yongco'@'localhost';
GRANT SELECT ON inventory_man_system.count_products_per_brand TO 'yongco'@'localhost';
GRANT SELECT ON inventory_man_system.view_product_details TO 'yongco'@'localhost';

GRANT EXECUTE ON procedure inventory_man_system.add_new_product_with_purchase_and_quantity TO 'labrias'@'localhost';
GRANT EXECUTE ON procedure inventory_man_system.get_low_stock_products TO 'labrias'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON inventory_man_system.purchase_info TO 'labrias'@'localhost';

GRANT EXECUTE ON procedure inventory_man_system.get_product_sales TO 'mae'@'localhost';
GRANT EXECUTE ON FUNCTION inventory_man_system.check_product_availability TO 'mae'@'localhost';
GRANT EXECUTE ON FUNCTION inventory_man_system.calculate_total_sales TO 'mae'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON inventory_man_system.sales_info TO 'mae'@'localhost';
GRANT EXECUTE ON procedure inventory_man_system.add_sales TO 'mae'@'localhost';

GRANT CREATE USER, RELOAD, PROCESS, SHUTDOWN, GRANT OPTION ON *.* TO 'carren'@'localhost';
GRANT SUPER, REPLICATION CLIENT, REPLICATION SLAVE ON *.* TO 'carren'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON inventory_man_system.users TO 'carren'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON inventory_man_system.suppliers TO 'carren'@'localhost';

GRANT EXECUTE ON procedure inventory_man_system.add_new_product_with_purchase_and_quantity TO 'labrias'@'localhost';


DELIMITER //

CREATE PROCEDURE delete_user(
  IN user_id INT
)
BEGIN
  DELETE FROM users WHERE user_id = user_id;
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE update_user(
  IN user_id INT,
  IN new_name VARCHAR(45),
  IN new_mobile_number VARCHAR(20),
  IN new_username VARCHAR(20),
  IN new_password VARCHAR(200)
)
BEGIN
  UPDATE users
  SET name = new_name,
      moobile_number = new_mobile_number,
      username = new_username,
      password = new_password
  WHERE user_id = user_id;
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE insert_user(
  IN name VARCHAR(45),
  IN mobile_number VARCHAR(20),
  IN username VARCHAR(20),
  IN password VARCHAR(200)
)
BEGIN
  INSERT INTO users (name, moobile_number, username, password)
  VALUES (name, mobile_number, username, password);
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE insert_supplier(
  IN fullname VARCHAR(45),
  IN mobile_number VARCHAR(20)
)
BEGIN
  INSERT INTO suppliers (fullname, mobile_number) VALUES (fullname, mobile_number);
END //

DELIMITER ;



DELIMITER //

CREATE PROCEDURE delete_category(
  IN category_id INT
)
BEGIN
  DELETE FROM categories WHERE category_id = category_id;
END //

DELIMITER ;


DELIMITER //

CREATE PROCEDURE update_category(
  IN category_id INT,
  IN new_category_name VARCHAR(45)
)
BEGIN
  UPDATE categories SET category_name = new_category_name WHERE category_id = category_id;
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE insert_category(
  IN category_name VARCHAR(45)
)
BEGIN
  INSERT INTO categories (category_name) VALUES (category_name);
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE delete_brand(
  IN brand_id INT
)
BEGIN
  DELETE FROM brands WHERE brand_id = brand_id;
END //

DELIMITER ;


DELIMITER //

CREATE PROCEDURE update_brand(
  IN brand_id INT,
  IN new_brand_name VARCHAR(45)
)
BEGIN
  UPDATE brands SET brand_name = new_brand_name WHERE brand_id = brand_id;
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE insert_brand(
  IN brand_name VARCHAR(45)
)
BEGIN
  INSERT INTO brands (brand_name) VALUES (brand_name);
END //

DELIMITER ;
