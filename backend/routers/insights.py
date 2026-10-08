"""
backend/routers/insights.py  — GET /api/insights
"""
from fastapi import APIRouter, HTTPException
from backend.services.data_service import get_insights
from backend.schemas.response_schemas import InsightsResponse

router = APIRouter(prefix="/api/insights", tags=["AI Insights"])


@router.get("", response_model=InsightsResponse)
def ai_insights():
    """Return the AI-generated business insights report."""
    try:
        return get_insights()
    except Exception as exc:
        raise HTTPException(status_code=500,
                            detail=f"Failed to load insights report: {exc}")
