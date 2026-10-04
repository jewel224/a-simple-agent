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

## 3. v2 治理语义层

v2 在同一数据库中新增 `governance` schema：

### governance.table_metadata

| 字段 | 说明 |
| --- | --- |
| `table_name` | 业务表名，主键 |
| `business_meaning` | 表业务含义 |
| `grain` | 表粒度 |
| `is_active` | 是否可用于语义检索 |
| `embedding` | `vector(1024)` |
| `embedding_model` | 向量模型 |
| `updated_at` | 更新时间 |

### governance.column_metadata

| 字段 | 说明 |
| --- | --- |
| `table_name` + `column_name` | 联合主键 |
| `data_type` | PostgreSQL 字段类型 |
| `business_meaning` | 字段业务含义 |
| `sensitive_level` | `public` / `masked` / `restricted` |
| `allowed_roles` | 允许访问角色数组 |
| `embedding` | `vector(1024)` |

### governance.metric_metadata

保存指标编码、名称、口径、计算模板、单位和粒度。

### governance.query_example

保存自然语言问题、标准 SQL、使用表和向量。

四张表都建立 HNSW cosine 索引。DDL 初始化表和字段元数据；向量必须执行 `python -m app.governance.sync_semantic` 后才可检索。
