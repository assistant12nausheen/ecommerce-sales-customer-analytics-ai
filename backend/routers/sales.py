"""
backend/routers/sales.py  — GET /api/sales/monthly
"""
from fastapi import APIRouter, HTTPException
from backend.services.data_service import get_monthly_sales
from backend.schemas.response_schemas import MonthlySalesResponse

router = APIRouter(prefix="/api/sales", tags=["Sales"])


@router.get("/monthly", response_model=MonthlySalesResponse)
def monthly_sales():
    """Return monthly aggregated sales data for trend charts."""
    try:
        data = get_monthly_sales()
        return {"data": data, "total_months": len(data)}
    except Exception as exc:
        raise HTTPException(status_code=500,
                            detail=f"Failed to load monthly sales: {exc}")
