import secrets
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from functools import lru_cache

from fastapi import Depends, FastAPI, Header, Request
from fastapi.responses import JSONResponse

from app.governance.db import dispose_database_manager
from app.governance.errors import ApiError
from app.governance.schemas import (
    ErrorResponse,
    HealthResponse,
    QueryRequest,
    QueryResponse,
)
from app.governance.service import GovernedAgentService


@lru_cache
def get_agent_service() -> GovernedAgentService:
    """创建并复用治理版 Agent 服务。"""
    return GovernedAgentService()


def require_api_key(x_api_key: str | None = Header(default=None, alias="X-API-Key")) -> str:
    expected = get_agent_service().settings.app_api_key
    if not x_api_key or not secrets.compare_digest(x_api_key, expected):
        raise ApiError(401, "UNAUTHORIZED", "缺少或错误的 API Key")
    return "api_client"


@asynccontextmanager
async def lifespan(app: FastAPI):
    """启动时创建服务，退出时释放数据库连接池。"""
    service = get_agent_service()
    app.state.agent_service = service
    try:
        yield
    finally:
        dispose_database_manager()
        get_agent_service.cache_clear()


def create_app() -> FastAPI:
    app = FastAPI(
        title="Text-to-SQL Agent 数据问答与治理系统",
        version="v2",
        description="受治理的订单业务自然语言查询服务",
        lifespan=lifespan,
    )

    @app.exception_handler(Exception)
    async def unhandled_error_handler(request: Request, exc: Exception):
        return JSONResponse(
            status_code=500,
            content=ErrorResponse(code="INTERNAL_ERROR", message="服务内部错误").model_dump(),
        )

    @app.exception_handler(ApiError)
    async def api_error_handler(request: Request, exc: ApiError):
        return JSONResponse(
            status_code=exc.status_code,
            content=ErrorResponse(code=exc.code, message=exc.message).model_dump(),
        )

    @app.get("/healthz", response_model=HealthResponse)
    def healthz():
        service = get_agent_service()
        statuses = {}
        for name in ["shop_ro", "embedding", "memory", "op_log"]:
            try:
                statuses[name] = service.db_manager.ping(name)
            except Exception:
                statuses[name] = False

        try:
            missing = service.semantic.metadata_readiness()
            semantic_ready = all(value == 0 for value in missing.values())
        except Exception:
            missing = None
            semantic_ready = False
        return HealthResponse(
            status="ok" if all(statuses.values()) and semantic_ready else "unhealthy",
            databases=statuses,
            semantic_metadata_ready=semantic_ready,
            semantic_metadata_missing=missing,
            checked_at=datetime.now(timezone.utc),
        )

    @app.post("/api/v1/query", response_model=QueryResponse)
    def query(
        payload: QueryRequest,
        request: Request,
        actor_id: str = Depends(require_api_key),
    ):
        service = get_agent_service()
        return service.query(
            question=payload.question,
            session_id=payload.session_id,
            actor_id=actor_id,
            client_ip=request.client.host if request.client else None,
        )

    return app


app = create_app()




