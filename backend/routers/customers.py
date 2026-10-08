"""
backend/routers/customers.py  — GET /api/customers/stats
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from backend.database import get_db
from backend.services.data_service import get_customer_stats
from backend.schemas.response_schemas import CustomerStatsResponse

router = APIRouter(prefix="/api/customers", tags=["Customers"])


@router.get("/stats", response_model=CustomerStatsResponse)
def customer_stats(db: Session = Depends(get_db)):
    """Return customer analytics including breakdown by state."""
    try:
        return get_customer_stats(db)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500,
                            detail=f"Customer stats query failed: {exc}")
