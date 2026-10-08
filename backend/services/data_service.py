"""
backend/services/data_service.py
----------------------------------
All database queries and file-based data access live here.
Routers call these functions and receive plain Python dicts/lists.

Design rule: no SQLAlchemy or pandas code inside routers.
All business logic and data transformation happens here.
"""

import os
import json
import sys
from typing import List, Dict, Any, Optional

import pandas as pd
import numpy as np
from sqlalchemy.orm  import Session
from sqlalchemy      import text

# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------

def _project_root() -> str:
    """Return the project root directory."""
    return os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "..")
    )


def _resolve_path(env_name: str, default_folder: str, filename: str) -> str:
    """Resolve configured paths relative to the backend directory."""
    configured_path = os.getenv(env_name, default_folder)

    if os.path.isabs(configured_path):
        base = configured_path
    else:
        backend_dir = os.path.dirname(os.path.abspath(__file__))
        base = os.path.join(backend_dir, "..", "..", configured_path)

    return os.path.normpath(os.path.join(base, filename))


def _cleaned(filename: str) -> str:
    """Resolve a filename inside the cleaned-data directory."""
    return _resolve_path(
        "CLEANED_DATA_DIR",
        os.path.join("data", "cleaned"),
        filename,
    )


def _reports(filename: str) -> str:
    """Resolve a filename inside the reports directory."""
    return _resolve_path(
        "REPORTS_DIR",
        os.path.join("reports"),
        filename,
    )

# ===========================================================================
# 1. Dashboard KPIs
# ===========================================================================

def get_kpis(db: Session) -> Dict[str, Any]:
    sql = text("""
        SELECT
            COUNT(DISTINCT o.order_id)                         AS total_orders,
            ROUND(SUM(p.payment_value), 2)                     AS total_revenue,
            ROUND(AVG(p.payment_value), 2)                     AS avg_order_value,
            COUNT(DISTINCT c.customer_unique_id)               AS total_customers,
            (SELECT COUNT(*) FROM products)                    AS total_products,
            (SELECT COUNT(*) FROM sellers)                     AS total_sellers,
            ROUND(AVG(r.review_score), 2)                      AS avg_review_score,
            ROUND(AVG(o.delivery_duration_days), 1)            AS avg_delivery_days,
            ROUND(SUM(CASE WHEN o.is_late = 1 THEN 1 ELSE 0 END)
                  * 100.0 / COUNT(DISTINCT o.order_id), 1)     AS late_delivery_pct
        FROM orders  o
        JOIN customers c ON o.customer_id = c.customer_id
        JOIN payments  p ON o.order_id    = p.order_id
        LEFT JOIN reviews r ON o.order_id = r.order_id
        WHERE o.order_status = 'delivered'
    """)
    row = db.execute(sql).fetchone()._mapping

      # median order value via cleaned order totals
    try:
        ot = pd.read_csv(_cleaned("order_totals.csv"))
        delivered_values = pd.to_numeric(
            ot.loc[ot["order_status"].eq("delivered"), "total_payment"],
            errors="coerce"
        ).dropna()

        median_ov = float(delivered_values.median()) if not delivered_values.empty else 0.0
    except Exception:
        median_ov = 0.0

    return {
        "total_orders":      int(row["total_orders"]),
        "total_revenue":     float(row["total_revenue"] or 0),
        "avg_order_value":   float(row["avg_order_value"] or 0),
        "median_order_value": round(median_ov, 2),
        "total_customers":   int(row["total_customers"]),
        "total_products":    int(row["total_products"]),
        "total_sellers":     int(row["total_sellers"]),
        "avg_review_score":  float(row["avg_review_score"] or 0),
        "avg_delivery_days": float(row["avg_delivery_days"] or 0),
        "late_delivery_pct": float(row["late_delivery_pct"] or 0),
    }


# ===========================================================================
# 2. Monthly Sales Trend  (read from CSV — faster than DB aggregate)
# ===========================================================================

