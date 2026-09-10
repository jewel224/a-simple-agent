-- embedding_store 向量测试

DO $$
DECLARE
    document_count integer;
    chunk_count integer;
    embedding_count integer;
    nearest_chunk bigint;
BEGIN
    SELECT count(*) INTO document_count FROM public.documents;
    SELECT count(*) INTO chunk_count FROM public.chunks;
    SELECT count(*) INTO embedding_count FROM public.embeddings;

    IF document_count <> 2 OR chunk_count <> 3 OR embedding_count <> 3 THEN
        RAISE EXCEPTION 'embedding seed counts mismatch: doc=% chunk=% embedding=%',
            document_count, chunk_count, embedding_count;
    END IF;

    SELECT chunk_id INTO nearest_chunk
    FROM public.embeddings
    ORDER BY embedding <=> '[1,0,0]'::vector
    LIMIT 1;

    IF nearest_chunk <> 1 THEN
        RAISE EXCEPTION 'cosine nearest chunk should be 1, got %', nearest_chunk;
    END IF;
END;
$$;
