"""
backend/routers/segmentation.py  — GET /api/segmentation
"""
from fastapi import APIRouter, HTTPException
from backend.services.data_service import get_segmentation
from backend.schemas.response_schemas import SegmentationResponse

router = APIRouter(prefix="/api/segmentation", tags=["Segmentation"])


@router.get("", response_model=SegmentationResponse)
def customer_segmentation():
    """Return RFM K-Means customer segmentation results."""
    try:
        return get_segmentation()
    except Exception as exc:
        raise HTTPException(status_code=500,
                            detail=f"Failed to load segmentation data: {exc}")
