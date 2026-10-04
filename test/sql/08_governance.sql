-- 治理版业务库权限与脱敏验收

DO $$
BEGIN
    -- 只读角色禁止执行任何写入、变更或管理操作
    BEGIN
        EXECUTE 'INSERT INTO public.dim_date (date_key) VALUES (-1)';
        RAISE EXCEPTION 'shop_ro 不应拥有 INSERT 权限';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'INSERT denied as expected';
    END;

    BEGIN
        EXECUTE 'UPDATE public.dim_date SET year = 2025 WHERE date_key = 20250101';
        RAISE EXCEPTION 'shop_ro 不应拥有 UPDATE 权限';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'UPDATE denied as expected';
    END;

    BEGIN
        EXECUTE 'DELETE FROM public.dim_date WHERE date_key = -1';
        RAISE EXCEPTION 'shop_ro 不应拥有 DELETE 权限';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'DELETE denied as expected';
    END;

    BEGIN
        EXECUTE 'DROP TABLE public.dim_date';
        RAISE EXCEPTION 'shop_ro 不应拥有 DROP 权限';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'DROP denied as expected';
    END;

    BEGIN
        EXECUTE 'TRUNCATE TABLE public.dim_date';
        RAISE EXCEPTION 'shop_ro 不应拥有 TRUNCATE 权限';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'TRUNCATE denied as expected';
    END;

    -- 敏感字段不能被直接读取
    BEGIN
        EXECUTE 'SELECT recipient_name FROM public.fact_order_item LIMIT 1';
        RAISE EXCEPTION 'shop_ro 不应读取 recipient_name';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'recipient_name denied as expected';
    END;

    BEGIN
        EXECUTE 'SELECT recipient_phone FROM public.fact_order_item LIMIT 1';
        RAISE EXCEPTION 'shop_ro 不应读取 recipient_phone';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'recipient_phone denied as expected';
    END;

    BEGIN
        EXECUTE 'SELECT shipping_detail_address FROM public.fact_order_item LIMIT 1';
        RAISE EXCEPTION 'shop_ro 不应读取 shipping_detail_address';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'shipping_detail_address denied as expected';
    END;
END
$$;

-- 常规安全字段可读
SELECT COUNT(*) AS order_item_count FROM public.fact_order_item;

-- 脱敏视图可读且脱敏格式正确
SELECT
    COUNT(*) AS masked_row_count,
    COUNT(*) FILTER (WHERE recipient_name_masked IS NOT NULL AND recipient_name_masked NOT LIKE '_*%') AS bad_name_mask,
    COUNT(*) FILTER (WHERE recipient_phone_masked IS NOT NULL AND recipient_phone_masked !~ '^\d{3}\*{4}\d{4}$') AS bad_phone_mask,
    COUNT(*) FILTER (WHERE shipping_detail_address_masked IS NOT NULL AND right(shipping_detail_address_masked, 4) <> '****') AS bad_address_mask
FROM public.v_fact_order_item_masked;

DO $$
DECLARE
    bad_count bigint;
BEGIN
    SELECT
        COUNT(*) FILTER (WHERE recipient_name_masked IS NOT NULL AND recipient_name_masked NOT LIKE '_*%')
        + COUNT(*) FILTER (WHERE recipient_phone_masked IS NOT NULL AND recipient_phone_masked !~ '^\d{3}\*{4}\d{4}$')
        + COUNT(*) FILTER (WHERE shipping_detail_address_masked IS NOT NULL AND right(shipping_detail_address_masked, 4) <> '****')
    INTO bad_count
    FROM public.v_fact_order_item_masked;

    IF bad_count <> 0 THEN
        RAISE EXCEPTION '脱敏结果不符合规则，异常行数: %', bad_count;
    END IF;
END
$$;

