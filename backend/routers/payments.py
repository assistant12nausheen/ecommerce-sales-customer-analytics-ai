"""
backend/routers/payments.py  — GET /api/payments/analysis
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from backend.database import get_db
from backend.services.data_service import get_payment_analysis
from backend.schemas.response_schemas import PaymentResponse

router = APIRouter(prefix="/api/payments", tags=["Payments"])


@router.get("/analysis", response_model=PaymentResponse)
def payment_analysis(db: Session = Depends(get_db)):
    """Return payment type distribution and installment breakdown."""
    try:
        return get_payment_analysis(db)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500,
                            detail=f"Payment analysis query failed: {exc}")
