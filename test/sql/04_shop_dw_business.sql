-- shop_dw 业务数据与规则测试

DO $$
DECLARE
    date_count integer;
    region_count integer;
    user_count integer;
    merchant_count integer;
    category_count integer;
    product_count integer;
    order_count integer;
    order_item_count integer;
    logistics_count integer;
    logistics_trace_count integer;
    payment_count integer;
    event_count integer;
    order_date_min integer;
    order_date_max integer;
    user1_address_count integer;
    home_phone_user_count integer;
    company_address_user_count integer;
    pair_phone_groups integer;
    triple_phone_groups integer;
    merchant_multi_category integer;
    required_categories integer;
    women_count integer;
    baby_count integer;
    men_count integer;
    furniture_count integer;
    promo_total_count integer;
    province_count integer;
    jzh_item_count integer;
    total_item_count integer;
    jzh_ratio numeric;
BEGIN
    SELECT count(*) INTO date_count FROM public.dim_date;
    IF date_count <> 1095 THEN
        RAISE EXCEPTION 'expected 1095 date rows, got %', date_count;
    END IF;

    SELECT count(*) INTO region_count FROM public.dim_region;
    SELECT count(*) INTO user_count FROM public.dim_user;
    SELECT count(*) INTO merchant_count FROM public.dim_merchant;
    SELECT count(*) INTO category_count FROM public.dim_category;
    SELECT count(*) INTO product_count FROM public.dim_product;
    SELECT count(*) INTO order_count FROM public.fact_order;
    SELECT count(*) INTO order_item_count FROM public.fact_order_item;
    SELECT count(*) INTO logistics_count FROM public.fact_logistics_order;
    SELECT count(*) INTO logistics_trace_count FROM public.fact_logistics_trace;
    SELECT count(*) INTO payment_count FROM public.fact_payment;
    SELECT count(*) INTO event_count FROM public.fact_app_event;

    IF region_count < 106 OR user_count < 213 OR merchant_count < 20
       OR category_count < 25 OR product_count < 44 THEN
        RAISE EXCEPTION 'extended dimension count mismatch: region=% user=% merchant=% category=% product=%',
            region_count, user_count, merchant_count, category_count, product_count;
    END IF;

    IF order_count < 20000 THEN
        RAISE EXCEPTION 'expected more than 20000 mock orders, got %', order_count;
    END IF;

    IF order_item_count <> order_count + 2 THEN
        RAISE EXCEPTION 'order item count should be order count plus 2 sample items: order=% item=%',
            order_count, order_item_count;
    END IF;

    IF logistics_count < 10000 OR logistics_trace_count < 20000 OR event_count < order_count THEN
        RAISE EXCEPTION 'extended fact count mismatch: logistics=% trace=% event=% order=%',
            logistics_count, logistics_trace_count, event_count, order_count;
    END IF;

    SELECT min(date_key), max(date_key) INTO order_date_min, order_date_max
    FROM public.fact_order;
    IF order_date_min <> 20250101 OR order_date_max > 20260910 THEN
        RAISE EXCEPTION 'mock order period mismatch: min=% max=%', order_date_min, order_date_max;
    END IF;

    SELECT count(DISTINCT oi.shipping_detail_address) INTO user1_address_count
    FROM public.fact_order_item oi
    JOIN public.fact_order o ON o.order_key = oi.order_key
    WHERE o.user_key = 1;
    IF user1_address_count < 3 THEN
        RAISE EXCEPTION 'user 1 should have at least 3 distinct addresses, got %', user1_address_count;
    END IF;

    SELECT count(DISTINCT o.user_key) INTO home_phone_user_count
    FROM public.fact_order_item oi
    JOIN public.fact_order o ON o.order_key = oi.order_key
    WHERE oi.recipient_phone = '13800001111';

    SELECT count(DISTINCT o.user_key) INTO company_address_user_count
    FROM public.fact_order_item oi
    JOIN public.fact_order o ON o.order_key = oi.order_key
    WHERE oi.shipping_detail_address = '张江高科技园区博云路2号 A座';

    IF company_address_user_count < 20 THEN
        RAISE EXCEPTION 'company shared address scenario mismatch: users=%', company_address_user_count;
    END IF;

    SELECT
        count(*) FILTER (WHERE phone_user_count = 2),
        count(*) FILTER (WHERE phone_user_count = 3)
    INTO pair_phone_groups, triple_phone_groups
    FROM (
        SELECT oi.recipient_phone, count(DISTINCT o.user_key) AS phone_user_count
        FROM public.fact_order_item oi
        JOIN public.fact_order o ON o.order_key = oi.order_key
        GROUP BY oi.recipient_phone
    ) phone_groups;

    IF pair_phone_groups < 10 OR triple_phone_groups < 5 THEN
        RAISE EXCEPTION 'shared phone group mismatch: pair=% triple=%',
            pair_phone_groups, triple_phone_groups;
    END IF;

    SELECT count(*) INTO merchant_multi_category
    FROM (
        SELECT merchant_key
        FROM public.dim_product
        GROUP BY merchant_key
        HAVING count(DISTINCT category_key) > 1
    ) multi_category_merchants;

    IF merchant_multi_category > 0 THEN
        RAISE EXCEPTION 'found % merchants operating multiple big categories', merchant_multi_category;
    END IF;

    SELECT count(*) INTO required_categories
    FROM public.dim_category
    WHERE category_name IN (
        '女装', '饰品', '护肤品', '彩妆', '鞋子', '包包',
        '童装', '玩具', '童鞋', '童书',
        '男装', '男鞋', '家具家电', '虚拟产品', '生鲜', '水果'
    );
    IF required_categories < 16 THEN
        RAISE EXCEPTION 'missing daily life categories, got %', required_categories;
    END IF;

    SELECT
        count(*) FILTER (WHERE p.category_key BETWEEN 9 AND 14),
        count(*) FILTER (WHERE p.category_key BETWEEN 15 AND 18),
        count(*) FILTER (WHERE p.category_key BETWEEN 19 AND 20),
        count(*) FILTER (WHERE p.category_key = 21)
    INTO women_count, baby_count, men_count, furniture_count
    FROM public.fact_order_item oi
    JOIN public.dim_product p ON p.product_key = oi.product_key;

    IF NOT (women_count > baby_count AND baby_count > men_count AND men_count > furniture_count) THEN
        RAISE EXCEPTION 'category order mismatch: women=% baby=% men=% furniture=%',
            women_count, baby_count, men_count, furniture_count;
    END IF;

    SELECT count(*) INTO promo_total_count
    FROM public.fact_order_item
    WHERE promotion_key IN (4, 5, 6, 7, 8);
    IF promo_total_count < 6000 THEN
        RAISE EXCEPTION 'promotion order count too low: %', promo_total_count;
    END IF;

    SELECT
        count(DISTINCT shipping_province_name),
        count(*) FILTER (WHERE shipping_region_key IN (4, 10, 94)),
        count(*)
    INTO province_count, jzh_item_count, total_item_count
    FROM public.fact_order_item;

    jzh_ratio := jzh_item_count::numeric / total_item_count;
    IF province_count < 31 OR jzh_ratio < 0.30 OR jzh_ratio > 0.80 THEN
        RAISE EXCEPTION 'region distribution mismatch: province=% jzh=% total=%',
            province_count, jzh_item_count, total_item_count;
    END IF;