def get_monthly_sales() -> List[Dict[str, Any]]:
    df = pd.read_csv(_cleaned("monthly_sales.csv"))
    df = df[df["order_count"] >= 10].sort_values("month_number")
    df = df.where(pd.notnull(df), None)   # NaN → None for JSON
    return df[[
        "year_month", "order_count", "revenue",
        "avg_order_value", "avg_review_score",
        "avg_delivery_days", "late_order_count",
    ]].to_dict(orient="records")


# ===========================================================================
# 3. Category Performance
# ===========================================================================

def get_category_performance(db: Session, limit: int = 20) -> List[Dict[str, Any]]:
    sql = text("""
        SELECT
            COALESCE(pr.product_category_name_english,
                     pr.product_category_name, 'unknown')      AS category,
            COUNT(DISTINCT oi.order_id)                        AS orders,
            ROUND(SUM(oi.price), 2)                            AS revenue,
            COUNT(oi.order_item_id)                            AS units_sold,
            ROUND(AVG(oi.price), 2)                            AS avg_price,
            ROUND(AVG(r.review_score), 2)                      AS avg_review_score
        FROM order_items oi
        JOIN orders   o  ON oi.order_id   = o.order_id
        JOIN products pr ON oi.product_id = pr.product_id
        LEFT JOIN reviews r ON o.order_id = r.order_id
        WHERE o.order_status = 'delivered'
        GROUP BY category
        ORDER BY revenue DESC
        LIMIT :limit
    """)
    rows = db.execute(sql, {"limit": limit}).fetchall()
    return [dict(r._mapping) for r in rows]


# ===========================================================================
# 4. Customer Analytics
# ===========================================================================

def get_customer_stats(db: Session) -> Dict[str, Any]:
    # Aggregate from DB
    sql_state = text("""
        SELECT
            c.customer_state                               AS state,
            COUNT(DISTINCT o.order_id)                     AS order_count,
            ROUND(SUM(p.payment_value), 2)                 AS revenue,
            COUNT(DISTINCT c.customer_unique_id)           AS unique_customers
        FROM customers c
        JOIN orders   o ON c.customer_id = o.customer_id
        JOIN payments p ON o.order_id    = p.order_id
        WHERE o.order_status = 'delivered'
        GROUP BY c.customer_state
        ORDER BY order_count DESC
    """)
    state_rows = [dict(r._mapping) for r in db.execute(sql_state).fetchall()]

    # Summary stats from CSV (repeat rate, median spend)
    try:
        cf = pd.read_csv(_cleaned("customer_features.csv"))
        return {
            "total_customers":     int(cf["customer_unique_id"].nunique()),
            "repeat_customer_pct": round(float(cf["is_repeat_customer"].mean() * 100), 1),
            "avg_spend":           round(float(cf["monetary"].mean()), 2),
            "median_spend":        round(float(cf["monetary"].median()), 2),
            "by_state":            state_rows,
        }
    except Exception:
        return {"total_customers": 0, "repeat_customer_pct": 0,
                "avg_spend": 0, "median_spend": 0, "by_state": state_rows}


# ===========================================================================
# 5. Payment Analysis
# ===========================================================================

def get_payment_analysis(db: Session) -> Dict[str, Any]:
    sql_type = text("""
        SELECT
            payment_type,
            COUNT(DISTINCT order_id)                     AS order_count,
            ROUND(SUM(payment_value), 2)                 AS total_paid,
            ROUND(AVG(payment_value), 2)                 AS avg_payment,
            ROUND(COUNT(DISTINCT order_id) * 100.0 /
                  (SELECT COUNT(DISTINCT order_id) FROM payments), 1) AS pct_of_orders
        FROM payments
        WHERE payment_type != 'not_defined'
        GROUP BY payment_type
        ORDER BY order_count DESC
    """)
    by_type = [dict(r._mapping) for r in db.execute(sql_type).fetchall()]

    sql_inst = text("""
        SELECT
            payment_installments           AS installments,
            COUNT(*)                       AS count,
            ROUND(COUNT(*) * 100.0 /
                  (SELECT COUNT(*) FROM payments
                   WHERE payment_type = 'credit_card'), 1) AS pct
        FROM payments
        WHERE payment_type = 'credit_card'
        GROUP BY payment_installments
        ORDER BY payment_installments
    """)
    cc_inst = [dict(r._mapping) for r in db.execute(sql_inst).fetchall()]

    sql_cc = text("""
        SELECT
            ROUND(AVG(payment_installments), 1) AS avg_inst
        FROM payments
        WHERE payment_type = 'credit_card'
    """)
    avg_inst = float(db.execute(sql_cc).fetchone()[0] or 0)

    cc_pct = next(
        (r["pct_of_orders"] for r in by_type if r["payment_type"] == "credit_card"),
        0.0,
    )

    return {
        "by_type":           by_type,
        "cc_installments":   cc_inst,
        "credit_card_pct":   cc_pct,
        "avg_installments_cc": avg_inst,
    }


