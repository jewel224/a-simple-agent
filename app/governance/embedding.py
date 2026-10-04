from typing import Any

import dashscope

from app.governance.config import get_settings
from app.governance.errors import SemanticMetadataError


class EmbeddingClient:
    """调用 DashScope Embedding，并把向量转换为 pgvector 字符串。"""

    def __init__(self):
        self.settings = get_settings()
        dashscope.api_key = self.settings.dashscope_api_key

    def embed(self, text: str) -> list[float]:
        if not text.strip():
            raise SemanticMetadataError("生成向量时输入文本不能为空")
        response = dashscope.TextEmbedding.call(
            model=self.settings.embedding_model,
            input=[text],
        )
        if getattr(response, "status_code", None) != 200:
            raise SemanticMetadataError(f"向量生成失败: {getattr(response, 'message', response)}")
        try:
            vector = response.output["embeddings"][0]["embedding"]
        except Exception as exc:
            raise SemanticMetadataError("向量接口返回结构异常") from exc
        if len(vector) != self.settings.embedding_dimension:
            raise SemanticMetadataError(
                f"向量维度不匹配: 期望 {self.settings.embedding_dimension}, 实际 {len(vector)}"
            )
        return vector

    @staticmethod
    def to_pgvector(vector: list[float]) -> str:
        return "[" + ",".join(str(value) for value in vector) + "]"
