# embedding_store 数据模型

## 1. 用途

`embedding_store` 用于存放 AI 学习资料的文档、分块文本与向量，作为 RAG 检索的基础存储。

## 2. 表结构

### documents 文档表

一行一个来源文档。

字段：

- `document_id BIGINT PRIMARY KEY`
- `document_code VARCHAR(64) UNIQUE NOT NULL` 来源业务编码
- `source_type VARCHAR(32) NOT NULL` pdf/markdown/web/csv/sql
- `title VARCHAR(255) NOT NULL`
- `uri VARCHAR(1024)`
- `content_sha256 CHAR(64)`
- `metadata JSONB NOT NULL DEFAULT '{}'`
- `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`

### chunks 分块表

一行一个文档分块。

字段：

- `chunk_id BIGINT PRIMARY KEY`
- `document_id BIGINT NOT NULL REFERENCES documents(document_id) ON DELETE CASCADE`
- `chunk_no INTEGER NOT NULL`
- `content TEXT NOT NULL`
- `content_sha256 CHAR(64)`
- `token_count INTEGER`
- `metadata JSONB NOT NULL DEFAULT '{}'`
- `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`

唯一约束：`UNIQUE(document_id, chunk_no)`。

### embeddings 向量表

一行一个文档分块在一套模型参数下生成的向量。

字段：

- `embedding_id BIGINT PRIMARY KEY`
- `chunk_id BIGINT NOT NULL REFERENCES chunks(chunk_id) ON DELETE CASCADE`
- `model_name VARCHAR(128) NOT NULL`
- `model_version VARCHAR(64) NOT NULL`
- `dimensions INTEGER NOT NULL`
- `embedding vector NOT NULL`
- `distance_function VARCHAR(16) NOT NULL DEFAULT 'cosine'`
- `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`

约束：

- `CHECK (vector_dims(embedding) = dimensions)`
- `UNIQUE(chunk_id, model_name, model_version)`

初始阶段使用精确最近邻查询；确定模型维度后，可以按模型和维度建立 HNSW 表达式索引。
