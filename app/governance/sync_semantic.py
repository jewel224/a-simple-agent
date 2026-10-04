from sqlalchemy import text

from app.governance.config import get_settings
from app.governance.db import DatabaseManager
from app.governance.embedding import EmbeddingClient


def sync_semantic_metadata():
    """为语义层元数据生成向量；缺失向量时检索不可用。"""
    settings = get_settings()
    db_manager = DatabaseManager(settings)
    embedding_client = EmbeddingClient()

    jobs = [
        (
            "table_metadata",
            "SELECT table_name, business_meaning, grain FROM governance.table_metadata",
            "UPDATE governance.table_metadata SET embedding = CAST(:embedding AS vector), embedding_model = :model, updated_at = now() WHERE table_name = :table_name",
            lambda row: f"{row['table_name']} {row['business_meaning']} {row['grain']}",
        ),
        (
            "column_metadata",
            "SELECT table_name, column_name, data_type, business_meaning, sensitive_level FROM governance.column_metadata",
            "UPDATE governance.column_metadata SET embedding = CAST(:embedding AS vector), embedding_model = :model, updated_at = now() WHERE table_name = :table_name AND column_name = :column_name",
            lambda row: f"{row['table_name']}.{row['column_name']} {row['data_type']} {row['business_meaning']} 敏感级别 {row['sensitive_level']}",
        ),
        (
            "metric_metadata",
            "SELECT metric_code, metric_name, definition, calculation_sql_template, unit, grain FROM governance.metric_metadata",
            "UPDATE governance.metric_metadata SET embedding = CAST(:embedding AS vector), embedding_model = :model, updated_at = now() WHERE metric_code = :metric_code",
            lambda row: f"{row['metric_code']} {row['metric_name']} {row['definition']} {row['calculation_sql_template']} {row['unit']} {row['grain']}",
        ),
        (
            "query_example",
            "SELECT example_id, question, sql_text FROM governance.query_example",
            "UPDATE governance.query_example SET embedding = CAST(:embedding AS vector), embedding_model = :model WHERE example_id = :example_id",
            lambda row: f"{row['question']} {row['sql_text']}",
        ),
    ]

    # 使用单个显式事务包住全部向量更新，避免 SQLAlchemy 连接退出时回滚已生成向量。
    with db_manager.engine("embedding").begin() as conn:
        for table_name, select_sql, update_sql, sentence_builder in jobs:
            rows = conn.execute(text(select_sql)).mappings().all()
            if not rows:
                raise RuntimeError(f"语义表 {table_name} 没有可同步数据")
            for row in rows:
                sentence = sentence_builder(row)
                vector = embedding_client.embed(sentence)
                params = {
                    "embedding": EmbeddingClient.to_pgvector(vector),
                    "model": settings.embedding_model,
                    **row,
                }
                conn.execute(text(update_sql), params)
            print(f"synced {len(rows)} rows in {table_name}")

        missing_count = conn.execute(
            text(
                """
                SELECT
                    (SELECT COUNT(*) FROM governance.table_metadata WHERE embedding IS NULL) +
                    (SELECT COUNT(*) FROM governance.column_metadata WHERE embedding IS NULL) +
                    (SELECT COUNT(*) FROM governance.metric_metadata WHERE embedding IS NULL) +
                    (SELECT COUNT(*) FROM governance.query_example WHERE embedding IS NULL)
                """
            )
        ).scalar_one()
        if missing_count != 0:
            raise RuntimeError(f"语义向量同步后仍有 {missing_count} 条元数据缺失向量")


if __name__ == "__main__":
    sync_semantic_metadata()
