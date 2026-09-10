-- embedding_store 演示种子数据
-- 执行角色：embed_app，连接数据库：embedding_store

TRUNCATE TABLE public.embeddings, public.chunks, public.documents RESTART IDENTITY CASCADE;

INSERT INTO public.documents (
    document_id,
    document_code,
    source_type,
    title,
    uri,
    metadata
) OVERRIDING SYSTEM VALUE
VALUES
    (1, 'DOC_SQL_001', 'markdown', 'PostgreSQL 外键设计说明', 'local://sql/fk_guide.md',
     '{"topic": "database", "tags": ["postgresql", "foreign key"]}'),
    (2, 'DOC_AGENT_001', 'markdown', 'AI Agent 记忆设计说明', 'local://agent/memory_guide.md',
     '{"topic": "agent", "tags": ["memory", "session"]}');

INSERT INTO public.chunks (
    chunk_id,
    document_id,
    chunk_no,
    content,
    token_count,
    metadata
) OVERRIDING SYSTEM VALUE
VALUES
    (1, 1, 1, '外键用于维护子表与父表之间的一致性，删除父记录时必须考虑引用完整性。', 24,
     '{"section": "intro"}'),
    (2, 1, 2, '事实表通常引用多个维度表，维度表通过代理键建立关联。', 21,
     '{"section": "star_schema"}'),
    (3, 2, 1, 'Agent 可以把用户偏好保存为长期记忆，并在后续会话中检索使用。', 23,
     '{"section": "memory"}');

INSERT INTO public.embeddings (
    embedding_id,
    chunk_id,
    model_name,
    model_version,
    dimensions,
    embedding,
    distance_function
) OVERRIDING SYSTEM VALUE
VALUES
    (1, 1, 'demo-embedding', 'v1', 3, '[0.90, 0.10, 0.00]'::vector, 'cosine'),
    (2, 2, 'demo-embedding', 'v1', 3, '[0.10, 0.90, 0.00]'::vector, 'cosine'),
    (3, 3, 'demo-embedding', 'v1', 3, '[0.00, 0.20, 0.80]'::vector, 'cosine');

SELECT setval(pg_get_serial_sequence('public.documents', 'document_id'), (SELECT max(document_id) FROM public.documents));
SELECT setval(pg_get_serial_sequence('public.chunks', 'chunk_id'), (SELECT max(chunk_id) FROM public.chunks));
SELECT setval(pg_get_serial_sequence('public.embeddings', 'embedding_id'), (SELECT max(embedding_id) FROM public.embeddings));
