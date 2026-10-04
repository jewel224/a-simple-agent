from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field


class QueryRequest(BaseModel):
    question: str = Field(..., min_length=1, max_length=1000)
    session_id: UUID | None = None


class UsedMetadata(BaseModel):
    tables: list[str] = Field(default_factory=list)
    metrics: list[str] = Field(default_factory=list)
    examples: list[str] = Field(default_factory=list)


class QueryResponse(BaseModel):
    trace_id: UUID
    session_id: UUID
    answer: str
    sql: str | None = None
    columns: list[str] = Field(default_factory=list)
    rows: list[list[Any]] = Field(default_factory=list)
    row_count: int = 0
    truncated: bool = False
    safety_rejected: bool = False
    used_metadata: UsedMetadata
    sql_latency_ms: int | None = None
    latency_ms: int | None = None
    token_usage: dict[str, Any] | None = None


class HealthResponse(BaseModel):
    status: str
    databases: dict[str, bool]
    semantic_metadata_ready: bool
    semantic_metadata_missing: dict[str, int] | None
    checked_at: datetime


class ErrorResponse(BaseModel):
    code: str
    message: str
