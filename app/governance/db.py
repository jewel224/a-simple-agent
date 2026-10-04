from urllib.parse import quote_plus

from functools import lru_cache

from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine

from app.governance.config import Settings, get_settings


class DatabaseManager:
    """按业务库、语义库、记忆库、日志库管理独立连接。"""

    def __init__(self, settings: Settings | None = None):
        self.settings = settings or get_settings()
        self._engines: dict[str, Engine] = {}

    def _url(self, user: str, password: str, database: str) -> str:
        return (
            f"postgresql+psycopg2://{quote_plus(user)}:{quote_plus(password)}"
            f"@{self.settings.mock_pg_host}:{self.settings.mock_pg_port}/{database}"
        )

    def engine(self, name: str) -> Engine:
        if name in self._engines:
            return self._engines[name]

        s = self.settings
        definitions = {
            "shop_ro": (s.mock_pg_ro_user, s.mock_pg_ro_password, s.mock_pg_db),
            "embedding": (s.embedding_pg_user, s.embedding_pg_password, s.embedding_pg_db),
            "memory": (s.memory_pg_user, s.memory_pg_password, s.memory_pg_db),
            "op_log": (s.op_log_user, s.op_log_password, s.op_log_db),
        }
        if name not in definitions:
            raise ValueError(f"未知的数据库连接类型: {name}")

        user, password, database = definitions[name]
        engine = create_engine(
            self._url(user, password, database),
            pool_pre_ping=True,
            pool_size=5,
            max_overflow=10,
            connect_args={"connect_timeout": 10},
        )
        self._engines[name] = engine
        return engine

    def ping(self, name: str) -> bool:
        with self.engine(name).connect() as conn:
            conn.execute(text("SELECT 1"))
        return True

    def dispose(self) -> None:
        for engine in self._engines.values():
            engine.dispose()
        self._engines.clear()

@lru_cache
def get_database_manager() -> DatabaseManager:
    """创建进程级共享连接池，供 API、Agent 工具和评测复用。"""
    return DatabaseManager()


def dispose_database_manager() -> None:
    """释放共享连接池并清除缓存，供 FastAPI 退出钩子调用。"""
    manager = get_database_manager()
    manager.dispose()
    get_database_manager.cache_clear()
