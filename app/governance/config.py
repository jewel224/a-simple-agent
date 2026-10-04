from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """治理版 Agent 的强制配置，缺失时禁止启动。"""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    mock_pg_host: str = "localhost"
    mock_pg_port: int = 5432
    mock_pg_user: str = "shop_app"
    mock_pg_password: str
    mock_pg_db: str = "shop_dw"
    mock_pg_ro_user: str = "shop_ro"
    mock_pg_ro_password: str

    embedding_pg_db: str = "embedding_store"
    embedding_pg_user: str = "embed_app"
    embedding_pg_password: str

    memory_pg_db: str = "agent_memory"
    memory_pg_user: str = "memory_app"
    memory_pg_password: str

    op_log_db: str = "op_log"
    op_log_user: str = "log_app"
    op_log_password: str

    dashscope_api_key: str
    qwen_model: str = "qwen-turbo"
    embedding_model: str = "text-embedding-v3"
    embedding_dimension: int = 1024

    app_api_key: str
    governed_sql_timeout_ms: int = 3000
    governed_sql_max_rows: int = 100

    semantic_table_limit: int = 6
    semantic_column_limit: int = 20
    semantic_metric_limit: int = 6
    semantic_example_limit: int = 3
    memory_message_limit: int = 10


@lru_cache
def get_settings() -> Settings:
    """读取并缓存配置；所有必要字段缺失时直接抛出异常。"""
    return Settings()
