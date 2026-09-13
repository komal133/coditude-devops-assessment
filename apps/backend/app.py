"""
Minimal production-style FastAPI backend.

Database credentials are NEVER hard-coded. They arrive in one of two ways:

1. Containerised (ECS Fargate): individual DB_* environment variables are
   injected by ECS directly from AWS Secrets Manager ("secrets" block in the
   task definition). The application never calls Secrets Manager itself.

2. Non-containerised (EC2 + CodeDeploy): only DB_SECRET_ARN is provided.
   The app fetches the secret at start-up with boto3, using the IAM role
   attached to the EC2 instance (no keys on disk).
"""

import json
import os
from contextlib import asynccontextmanager

import psycopg
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

APP_ENV = os.getenv("APP_ENV", "dev")
DB_SECRET_ARN = os.getenv("DB_SECRET_ARN", "")


def load_db_config() -> dict:
    """Return connection settings from env vars or from Secrets Manager."""
    if DB_SECRET_ARN:
        import boto3  # imported lazily so local runs do not need AWS

        client = boto3.client(
            "secretsmanager",
            region_name=os.getenv("AWS_REGION", "ap-south-1"),
        )
        secret = json.loads(
            client.get_secret_value(SecretId=DB_SECRET_ARN)["SecretString"]
        )
        return {
            "host": secret.get("host", ""),
            "port": int(secret.get("port", 5432)),
            "user": secret.get("username", ""),
            "password": secret.get("password", ""),
            "dbname": secret.get("dbname", "appdb"),
        }
    return {
        "host": os.getenv("DB_HOST", "localhost"),
        "port": int(os.getenv("DB_PORT", "5432")),
        "user": os.getenv("DB_USER", "postgres"),
        "password": os.getenv("DB_PASSWORD", "postgres"),
        "dbname": os.getenv("DB_NAME", "appdb"),
    }


def connect():
    cfg = load_db_config()
    return psycopg.connect(
        host=cfg["host"],
        port=cfg["port"],
        user=cfg["user"],
        password=cfg["password"],
        dbname=cfg["dbname"],
        connect_timeout=5,
    )


def init_db() -> None:
    with connect() as conn, conn.cursor() as cur:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS items (
                id    SERIAL PRIMARY KEY,
                name  TEXT NOT NULL,
                added TIMESTAMPTZ NOT NULL DEFAULT now()
            )
            """
        )
        conn.commit()


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Never crash the container if the DB is briefly unavailable: the
    # /api/health endpoint stays up so the load balancer can still route.
    try:
        init_db()
    except Exception as exc:  # noqa: BLE001
        print(f"[startup] database not ready yet: {exc}", flush=True)
    yield


app = FastAPI(title="Assessment Backend", lifespan=lifespan)


class Item(BaseModel):
    name: str


@app.get("/api/health")
def health():
    """Load balancer health check. Must stay cheap and dependency-free."""
    return {"status": "ok", "env": APP_ENV}


@app.get("/api/ready")
def ready():
    """Deeper check used by CodeDeploy validation hooks."""
    try:
        with connect() as conn, conn.cursor() as cur:
            cur.execute("SELECT 1")
            cur.fetchone()
        return {"status": "ready", "database": "reachable"}
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=503, detail=str(exc))


@app.get("/api/items")
def list_items():
    with connect() as conn, conn.cursor() as cur:
        cur.execute("SELECT id, name, added FROM items ORDER BY id DESC LIMIT 50")
        rows = cur.fetchall()
    return [{"id": r[0], "name": r[1], "added": r[2].isoformat()} for r in rows]


@app.post("/api/items", status_code=201)
def create_item(item: Item):
    with connect() as conn, conn.cursor() as cur:
        cur.execute("INSERT INTO items (name) VALUES (%s) RETURNING id", (item.name,))
        new_id = cur.fetchone()[0]
        conn.commit()
    return {"id": new_id, "name": item.name}
