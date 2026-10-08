"""
backend/routers/reviews.py  — GET /api/reviews/analysis
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from backend.database import get_db
from backend.services.data_service import get_review_analysis
from backend.schemas.response_schemas import ReviewResponse

router = APIRouter(prefix="/api/reviews", tags=["Reviews"])


@router.get("/analysis", response_model=ReviewResponse)
def review_analysis(db: Session = Depends(get_db)):
    """Return review score distribution and summary statistics."""
    try:
        return get_review_analysis(db)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500,
                            detail=f"Review analysis query failed: {exc}")
