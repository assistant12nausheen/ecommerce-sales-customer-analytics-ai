"""
backend/routers/dashboard.py  — GET /api/dashboard/kpis
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from backend.database import get_db
from backend.services.data_service import get_kpis
from backend.schemas.response_schemas import DashboardKpis

router = APIRouter(prefix="/api/dashboard", tags=["Dashboard"])


@router.get("/kpis", response_model=DashboardKpis)
def dashboard_kpis(db: Session = Depends(get_db)):
    """Return all headline KPI numbers for the dashboard cards."""
    try:
        return get_kpis(db)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500,
                            detail=f"Dashboard KPI query failed: {exc}")
