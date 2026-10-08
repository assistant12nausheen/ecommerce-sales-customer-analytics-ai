import sys, os
sys.path.insert(0, ".")
os.environ["CLEANED_DATA_DIR"] = os.path.abspath("data/cleaned")
os.environ["REPORTS_DIR"]      = os.path.abspath("reports")

from backend.services.data_service import (
    get_monthly_sales, get_segmentation, get_forecast, get_anomalies, get_insights
)

# Test 1: Monthly sales
ms = get_monthly_sales()
print(f"Monthly sales: {len(ms)} rows  {ms[0]['year_month']} to {ms[-1]['year_month']}")

# Test 2: Segmentation
sg = get_segmentation()
print(f"Segmentation: {sg['total_customers']:,} customers, {len(sg['segments'])} segments")
for s in sg["segments"]:
    print(f"  {s['segment']}: {s['customer_count']:,} ({s['pct_of_total']}%)")

# Test 3: Forecast
fc = get_forecast()
print(f"Forecast: {len(fc['data'])} history rows, {len(fc['forecast_months'])} future months")
for r in fc["forecast_months"]:
    print(f"  {r['year_month']}: poly={r['pred_poly']:,.0f}")

# Test 4: Anomalies
an = get_anomalies(limit=3)
print(f"Anomalies: total={an['total_flagged']:,}  orders={an['order_anomalies']:,}  monthly={an['monthly_anomalies']}")

# Test 5: Insights
ins = get_insights()
print(f"Insights keys: {list(ins.keys())}")
print(f"  Summary: {ins['executive_summary'][:80]}...")

print("\nAll file-based service tests PASSED.")
