-- shop_dw 结构测试

DO $$
DECLARE
    table_count integer;
    expected_missing integer;
BEGIN
    SELECT count(*) INTO table_count
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_type = 'BASE TABLE';

    IF table_count <> 16 THEN
        RAISE EXCEPTION 'expected 16 shop_dw tables, got %', table_count;
    END IF;

    SELECT count(*) INTO expected_missing
    FROM (
        SELECT unnest(ARRAY[
            'dim_date', 'dim_region', 'dim_channel', 'dim_user',
            'dim_category', 'dim_merchant', 'dim_product',
            'dim_promotion', 'dim_payment_method',
            'fact_order', 'fact_order_item', 'fact_payment',
            'fact_refund', 'fact_app_event',
            'fact_logistics_order', 'fact_logistics_trace'
        ]) AS table_name
        EXCEPT
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
    ) missing_tables;

    IF expected_missing <> 0 THEN
        RAISE EXCEPTION 'shop_dw missing % expected tables', expected_missing;
    END IF;
END;
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE constraint_schema = 'public'
          AND table_name = 'fact_order_item'
          AND constraint_type = 'FOREIGN KEY'
          AND constraint_name = 'fk_fact_order_item_logistics'
    ) THEN
        RAISE EXCEPTION 'fact_order_item.logistics_order_key foreign key not found';
    END IF;
END;
$$;
