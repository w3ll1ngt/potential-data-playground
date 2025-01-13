-- Вставка категорий товаров
INSERT INTO ecommerce.product_categories (category_id, name) VALUES
    (gen_random_uuid(), 'Electronics'),
    (gen_random_uuid(), 'Home Appliances'),
    (gen_random_uuid(), 'Books'),
    (gen_random_uuid(), 'Clothing'),
    (gen_random_uuid(), 'Toys');

-- Вставка пользователей
INSERT INTO ecommerce.users (first_name, last_name, email, phone, loyalty_status) VALUES
    ('John', 'Doe', 'john.doe@example.com', '123-456-7890', 'Gold'),
    ('Jane', 'Smith', 'jane.smith@example.com', '234-567-8901', 'Silver'),
    ('Alice', 'Johnson', 'alice.johnson@example.com', '345-678-9012', 'Bronze'),
    ('Bob', 'Brown', 'bob.brown@example.com', '456-789-0123', 'Gold');

-- Вставка товаров
INSERT INTO ecommerce.products (name, description, category_id, price, stock_quantity) VALUES
    ('Laptop', 'High-performance laptop', (SELECT category_id FROM ecommerce.product_categories WHERE name = 'Electronics'), 1200.00, 50),
    ('Microwave', 'Compact microwave oven', (SELECT category_id FROM ecommerce.product_categories WHERE name = 'Home Appliances'), 150.00, 100),
    ('Novel', 'Bestselling novel', (SELECT category_id FROM ecommerce.product_categories WHERE name = 'Books'), 20.00, 200),
    ('T-Shirt', 'Comfortable cotton t-shirt', (SELECT category_id FROM ecommerce.product_categories WHERE name = 'Clothing'), 15.00, 500),
    ('Teddy Bear', 'Soft plush teddy bear', (SELECT category_id FROM ecommerce.product_categories WHERE name = 'Toys'), 25.00, 300);

-- Вставка заказов
INSERT INTO ecommerce.orders (user_id, total_amount, status, delivery_date) VALUES
    ((SELECT user_id FROM ecommerce.users WHERE email = 'john.doe@example.com'), 1250.00, 'Completed', NOW() + INTERVAL '3 days'),
    ((SELECT user_id FROM ecommerce.users WHERE email = 'jane.smith@example.com'), 200.00, 'Pending', NOW() + INTERVAL '5 days');

-- Вставка деталей заказов
INSERT INTO ecommerce.order_details (order_id, product_id, quantity, price_per_unit, total_price) VALUES
    ((SELECT order_id FROM ecommerce.orders WHERE total_amount = 1250.00),
     (SELECT product_id FROM ecommerce.products WHERE name = 'Laptop'), 1, 1200.00, 1200.00),
    ((SELECT order_id FROM ecommerce.orders WHERE total_amount = 200.00),
     (SELECT product_id FROM ecommerce.products WHERE name = 'Microwave'), 1, 150.00, 150.00);
