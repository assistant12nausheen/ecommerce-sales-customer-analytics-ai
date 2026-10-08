"""
backend/schemas/response_schemas.py
-------------------------------------
Pydantic response models for every API endpoint.
FastAPI uses these to validate and serialise what the routers return.
"""

from __future__ import annotations
from typing import Any, Dict, List, Optional
from pydantic import BaseModel


# ---------------------------------------------------------------------------
# Shared
# ---------------------------------------------------------------------------

class StatusResponse(BaseModel):
    status: str
    database_connected: bool
    message: str


# ---------------------------------------------------------------------------
# KPI Dashboard
# ---------------------------------------------------------------------------

class KpiCard(BaseModel):
    label: str
    value: Any
    unit: Optional[str] = None


class DashboardKpis(BaseModel):
    total_orders: int
    total_revenue: float
    avg_order_value: float
    median_order_value: float
    total_customers: int
    total_products: int
    total_sellers: int
    avg_review_score: float
    avg_delivery_days: float
    late_delivery_pct: float


# ---------------------------------------------------------------------------
# Sales Trends
# ---------------------------------------------------------------------------

class MonthlySalesRow(BaseModel):
    year_month: str
    order_count: int
    revenue: float
    avg_order_value: float
    avg_review_score: Optional[float]
    avg_delivery_days: Optional[float]
    late_order_count: Optional[int]


class MonthlySalesResponse(BaseModel):
    data: List[MonthlySalesRow]
    total_months: int


# ---------------------------------------------------------------------------
# Category Performance
# ---------------------------------------------------------------------------

class CategoryRow(BaseModel):
    category: str
    orders: int
    revenue: float
    units_sold: int
    avg_price: float
    avg_review_score: Optional[float]


class CategoryResponse(BaseModel):
    data: List[CategoryRow]


# ---------------------------------------------------------------------------
# Customer Analytics
# ---------------------------------------------------------------------------

class StateRow(BaseModel):
    state: str
    order_count: int
    revenue: float
    unique_customers: int


class CustomerStatsResponse(BaseModel):
    total_customers: int
    repeat_customer_pct: float
    avg_spend: float
    median_spend: float
    by_state: List[StateRow]


# ---------------------------------------------------------------------------
# Payment Analysis
# ---------------------------------------------------------------------------

class PaymentTypeRow(BaseModel):
    payment_type: str
    order_count: int
    total_paid: float
    avg_payment: float
    pct_of_orders: float


class InstallmentRow(BaseModel):
    installments: int
    count: int
    pct: float


class PaymentResponse(BaseModel):
    by_type: List[PaymentTypeRow]
    cc_installments: List[InstallmentRow]
    credit_card_pct: float
    avg_installments_cc: float


# ---------------------------------------------------------------------------
# Review Analysis
# ---------------------------------------------------------------------------

class ReviewScoreRow(BaseModel):
    score: int
    count: int
    pct: float


class ReviewResponse(BaseModel):
    avg_score: float
    five_star_pct: float
    negative_pct: float
    by_score: List[ReviewScoreRow]


# ---------------------------------------------------------------------------
# Delivery Analysis
# ---------------------------------------------------------------------------

class DeliveryStatsResponse(BaseModel):
    avg_delivery_days: float
    median_delivery_days: float
    late_pct: float
    avg_delay_days: float
    on_time_pct: float


class DeliveryByMonthRow(BaseModel):
    year_month: str
    avg_delivery_days: float
    late_pct: float


class DeliveryResponse(BaseModel):
    summary: DeliveryStatsResponse
    by_month: List[DeliveryByMonthRow]


# ---------------------------------------------------------------------------
# Customer Segmentation
# ---------------------------------------------------------------------------

class SegmentRow(BaseModel):
    segment: str
    customer_count: int
    pct_of_total: float
    avg_recency_days: float
    avg_frequency: float
    avg_monetary: float


class SegmentationResponse(BaseModel):
    segments: List[SegmentRow]
    total_customers: int
    method: str


# ---------------------------------------------------------------------------
# Forecasting
# ---------------------------------------------------------------------------

class ForecastRow(BaseModel):
    year_month: str
    actual_revenue: Optional[float]
    pred_linear: Optional[float]
    pred_poly: Optional[float]
    split: str


class ForecastResponse(BaseModel):
    data: List[ForecastRow]
    mae_poly: float
    rmse_poly: float
    mape_poly: float
    forecast_months: List[ForecastRow]


# ---------------------------------------------------------------------------
# Anomaly Detection
# ---------------------------------------------------------------------------

class AnomalyRow(BaseModel):
    order_id: str
    total_payment: Optional[float]
    item_count: Optional[float]
    delivery_duration_days: Optional[float]
    if_score: Optional[float]
    both_flag: Optional[bool]
    level: str


class AnomalyResponse(BaseModel):
    total_flagged: int
    order_anomalies: int
    monthly_anomalies: int
    top_anomalies: List[AnomalyRow]


# ---------------------------------------------------------------------------
# AI Insights
# ---------------------------------------------------------------------------

class InsightsResponse(BaseModel):
    generated_at: str
    data_range: str
    methodology_note: str
    executive_summary: str
    key_trends: List[str]
    customer_insights: List[str]
    product_insights: List[str]
    delivery_insights: List[str]
    review_insights: List[str]
    potential_issues: List[str]
    suggested_actions: List[str]
