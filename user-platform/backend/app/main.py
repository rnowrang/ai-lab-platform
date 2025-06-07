"""
AI Lab User Platform - Main FastAPI Application
Multi-user ML platform with dynamic GPU allocation
"""

from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from contextlib import asynccontextmanager
import uvicorn

from .auth.router import auth_router
from .resources.router import resources_router
from .environments.router import environments_router
from .monitoring.router import monitoring_router
from .admin.router import admin_router
from .database import init_db


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize database on startup"""
    await init_db()
    yield


# Create FastAPI app
app = FastAPI(
    title="AI Lab User Platform",
    description="Multi-user ML platform with dynamic GPU allocation",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware for frontend integration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:8080"],  # Frontend URLs
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security
security = HTTPBearer()

# Include routers
app.include_router(auth_router, prefix="/api/auth", tags=["Authentication"])
app.include_router(resources_router, prefix="/api/resources", tags=["Resources"])
app.include_router(environments_router, prefix="/api/environments", tags=["Environments"])
app.include_router(monitoring_router, prefix="/api/monitoring", tags=["Monitoring"])
app.include_router(admin_router, prefix="/api/admin", tags=["Administration"])


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": "AI Lab User Platform API",
        "version": "1.0.0",
        "docs": "/docs",
        "status": "running"
    }


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "ai-lab-user-platform",
        "components": {
            "api": "running",
            "database": "connected",
            "kubernetes": "available"
        }
    }


if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    ) 