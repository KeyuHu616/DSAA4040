from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from backend.app.api.routes.actions import router as actions_router
from backend.app.api.routes.cluster import router as cluster_router
from backend.app.api.routes.kubeconfigs import router as kubeconfigs_router
from backend.app.api.routes.tenants import router as tenants_router
from backend.app.api.routes.test_results import router as test_results_router
from backend.app.config import get_settings


settings = get_settings()

app = FastAPI(
    title="DSAA4040 Local Management Backend",
    version="0.1.0",
    description="Local-only backend for the DSAA4040 multi-tenant Kubernetes lab platform.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://127.0.0.1:5173",
        "http://localhost:5173",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(cluster_router)
app.include_router(tenants_router)
app.include_router(kubeconfigs_router)
app.include_router(actions_router)
app.include_router(test_results_router)


@app.get("/")
def root() -> dict[str, object]:
    return {
        "name": "dsaa4040-local-backend",
        "local_only": True,
        "host": settings.backend_host,
        "port": settings.backend_port,
    }