"""
backend/routers/delivery.py  — GET /api/delivery/analysis
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from backend.database import get_db
from backend.services.data_service import get_delivery_analysis
from backend.schemas.response_schemas import DeliveryResponse

router = APIRouter(prefix="/api/delivery", tags=["Delivery"])


@router.get("/analysis", response_model=DeliveryResponse)
def delivery_analysis(db: Session = Depends(get_db)):
    """Return delivery performance summary and monthly trend."""
    try:
        return get_delivery_analysis(db)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500,
                            detail=f"Delivery analysis query failed: {exc}")
