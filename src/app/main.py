"""
FastAPI application — ECS Fargate deployment target.
"""
import os
import logging
import json
from datetime import datetime

from fastapi import FastAPI, Response
from fastapi.responses import JSONResponse

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

app = FastAPI(title="cicd-python-ecs", version="1.0.0")

ENVIRONMENT = os.getenv("ENVIRONMENT", "dev")
PORT = int(os.getenv("PORT", "8000"))


@app.get("/health")
def health() -> JSONResponse:
    return JSONResponse({"status": "healthy", "environment": ENVIRONMENT, "timestamp": datetime.utcnow().isoformat()})


@app.get("/")
def root() -> JSONResponse:
    return JSONResponse({"message": "cicd-python-ecs API", "environment": ENVIRONMENT})
