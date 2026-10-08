"""
backend/routers/anomalies.py  — GET /api/anomalies
"""
from fastapi import APIRouter, HTTPException, Query
from backend.services.data_service import get_anomalies
from backend.schemas.response_schemas import AnomalyResponse

router = APIRouter(prefix="/api/anomalies", tags=["Anomalies"])


@router.get("", response_model=AnomalyResponse)
def anomaly_detection(
    limit: int = Query(default=50, ge=1, le=500,
                       description="Max number of top anomalous orders to return"),
):
    """Return anomaly detection results from IQR + Isolation Forest."""
    try:
        return get_anomalies(limit=limit)
    except Exception as exc:
        raise HTTPException(status_code=500,
                            detail=f"Failed to load anomaly data: {exc}")
