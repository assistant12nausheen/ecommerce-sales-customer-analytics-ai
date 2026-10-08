"""
backend/routers/forecasting.py  — GET /api/forecast
"""
from fastapi import APIRouter, HTTPException
from backend.services.data_service import get_forecast
from backend.schemas.response_schemas import ForecastResponse

router = APIRouter(prefix="/api/forecast", tags=["Forecasting"])


@router.get("", response_model=ForecastResponse)
def sales_forecast():
    """Return historical sales data with model fits and 3-month forward forecast."""
    try:
        return get_forecast()
    except Exception as exc:
        raise HTTPException(status_code=500,
                            detail=f"Failed to load forecast data: {exc}")