# ===========================================================================
# 6. Review Analysis
# ===========================================================================

def get_review_analysis(db: Session) -> Dict[str, Any]:
    sql = text("""
        SELECT
            review_score                        AS score,
            COUNT(*)                            AS count,
            ROUND(COUNT(*) * 100.0 /
                  (SELECT COUNT(*) FROM reviews), 1) AS pct
        FROM reviews
        GROUP BY review_score
        ORDER BY review_score
    """)
    by_score = [dict(r._mapping) for r in db.execute(sql).fetchall()]

    sql_agg = text("""
        SELECT
            ROUND(AVG(review_score), 2)                         AS avg_score,
            ROUND(SUM(CASE WHEN review_score = 5 THEN 1 ELSE 0 END)
                  * 100.0 / COUNT(*), 1)                        AS five_star_pct,
            ROUND(SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END)
                  * 100.0 / COUNT(*), 1)                        AS negative_pct
        FROM reviews
    """)
    agg = db.execute(sql_agg).fetchone()._mapping

    return {
        "avg_score":    float(agg["avg_score"] or 0),
        "five_star_pct": float(agg["five_star_pct"] or 0),
        "negative_pct": float(agg["negative_pct"] or 0),
        "by_score":     by_score,
    }


# ===========================================================================
# 7. Delivery Analysis
# ===========================================================================

def get_delivery_analysis(db: Session) -> Dict[str, Any]:
    sql_summary = text("""
        SELECT
            ROUND(AVG(delivery_duration_days), 1)  AS avg_delivery_days,
            ROUND(MIN(delivery_duration_days), 1)  AS min_days,
            ROUND(MAX(delivery_duration_days), 1)  AS max_days,
            ROUND(AVG(delivery_delay_days), 1)     AS avg_delay_days,
            ROUND(SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END)
                  * 100.0 / COUNT(*), 1)           AS late_pct,
            ROUND(SUM(CASE WHEN is_late = 0 THEN 1 ELSE 0 END)
                  * 100.0 / COUNT(*), 1)           AS on_time_pct
        FROM orders
        WHERE order_status = 'delivered'
              AND delivery_duration_days IS NOT NULL
    """)
    s = db.execute(sql_summary).fetchone()._mapping 

    sql_monthly = text("""
        SELECT
            YEAR(order_purchase_timestamp) AS sale_year,
            MONTH(order_purchase_timestamp) AS sale_month,
            ROUND(AVG(delivery_duration_days), 1) AS avg_delivery_days,
            ROUND(
                SUM(CASE WHEN is_late = 1 THEN 1 ELSE 0 END)
                * 100.0 / COUNT(*),
                1
            ) AS late_pct
        FROM orders
        WHERE order_status = 'delivered'
          AND order_purchase_timestamp IS NOT NULL
          AND delivery_duration_days IS NOT NULL
        GROUP BY
            YEAR(order_purchase_timestamp),
            MONTH(order_purchase_timestamp)
        ORDER BY
            YEAR(order_purchase_timestamp),
            MONTH(order_purchase_timestamp)
    """)
    by_month = []
    for r in db.execute(sql_monthly).fetchall():
        year_month = f"{int(r[0])}-{int(r[1]):02d}"
        by_month.append({
            "year_month": year_month,
            "avg_delivery_days": float(r[2] or 0),
            "late_pct": float(r[3] or 0)
        })
    try:
        oe = pd.read_csv(_cleaned("orders_enriched.csv"))
        med = float(oe[oe["order_status"] == "delivered"]["delivery_duration_days"].median())
    except Exception:
        med = 0.0

    return {
        "summary": {
            "avg_delivery_days":    float(s["avg_delivery_days"] or 0),
            "median_delivery_days": round(med, 1),
            "late_pct":             float(s["late_pct"] or 0),
            "avg_delay_days":       float(s["avg_delay_days"] or 0),
            "on_time_pct":          float(s["on_time_pct"] or 0),
        },
        "by_month": by_month,
    }


