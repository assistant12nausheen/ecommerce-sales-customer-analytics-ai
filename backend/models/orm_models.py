"""
backend/models/orm_models.py

SQLAlchemy ORM models matching the MySQL database schema.
"""

from sqlalchemy import (
    Column,
    String,
    Integer,
    SmallInteger,
    DECIMAL,
    DateTime,
    Boolean,
    Text,
    ForeignKey,
)
from sqlalchemy.orm import relationship

from backend.database import Base


TinyInteger = SmallInteger


class Customer(Base):
    __tablename__ = "customers"

    customer_id = Column(String(36), primary_key=True)
    customer_unique_id = Column(String(36), nullable=False, index=True)
    customer_zip_code_prefix = Column(String(5), nullable=False)
    customer_city = Column(String(100), nullable=False)
    customer_state = Column(String(2), nullable=False, index=True)

    orders = relationship("Order", back_populates="customer")


class Product(Base):
    __tablename__ = "products"

    product_id = Column(String(36), primary_key=True)
    product_category_name = Column(String(100))
    product_category_name_english = Column(String(100), index=True)
    product_name_lenght = Column(SmallInteger)
    product_description_lenght = Column(Integer)
    product_photos_qty = Column(TinyInteger)
    product_weight_g = Column(DECIMAL(8, 2))
    product_length_cm = Column(DECIMAL(6, 2))
    product_height_cm = Column(DECIMAL(6, 2))
    product_width_cm = Column(DECIMAL(6, 2))
    is_incomplete = Column(Boolean, default=False)

    order_items = relationship("OrderItem", back_populates="product")


class Seller(Base):
    __tablename__ = "sellers"

    seller_id = Column(String(36), primary_key=True)
    seller_zip_code_prefix = Column(String(5), nullable=False)
    seller_city = Column(String(100), nullable=False)
    seller_state = Column(String(2), nullable=False, index=True)

    order_items = relationship("OrderItem", back_populates="seller")


class Order(Base):
    __tablename__ = "orders"

    order_id = Column(String(36), primary_key=True)
    customer_id = Column(
        String(36),
        ForeignKey("customers.customer_id"),
        nullable=False,
        index=True,
    )
    order_status = Column(String(20), nullable=False, index=True)
    order_purchase_timestamp = Column(DateTime, nullable=False, index=True)
    order_approved_at = Column(DateTime)
    order_delivered_carrier_date = Column(DateTime)
    order_delivered_customer_date = Column(DateTime)
    order_estimated_delivery_date = Column(DateTime, nullable=False)

    purchase_year = Column(SmallInteger)
    purchase_month = Column(TinyInteger)
    purchase_day = Column(TinyInteger)
    purchase_weekday = Column(TinyInteger)
    purchase_hour = Column(TinyInteger)
    year_month = Column(String(7), index=True)
    delivery_duration_days = Column(DECIMAL(6, 1))
    estimated_delivery_days = Column(DECIMAL(6, 1))
    delivery_delay_days = Column(DECIMAL(6, 1))
    is_late = Column(Boolean)
    carrier_handling_days = Column(DECIMAL(6, 1))

    customer = relationship("Customer", back_populates="orders")

    order_items = relationship(
        "OrderItem",
        back_populates="order",
        cascade="all, delete-orphan",
    )

    payments = relationship(
        "Payment",
        back_populates="order",
        cascade="all, delete-orphan",
    )

    reviews = relationship(
        "Review",
        back_populates="order",
        cascade="all, delete-orphan",
    )


class OrderItem(Base):
    __tablename__ = "order_items"

    order_id = Column(
        String(36),
        ForeignKey("orders.order_id"),
        primary_key=True,
    )
    order_item_id = Column(TinyInteger, primary_key=True)

    product_id = Column(
        String(36),
        ForeignKey("products.product_id"),
        nullable=False,
        index=True,
    )

    seller_id = Column(
        String(36),
        ForeignKey("sellers.seller_id"),
        nullable=False,
        index=True,
    )

    shipping_limit_date = Column(DateTime)
    price = Column(DECIMAL(10, 2), nullable=False)
    freight_value = Column(DECIMAL(10, 2), nullable=False)

    order = relationship("Order", back_populates="order_items")
    product = relationship("Product", back_populates="order_items")
    seller = relationship("Seller", back_populates="order_items")


class Payment(Base):
    __tablename__ = "payments"

    order_id = Column(
        String(36),
        ForeignKey("orders.order_id"),
        primary_key=True,
    )
    payment_sequential = Column(TinyInteger, primary_key=True)
    payment_type = Column(String(20), nullable=False, index=True)
    payment_installments = Column(TinyInteger, nullable=False)
    payment_value = Column(DECIMAL(10, 2), nullable=False)

    order = relationship("Order", back_populates="payments")


class Review(Base):
    __tablename__ = "reviews"

    review_pk = Column(
        Integer,
        primary_key=True,
        autoincrement=True,
    )

    review_id = Column(
        String(36),
        nullable=False,
        index=True,
    )

    order_id = Column(
        String(36),
        ForeignKey("orders.order_id"),
        nullable=False,
        index=True,
    )

    review_score = Column(
        TinyInteger,
        nullable=False,
        index=True,
    )

    review_comment_title = Column(String(255))
    review_comment_message = Column(Text)
    review_creation_date = Column(DateTime)
    review_answer_timestamp = Column(DateTime)

    order = relationship("Order", back_populates="reviews")