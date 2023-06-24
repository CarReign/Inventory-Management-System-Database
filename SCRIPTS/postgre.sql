CREATE TABLE stocks (
  product_id INT NOT NULL,
  quantity int NOT NULL
);

INSERT INTO stocks 
VALUES 
  (1, 146),
  (2, 100),
  (3, 202);


CREATE TABLE suppliers (
  supplier_id SERIAL PRIMARY KEY,
  fullname varchar(45) NOT NULL,
  mobile_number varchar(20) NOT NULL
);

INSERT INTO suppliers 
VALUES 
  (1,'sup1','1800560001'),
  (2,'sup2','1800560041'),
  (3,'sup3','6546521234');


CREATE TABLE brands (
  brand_id SERIAL PRIMARY KEY,
  brand_name varchar(45) NOT NULL
);

INSERT INTO brands 
VALUES 
  (1,'brand1'),
  (2,'brand2'),
  (3,'brand3');


CREATE TABLE categories (
  category_id SERIAL PRIMARY KEY,
  category_name varchar(45) NOT NULL
);

INSERT INTO categories 
VALUES 
  (1,'category1'),
  (2,'category2'),
  (3,'category3');


CREATE TABLE products (
  product_id SERIAL PRIMARY KEY,
  product_name varchar(45) NOT NULL,
  buy_price DECIMAL(25,2) NOT NULL,
  sell_price DECIMAL(25,2) NOT NULL,
  brand_id INT NOT NULL,
  category_id INT NOT NULL,
  FOREIGN KEY (brand_id) REFERENCES brands(brand_id),
  FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

INSERT INTO products 
VALUES 
  (1,'prod1',85000,90000,1,1),
  (2,'prod2',70000,72000,2,1),
  (3,'prod3',60000,64000,3,1);


CREATE TABLE purchase_info (
  purchase_id SERIAL PRIMARY KEY,
  product_id INT NOT NULL,
  supplier_id INT NOT NULL,
  date DATE NOT NULL,
  quantity int NOT NULL,
  totalcost DECIMAL(25,2) NOT NULL,
  FOREIGN KEY (product_id) REFERENCES products(product_id),
  FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
);

INSERT INTO purchase_info 
VALUES 
  (1,1,1,'2023-05-11',10,850000),
  (2,2,1,'2023-05-14',20,34000),
  (3,3,3,'2023-05-16',5,300000);


CREATE TABLE sales_info (
  sales_id SERIAL PRIMARY KEY,
  date DATE NOT NULL,
  product_id INT NOT NULL,
  quantity int NOT NULL,
  revenue DECIMAL(25,2) NOT NULL,
  FOREIGN KEY (product_id) REFERENCES products(product_id)
);

INSERT INTO sales_info 
VALUES 
  (1,'2023-05-17',1,3,270000),
  (2,'2023-05-20',2,2,144000),
  (3,'2023-05-25',2,1,64000);


CREATE TABLE users (
  user_id SERIAL PRIMARY KEY,
  name varchar(45) NOT NULL,
  mobile_number varchar(20) NOT NULL,
  username varchar(20) NOT NULL,
  password varchar(200) NOT NULL
);

INSERT INTO users 
VALUES 
  (1,'user1','9650786717','u1','user1'),
  (2,'user2','9660654785','u2','user2'),
  (3,'user3','9876543210','u3','user3'),
  (4,'user4','1122334455','u4','user4');


-- Stored Procedures

CREATE OR REPLACE PROCEDURE add_new_product_with_purchase_and_quantity(
    IN p_product_name VARCHAR(45),
    IN p_buy_price DECIMAL(25, 2),
    IN p_sell_price DECIMAL(25, 2),
    IN p_brand_name VARCHAR(45),
    IN p_category_name VARCHAR(45),
    IN p_supplier_id INT,
    IN p_date DATE,
    IN p_quantity INT,
    IN p_total_cost DECIMAL(25, 2)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_brand_id INT;
    v_category_id INT;
    v_product_id INT;
    v_current_stock INT;
BEGIN
    -- Get the brand ID
    SELECT brand_id INTO v_brand_id FROM brands WHERE brand_name = p_brand_name;

    -- Get the category ID
    SELECT category_id INTO v_category_id FROM categories WHERE category_name = p_category_name;

    -- Insert product details into the products table
    INSERT INTO products (product_name, buy_price, sell_price, brand_id, category_id)
    VALUES (p_product_name, p_buy_price, p_sell_price, v_brand_id, v_category_id)
    RETURNING product_id INTO v_product_id;

    -- Insert purchase details into the purchase_info table
    INSERT INTO purchase_info (product_id, supplier_id, date, quantity, totalcost)
    VALUES (v_product_id, p_supplier_id, p_date, p_quantity, p_total_cost);

    -- Update the quantity in the stocks table
    SELECT quantity INTO v_current_stock FROM stocks WHERE product_id = v_product_id;
    IF v_current_stock IS NOT NULL THEN
        UPDATE stocks SET quantity = v_current_stock + p_quantity WHERE product_id = v_product_id;
    ELSE
        INSERT INTO stocks (product_id, quantity) VALUES (v_product_id, p_quantity);
    END IF;
END;
$$;




-- Triggers

CREATE OR REPLACE FUNCTION update_buy_price_function()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE products
  SET buy_price = NEW.totalcost / NEW.quantity
  WHERE product_id = NEW.product_id
    AND EXISTS (
      SELECT *
      FROM purchase_info
      WHERE product_id = NEW.product_id
        AND supplier_id = NEW.supplier_id
        AND purchase_id <> NEW.purchase_id
    );
    
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_buy_price_trigger
AFTER INSERT ON purchase_info
FOR EACH ROW
EXECUTE FUNCTION update_buy_price_function();



CREATE OR REPLACE FUNCTION calculate_revenue_function()
RETURNS TRIGGER AS $$
DECLARE
  product_sell_price DECIMAL(25,2);
  quantity INT;
BEGIN
  SELECT sell_price FROM products WHERE product_id = NEW.product_id INTO product_sell_price;
  
  quantity := NEW.quantity;
  NEW.revenue := product_sell_price * quantity;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER calculate_revenue_trigger
BEFORE INSERT ON sales_info
FOR EACH ROW
EXECUTE FUNCTION calculate_revenue_function();





CREATE OR REPLACE FUNCTION reduce_stock_on_sales_insert()
RETURNS TRIGGER AS $$
BEGIN
    -- Reduce stock quantity when new sales record is inserted
    UPDATE stocks
    SET quantity = quantity - NEW.quantity
    WHERE product_id = NEW.product_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER reduce_stock_on_sales_insert
AFTER INSERT ON sales_info
FOR EACH ROW
EXECUTE FUNCTION reduce_stock_on_sales_insert();


CREATE OR REPLACE FUNCTION add_stock_on_purchase_insert()
RETURNS TRIGGER AS $$
BEGIN
    -- Add stock quantity when new purchase record is inserted
    UPDATE stocks
    SET quantity = quantity + NEW.quantity
    WHERE product_id = NEW.product_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER add_stock_on_purchase_insert
AFTER INSERT ON purchase_info
FOR EACH ROW
EXECUTE FUNCTION add_stock_on_purchase_insert();


-- Functions

CREATE OR REPLACE FUNCTION get_low_stock_products(minimum_quantity INT)
RETURNS TABLE (
    product_id INT,
    product_name VARCHAR(45),
    quantity INT
)
AS $$
BEGIN
    RETURN QUERY
    SELECT p.product_id, p.product_name, s.quantity
    FROM products p
    INNER JOIN stocks s ON p.product_id = s.product_id
    WHERE s.quantity < minimum_quantity;
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION get_product_sales()
RETURNS TABLE (product_id INT, product_name VARCHAR, total_sales DECIMAL(25, 2))
AS $$
BEGIN
  RETURN QUERY
  SELECT p.product_id, p.product_name, SUM(s.revenue) AS total_sales
  FROM products p
  INNER JOIN sales_info s ON p.product_id = s.product_id
  GROUP BY p.product_id, p.product_name;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION check_product_availability(product_name VARCHAR(100))
RETURNS VARCHAR(50) AS $$
DECLARE 
    available VARCHAR(50);
    stock_quantity INT;
BEGIN
    SELECT s.quantity INTO stock_quantity
    FROM stocks s
    INNER JOIN products p ON s.product_id = p.product_id
    WHERE p.product_name = check_product_availability.product_name; -- Qualify the column reference

    IF stock_quantity > 0 THEN
        available := 'Available';
    ELSE
        available := 'Out of Stock';
    END IF;

    RETURN available;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION calculate_total_sales(start_date DATE, end_date DATE)
RETURNS DECIMAL(10, 2) AS $$
DECLARE total DECIMAL(10, 2);
BEGIN
    SELECT SUM(revenue) INTO total
    FROM sales_info
    WHERE date BETWEEN start_date AND end_date;
    
    IF total IS NULL THEN
        total := 0.00;
    END IF;
    
    RETURN total;
END;
$$ LANGUAGE plpgsql;


-- Views


CREATE OR REPLACE VIEW view_product_details AS
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


CREATE OR REPLACE VIEW count_products_per_brand AS
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




--users and roles


CREATE USER carren WITH PASSWORD 'carren';
CREATE ROLE it_administrator;
GRANT it_administrator TO carren;
GRANT SELECT, INSERT, UPDATE, DELETE ON users TO it_administrator;
GRANT SELECT, INSERT, UPDATE, DELETE ON suppliers TO it_administrator;

-- to grant tom



CREATE USER mae WITH PASSWORD 'mae';
CREATE ROLE sales_manager;
GRANT sales_manager TO mae;
-- to grant tom
GRANT SELECT, INSERT, UPDATE, DELETE ON sales_info TO sales_manager;
GRANT EXECUTE ON function get_product_sales TO sales_manager;
GRANT EXECUTE ON FUNCTION check_product_availability TO sales_manager;
GRANT EXECUTE ON FUNCTION calculate_total_sales TO sales_manager;


CREATE USER labrias WITH PASSWORD 'labrias';
CREATE ROLE purchasing_manager;
GRANT purchasing_manager TO labrias;
GRANT SELECT, INSERT, UPDATE, DELETE ON purchase_info TO purchasing_manager;
GRANT EXECUTE ON procedure add_new_product_with_purchase_and_stock_details TO purchasing_manager;
GRANT EXECUTE ON function get_low_stock_products TO purchasing_manager;


CREATE USER yongco WITH PASSWORD 'yongco';
CREATE ROLE inventory_manager;
GRANT inventory_manager TO yongco;
GRANT SELECT, INSERT, UPDATE, DELETE ON products TO inventory_manager;
GRANT SELECT, INSERT, UPDATE ON stocks TO inventory_manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON brands TO inventory_manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON categories TO inventory_manager;
GRANT SELECT ON count_products_per_brand TO inventory_manager;
GRANT SELECT ON view_product_details TO inventory_manager;

-- to add
CREATE OR REPLACE PROCEDURE add_sales(
  IN sales_date DATE,
  IN product_id INT,
  IN sales_quantity INT
)
AS $$
BEGIN
  INSERT INTO sales_info ("date", "product_id", "quantity")
  VALUES (sales_date, product_id, sales_quantity);
END;
$$ LANGUAGE plpgsql;

CALL add_sales('2023-06-14', 1, 10);

GRANT EXECUTE ON procedure add_sales TO sales_manager;