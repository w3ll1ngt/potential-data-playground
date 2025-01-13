-- Создание схемы
CREATE SCHEMA IF NOT EXISTS ecommerce;
USE ecommerce;

-- Таблица пользователей
CREATE TABLE users (
    user_id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    registration_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    loyalty_status ENUM('Gold', 'Silver', 'Bronze') NOT NULL
);

-- Таблица товаров
CREATE TABLE products (
    product_id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    name VARCHAR(200) NOT NULL,
    description TEXT,
    category_id CHAR(36),
    price DECIMAL(10, 2) NOT NULL,
    stock_quantity INT NOT NULL CHECK (stock_quantity >= 0),
    creation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES product_categories(category_id)
);

-- Таблица категорий товаров
CREATE TABLE product_categories (
    category_id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    name VARCHAR(100) NOT NULL,
    parent_category_id CHAR(36),
    FOREIGN KEY (parent_category_id) REFERENCES product_categories(category_id)
);

-- Таблица заказов
CREATE TABLE orders (
    order_id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    user_id CHAR(36),
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(12, 2) NOT NULL,
    status ENUM('Pending', 'Completed', 'Cancelled') NOT NULL,
    delivery_date TIMESTAMP NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- Таблица деталей заказов
CREATE TABLE order_details (
    order_detail_id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    order_id CHAR(36),
    product_id CHAR(36),
    quantity INT NOT NULL CHECK (quantity > 0),
    price_per_unit DECIMAL(10, 2) NOT NULL,
    total_price DECIMAL(12, 2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);
