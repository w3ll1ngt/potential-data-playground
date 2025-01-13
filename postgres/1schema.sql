-- Создание схемы
CREATE SCHEMA IF NOT EXISTS ecommerce;

-- Таблица пользователей
CREATE TABLE ecommerce.users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    registration_date TIMESTAMP DEFAULT NOW(),
    loyalty_status VARCHAR(20) CHECK (loyalty_status IN ('Gold', 'Silver', 'Bronze'))
);

-- Таблица товаров
CREATE TABLE ecommerce.products (
    product_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    description TEXT,
    category_id UUID,
    price NUMERIC(10, 2) NOT NULL,
    stock_quantity INT NOT NULL CHECK (stock_quantity >= 0),
    creation_date TIMESTAMP DEFAULT NOW()
);

-- Таблица категорий товаров
CREATE TABLE ecommerce.product_categories (
    category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    parent_category_id UUID REFERENCES ecommerce.product_categories(category_id)
);

-- Таблица заказов
CREATE TABLE ecommerce.orders (
    order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES ecommerce.users(user_id),
    order_date TIMESTAMP DEFAULT NOW(),
    total_amount NUMERIC(12, 2) NOT NULL,
    status VARCHAR(20) CHECK (status IN ('Pending', 'Completed', 'Cancelled')),
    delivery_date TIMESTAMP
);

-- Таблица деталей заказов
CREATE TABLE ecommerce.order_details (
    order_detail_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES ecommerce.orders(order_id),
    product_id UUID REFERENCES ecommerce.products(product_id),
    quantity INT NOT NULL CHECK (quantity > 0),
    price_per_unit NUMERIC(10, 2) NOT NULL,
    total_price NUMERIC(12, 2) NOT NULL
);