# ===========================================================================
# 8. Customer Segmentation  (CSV-based)
# ===========================================================================

def get_segmentation() -> Dict[str, Any]:
    df = pd.read_csv(_cleaned("customer_segments.csv"))
    total = len(df)

    seg_stats = (
        df.groupby("segment")
        .agg(
            customer_count  = ("customer_unique_id", "count"),
            avg_recency_days = ("recency_days", "mean"),
            avg_frequency    = ("frequency",    "mean"),
            avg_monetary     = ("monetary",     "mean"),
        )
        .round(2)
        .reset_index()
    )
    seg_stats["pct_of_total"] = (seg_stats["customer_count"] / total * 100).round(1)
    seg_stats = seg_stats.sort_values("avg_monetary", ascending=False)

    return {
        "segments":        seg_stats.to_dict(orient="records"),
        "total_customers": total,
        "method":          "K-Means clustering on log-transformed, scaled RFM features (K=4)",
    }


# ===========================================================================
# 9. Forecasting  (CSV-based)
# ===========================================================================

def get_forecast() -> Dict[str, Any]:
    df = pd.read_csv(_cleaned("forecast_results.csv"))

    # Convert NaN / infinite values to JSON-safe None
    df = df.replace([np.inf, -np.inf], np.nan)
    df = df.astype(object).where(pd.notnull(df), None)

    historical = df[df["split"].isin(["train", "test"])].to_dict(orient="records")
    future = df[df["split"] == "forecast"].to_dict(orient="records")

    return {
        "data": historical,
        "mae_poly": 185249.43,
        "rmse_poly": 220396.00,
        "mape_poly": 18.2,
        "forecast_months": future,
    }

# ===========================================================================
# 10. Anomaly Detection  (CSV-based)
# ===========================================================================

def get_anomalies(limit: int = 50) -> Dict[str, Any]:
    df = pd.read_csv(_cleaned("anomalies.csv"))
    df = df.where(pd.notnull(df), None)

    order_anom   = df[df["level"] == "order"]
    monthly_anom = df[df["level"] == "monthly"]

    # Top anomalies: if_score column exists on order-level rows
    if "if_score" in order_anom.columns:
        top = (
            order_anom
            .sort_values("if_score")
            .head(limit)
        )
    else:
        top = order_anom.head(limit)

    top = top.where(pd.notnull(top), None)

    return {
        "total_flagged":     len(df),
        "order_anomalies":   len(order_anom),
        "monthly_anomalies": len(monthly_anom),
        "top_anomalies":     top[
            [c for c in [
                "order_id", "total_payment", "item_count",
                "delivery_duration_days", "if_score",
                "both_flag", "level",
            ] if c in top.columns]
        ].to_dict(orient="records"),
    }


# ===========================================================================
# 11. AI Insights  (JSON report file)
# ===========================================================================

def get_insights() -> Dict[str, Any]:
    json_path = _reports("ai_insights_report.json")
    if not os.path.exists(json_path):
        # Generate on the fly if file not present
        sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))
        from python.ai_insights import collect_metrics, generate_insights
        metrics = collect_metrics()
        return generate_insights(metrics)

    with open(json_path, encoding="utf-8") as f:
        report = json.load(f)

    # Remove raw_metrics from API response (too large)
    report.pop("raw_metrics", None)
    return report
