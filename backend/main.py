"""
backend/main.py
----------------
FastAPI application entry point.

HOW TO START THE SERVER
-----------------------
1. Install dependencies:
       pip install -r backend/requirements.txt

2. Copy the example env file and fill in your MySQL credentials:
       copy backend\\.env.example backend\\.env
   Then open backend/.env and set DB_PASSWORD.

3. Make sure MySQL is running and the database has been loaded:
       python python/db_seed.py

4. Run from the PROJECT ROOT directory (not from inside backend/):
       uvicorn backend.main:app --reload --port 8000

5. Open your browser:
       http://localhost:8000        -> welcome message
       http://localhost:8000/docs  -> interactive Swagger UI (all endpoints)
       http://localhost:8000/redoc -> ReDoc documentation

IMPORTANT: Always run uvicorn from the project root so that relative
imports (backend.routers.*, backend.services.*) resolve correctly and
the ../data/cleaned path in services works.
"""

import os
import logging
import traceback

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from dotenv import load_dotenv

logger = logging.getLogger(__name__)

# Load environment variables from backend/.env
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), ".env"))

# Import all routers
from backend.routers.dashboard    import router as dashboard_router
from backend.routers.sales        import router as sales_router
from backend.routers.products     import router as products_router
from backend.routers.customers    import router as customers_router
from backend.routers.payments     import router as payments_router
from backend.routers.reviews      import router as reviews_router
from backend.routers.delivery     import router as delivery_router
from backend.routers.segmentation import router as segmentation_router
from backend.routers.forecasting  import router as forecasting_router
from backend.routers.anomalies    import router as anomalies_router
from backend.routers.insights     import router as insights_router

from backend.database import test_connection

# ---------------------------------------------------------------------------
# Create the FastAPI app
# ---------------------------------------------------------------------------
app = FastAPI(
    title       = "Olist E-Commerce Analytics API",
    description = (
        "REST API for the E-Commerce Sales & Customer Analytics with AI project. "
        "Powered by Brazilian E-Commerce Public Dataset by Olist."
    ),
    version     = "1.0.0",
    docs_url    = "/docs",
    redoc_url   = "/redoc",
)

# ---------------------------------------------------------------------------
# CORS — allow the React frontend (Vite dev server on port 5173) to call the API
# ---------------------------------------------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins     = ["http://localhost:5173", "http://localhost:3000",
                         "http://127.0.0.1:5173"],
    allow_credentials = True,
    allow_methods     = ["GET"],      # this API is read-only
    allow_headers     = ["*"],
)

# ---------------------------------------------------------------------------
# Register routers
# ---------------------------------------------------------------------------
app.include_router(dashboard_router)
app.include_router(sales_router)
app.include_router(products_router)
app.include_router(customers_router)
app.include_router(payments_router)
app.include_router(reviews_router)
app.include_router(delivery_router)
app.include_router(segmentation_router)
app.include_router(forecasting_router)
app.include_router(anomalies_router)
app.include_router(insights_router)

# ---------------------------------------------------------------------------
# Root and health-check endpoints
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Global exception handler — turns unhandled exceptions into clean JSON
# instead of a plain HTTP 500 with no detail.
# ---------------------------------------------------------------------------

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    tb = traceback.format_exc()
    logger.error("Unhandled exception on %s %s\n%s", request.method, request.url, tb)
    # Never expose raw tracebacks in the response body
    return JSONResponse(
        status_code=500,
        content={
            "error":   type(exc).__name__,
            "detail":  str(exc),
            "path":    str(request.url.path),
        },
    )


# ---------------------------------------------------------------------------
# Root and health-check endpoints
# ---------------------------------------------------------------------------

@app.get("/", tags=["Root"])
def root():
    return {
        "project": "E-Commerce Sales & Customer Analytics with AI",
        "dataset": "Brazilian E-Commerce Public Dataset by Olist",
        "docs":    "/docs",
        "status":  "running",
    }


@app.get("/health", tags=["Root"])
@app.get("/api/health", tags=["Root"])
def health_check():
    """Quick health check — confirms API is running and DB is reachable."""
    db_ok = test_connection()
    return {
        "status":             "ok" if db_ok else "degraded",
        "database_connected": db_ok,
        "message":            (
            "API running. Database connected."
            if db_ok else
            "API running. Database NOT connected — CSV fallback is active."
        ),
    }
