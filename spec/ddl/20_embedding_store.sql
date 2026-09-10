-- embedding_store：文档分块与向量
-- 执行角色：embed_app，连接数据库：embedding_store

CREATE TABLE IF NOT EXISTS public.documents (
    document_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    document_code varchar(64) NOT NULL UNIQUE,
    source_type varchar(32) NOT NULL,
    title varchar(255) NOT NULL,
    uri varchar(1024),
    content_sha256 char(64),
    metadata jsonb NOT NULL DEFAULT '{}',
    created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.documents IS 'RAG 来源文档，一行一个文档';

CREATE TABLE IF NOT EXISTS public.chunks (
    chunk_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    document_id bigint NOT NULL REFERENCES public.documents(document_id) ON DELETE CASCADE,
    chunk_no integer NOT NULL,
    content text NOT NULL,
    content_sha256 char(64),
    token_count integer,
    metadata jsonb NOT NULL DEFAULT '{}',
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_chunks_document_no UNIQUE (document_id, chunk_no)
);

COMMENT ON TABLE public.chunks IS '文档分块，一行一个文本块';

CREATE TABLE IF NOT EXISTS public.embeddings (
    embedding_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    chunk_id bigint NOT NULL REFERENCES public.chunks(chunk_id) ON DELETE CASCADE,
    model_name varchar(128) NOT NULL,
    model_version varchar(64) NOT NULL,
    dimensions integer NOT NULL CHECK (dimensions > 0),
    embedding vector NOT NULL,
    distance_function varchar(16) NOT NULL DEFAULT 'cosine',
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_embeddings_chunk_model UNIQUE (chunk_id, model_name, model_version),
    CONSTRAINT chk_embeddings_dimension CHECK (vector_dims(embedding) = dimensions)
);

COMMENT ON TABLE public.embeddings IS '分块向量，模型、版本与维度可配置';
