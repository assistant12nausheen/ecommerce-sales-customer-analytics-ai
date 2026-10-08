import sys, os
sys.path.insert(0, ".")

env_path = os.path.join("backend", ".env")
if not os.path.exists(env_path):
    with open(env_path, "w") as f:
        f.write(
            "DB_HOST=localhost\nDB_PORT=3306\nDB_USER=root\n"
            "DB_PASSWORD=test\nDB_NAME=olist_ecommerce\n"
            "CLEANED_DATA_DIR=../data/cleaned\nREPORTS_DIR=../reports\n"
        )

from backend.database import Base, get_db, test_connection
from backend.models.orm_models import (
    Customer, Product, Seller, Order, OrderItem, Payment, Review
)
from backend.schemas.response_schemas import (
    DashboardKpis, MonthlySalesResponse, CategoryResponse,
    CustomerStatsResponse, PaymentResponse, ReviewResponse,
    DeliveryResponse, SegmentationResponse, ForecastResponse,
    AnomalyResponse, InsightsResponse,
)
from backend.services.data_service import (
    get_monthly_sales, get_segmentation, get_forecast,
    get_anomalies, get_insights,
)
from backend.routers import (
    dashboard, sales, products, customers, payments,
    reviews, delivery, segmentation, forecasting, anomalies, insights,
)
from backend.main import app

print("All imports OK.")
print(f"Routes registered: {len(app.routes)}")
for r in app.routes:
    if hasattr(r, "methods"):
        methods = ",".join(sorted(r.methods))
        print(f"  [{methods}] {r.path}")
