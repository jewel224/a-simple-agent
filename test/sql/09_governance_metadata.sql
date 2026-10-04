-- 治理语义层元数据与向量索引验收

DO $$
DECLARE
    table_count bigint;
    column_count bigint;
    restricted_count bigint;
    metric_count bigint;
    example_count bigint;
    index_count bigint;
    table_missing bigint;
    column_missing bigint;
    metric_missing bigint;
    example_missing bigint;
BEGIN
    SELECT COUNT(*) INTO table_count FROM governance.table_metadata WHERE table_name LIKE 'dim\_%' ESCAPE '\' OR table_name LIKE 'fact\_%' ESCAPE '\';
    SELECT COUNT(*) INTO column_count FROM governance.column_metadata;
    SELECT COUNT(*) INTO restricted_count FROM governance.column_metadata WHERE sensitive_level = 'restricted';
    SELECT COUNT(*) INTO metric_count FROM governance.metric_metadata;
    SELECT COUNT(*) INTO example_count FROM governance.query_example;
    SELECT COUNT(*) INTO index_count FROM pg_indexes WHERE schemaname = 'governance' AND indexdef LIKE '%hnsw%';
    SELECT COUNT(*) INTO table_missing FROM governance.table_metadata WHERE embedding IS NULL;
    SELECT COUNT(*) INTO column_missing FROM governance.column_metadata WHERE embedding IS NULL;
    SELECT COUNT(*) INTO metric_missing FROM governance.metric_metadata WHERE embedding IS NULL;
    SELECT COUNT(*) INTO example_missing FROM governance.query_example WHERE embedding IS NULL;

    IF table_count < 16 THEN
        RAISE EXCEPTION 'table_metadata 数量不足: %', table_count;
    END IF;
    IF column_count < 100 THEN
        RAISE EXCEPTION 'column_metadata 数量不足: %', column_count;
    END IF;
    IF restricted_count <> 3 THEN
        RAISE EXCEPTION 'restricted 字段元数据数量应为 3，当前: %', restricted_count;
    END IF;
    IF metric_count < 5 THEN
        RAISE EXCEPTION 'metric_metadata 数量不足: %', metric_count;
    END IF;
    IF example_count < 4 THEN
        RAISE EXCEPTION 'query_example 数量不足: %', example_count;
    END IF;
    IF index_count <> 4 THEN
        RAISE EXCEPTION 'governance HNSW 索引数量应为 4，当前: %', index_count;
    END IF;
    IF table_missing <> 0 THEN
        RAISE EXCEPTION 'table_metadata 存在 % 条缺失向量的元数据', table_missing;
    END IF;
    IF column_missing <> 0 THEN
        RAISE EXCEPTION 'column_metadata 存在 % 条缺失向量的元数据', column_missing;
    END IF;
    IF metric_missing <> 0 THEN
        RAISE EXCEPTION 'metric_metadata 存在 % 条缺失向量的元数据', metric_missing;
    END IF;
    IF example_missing <> 0 THEN
        RAISE EXCEPTION 'query_example 存在 % 条缺失向量的元数据', example_missing;
    END IF;
END
$$;

SELECT
    (SELECT COUNT(*) FROM governance.table_metadata) AS table_metadata_count,
    (SELECT COUNT(*) FROM governance.column_metadata) AS column_metadata_count,
    (SELECT COUNT(*) FROM governance.metric_metadata) AS metric_metadata_count,
    (SELECT COUNT(*) FROM governance.query_example) AS query_example_count,
    (SELECT COUNT(*) FROM governance.table_metadata WHERE embedding IS NULL) AS table_metadata_missing,
    (SELECT COUNT(*) FROM governance.column_metadata WHERE embedding IS NULL) AS column_metadata_missing,
    (SELECT COUNT(*) FROM governance.metric_metadata WHERE embedding IS NULL) AS metric_metadata_missing,
    (SELECT COUNT(*) FROM governance.query_example WHERE embedding IS NULL) AS query_example_missing;
