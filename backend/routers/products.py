"""
backend/routers/products.py  — GET /api/products/categories
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from backend.database import get_db
from backend.services.data_service import get_category_performance
from backend.schemas.response_schemas import CategoryResponse

router = APIRouter(prefix="/api/products", tags=["Products"])


@router.get("/categories", response_model=CategoryResponse)
def category_performance(
    limit: int = Query(default=20, ge=1, le=73, description="Number of categories to return"),
    db: Session = Depends(get_db),
):
    """Return product category performance ranked by revenue."""
    try:
        data = get_category_performance(db, limit=limit)
        return {"data": data}
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500,
                            detail=f"Category query failed: {exc}")