END;
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM public.fact_order_item
        WHERE product_name_snapshot = 'HUAWEI Mate 70 Pro'
          AND category_path_snapshot = '手机数码/手机/5G手机'
          AND recipient_phone = '13812341234'
          AND is_shipped = true
    ) THEN
        RAISE EXCEPTION 'order item snapshot fields are incorrect';
    END IF;
END;
$$;

DO $$
BEGIN
    BEGIN
        INSERT INTO public.fact_app_event (
            event_id, date_key, user_key, channel_key,
            session_id, page_code, event_type, event_time
        )
        VALUES (
            'EV_BAD_USER_001', 20260901, 999999, 1,
            'SESS_BAD', 'product_detail', 'view_product', now()
        );
        RAISE EXCEPTION 'expected foreign key violation for invalid user_key';
    EXCEPTION
        WHEN foreign_key_violation THEN
            NULL;
    END;
END;
$$;

BEGIN;

DO $$
BEGIN
    IF (SELECT current_status FROM public.fact_logistics_order
        WHERE logistics_order_key = 2) <> 'in_transit' THEN
        RAISE EXCEPTION 'logistics current status is not in_transit before trace insert';
    END IF;

    INSERT INTO public.fact_logistics_trace (
        logistics_order_key,
        order_key,
        trace_status,
        trace_status_cn,
        trace_time,
        location_name,
        operator_name,
        trace_description
    )
    VALUES (
        2, 2, 'out_for_delivery', '派送中',
        '2026-09-05 09:00:00+08', '深圳南山',
        '圆通派送员', '快件正在派送中'
    );

    IF (SELECT current_status FROM public.fact_logistics_order
        WHERE logistics_order_key = 2) <> 'out_for_delivery' THEN
        RAISE EXCEPTION 'logistics current status was not synced by trigger';
    END IF;
END;
$$;

ROLLBACK;
