-- shop_dw 演示种子数据
-- 执行角色：shop_app，连接数据库：shop_dw

TRUNCATE TABLE
    public.dim_date,
    public.dim_region,
    public.dim_channel,
    public.dim_user,
    public.dim_category,
    public.dim_merchant,
    public.dim_product,
    public.dim_promotion,
    public.dim_payment_method,
    public.fact_order,
    public.fact_logistics_order,
    public.fact_logistics_trace,
    public.fact_order_item,
    public.fact_payment,
    public.fact_refund,
    public.fact_app_event
RESTART IDENTITY CASCADE;

-- 日期维：2025-01-01 至 2027-12-31
INSERT INTO public.dim_date (
    date_key,
    calendar_date,
    year,
    quarter,
    month,
    day,
    week_of_year,
    day_of_week,
    day_name_cn,
    is_weekend,
    is_holiday
)
SELECT
    (to_char(calendar_date, 'YYYYMMDD'))::integer,
    calendar_date,
    extract(year FROM calendar_date)::smallint,
    extract(quarter FROM calendar_date)::smallint,
    extract(month FROM calendar_date)::smallint,
    extract(day FROM calendar_date)::smallint,
    extract(week FROM calendar_date)::smallint,
    extract(isodow FROM calendar_date)::smallint,
    CASE extract(isodow FROM calendar_date)
        WHEN 1 THEN '周一'
        WHEN 2 THEN '周二'
        WHEN 3 THEN '周三'
        WHEN 4 THEN '周四'
        WHEN 5 THEN '周五'
        WHEN 6 THEN '周六'
        WHEN 7 THEN '周日'
    END,
    extract(isodow FROM calendar_date) IN (6, 7),
    false
FROM generate_series('2025-01-01'::date, '2027-12-31'::date, '1 day') AS calendar_date;

-- 地区维
INSERT INTO public.dim_region (
    region_key,
    region_code,
    region_name,
    region_type,
    parent_region_key,
    level,
    region_path
) OVERRIDING SYSTEM VALUE
VALUES
    (1, 'CN', '中国', 'country', NULL, 1, '中国'),
    (2, 'ZJ', '浙江省', 'province', 1, 2, '中国/浙江省'),
    (3, 'HZ', '杭州市', 'city', 2, 3, '中国/浙江省/杭州市'),
    (4, 'XH', '西湖区', 'district', 3, 4, '中国/浙江省/杭州市/西湖区'),
    (5, 'GD', '广东省', 'province', 1, 2, '中国/广东省'),
    (6, 'SZ', '深圳市', 'city', 5, 3, '中国/广东省/深圳市'),
    (7, 'NS', '南山区', 'district', 6, 4, '中国/广东省/深圳市/南山区'),
    (8, 'JS', '江苏省', 'province', 1, 2, '中国/江苏省'),
    (9, 'NJ', '南京市', 'city', 8, 3, '中国/江苏省/南京市'),
    (10, 'XW', '玄武区', 'district', 9, 4, '中国/江苏省/南京市/玄武区');

-- 渠道维
INSERT INTO public.dim_channel (
    channel_key,
    channel_code,
    channel_name,
    channel_type,
    platform,
    device_platform,
    is_paid
) OVERRIDING SYSTEM VALUE
VALUES
    (1, 'app_ios', 'iOS App', 'natural', 'Apple iOS', 'mobile', false),
    (2, 'app_android', 'Android App', 'natural', 'Android', 'mobile', false),
    (3, 'miniapp', '微信小程序', 'content', 'WeChat', 'mobile', false),
    (4, 'h5', 'H5 页面', 'paid', 'Web', 'h5', true),
    (5, 'live', '直播间', 'live', 'Android', 'mobile', false);

-- 用户维
INSERT INTO public.dim_user (
    user_key,
    user_id,
    nickname_masked,
    phone_masked,
    gender_code,
    age_group,
    member_level,
    default_region_key,
    register_channel_key,
    registration_date,
    status
) OVERRIDING SYSTEM VALUE
VALUES
    (1, 'U10001', '林**', '138****1234', 'M', '25-34', 'gold', 4, 2, '2025-03-01', 'active'),
    (2, 'U10002', '周**', '139****5678', 'F', '18-24', 'silver', 7, 1, '2025-06-15', 'active'),
    (3, 'U10003', '陈**', '137****9999', 'U', '35-44', 'normal', 10, 3, '2026-08-20', 'active');

-- 品类维
INSERT INTO public.dim_category (
    category_key,
    category_code,
    category_name,
    parent_category_key,
    category_level,
    sort_no
) OVERRIDING SYSTEM VALUE
VALUES
    (1, 'CAT_PHONE_DIGITAL', '手机数码', NULL, 1, 1),
    (2, 'CAT_PHONE', '手机', 1, 2, 10),
    (3, 'CAT_5G_PHONE', '5G手机', 2, 3, 100),
    (4, 'CAT_COMPUTER', '电脑办公', NULL, 1, 2),
    (5, 'CAT_LAPTOP', '笔记本电脑', 4, 2, 10),
    (6, 'CAT_ULTRABOOK', '轻薄本', 5, 3, 100),
    (7, 'CAT_HOME_APPLIANCE', '家用电器', NULL, 1, 3),
    (8, 'CAT_FRIDGE', '冰箱', 7, 2, 10);

-- 商家维
INSERT INTO public.dim_merchant (
    merchant_key,
    merchant_id,
    merchant_name,
    merchant_type,
    merchant_level,
    region_key,
    service_score,
    opened_at,
    status
) OVERRIDING SYSTEM VALUE
VALUES
    (1, 'M1001', '华为官方旗舰店', 'flagship', 'S', 4, 4.90, '2025-01-01', true),
    (2, 'M1002', '苹果官方旗舰店', 'flagship', 'S', 7, 4.95, '2025-01-15', true),
    (3, 'M1003', '联想电脑专卖店', 'specialty', 'A', 10, 4.70, '2025-02-01', true);

-- 商品维
INSERT INTO public.dim_product (
    product_key,
    product_id,
    sku_code,
    product_name,
    brand,
    spec,
    category_key,
    merchant_key,
    reference_price,
    cost_price,
    shelf_status,
    on_shelf_at
) OVERRIDING SYSTEM VALUE
VALUES
    (1, 'P10001', 'SKU-HW-7001', 'HUAWEI Mate 70 Pro', '华为', '曜石黑 256G', 3, 1, 6999.00, 5200.00, 'on', '2025-09-10'),
    (2, 'P10002', 'SKU-AP-1501', 'iPhone 15 Pro Max', 'Apple', '原色钛金属 256G', 3, 2, 9999.00, 7800.00, 'on', '2025-09-20'),
    (3, 'P10003', 'SKU-LX-1601', '联想小新 Pro 16', '联想', '锐龙版 32G 1T', 6, 3, 6499.00, 5600.00, 'on', '2025-11-01'),
    (4, 'P10004', 'SKU-MD-2101', '美的 508L 冰箱', '美的', '灰色 508L', 8, 3, 3999.00, 3000.00, 'on', '2025-12-01');

-- 促销维
INSERT INTO public.dim_promotion (
    promotion_key,
    promotion_id,
    promotion_name,
    promotion_type,
    discount_type,
    discount_value,
    start_at,
    end_at,
    status
) OVERRIDING SYSTEM VALUE
VALUES
    (1, 'PR001', '品牌券满 9999 减 998', 'coupon', 'amount', 998.00, '2026-08-18 00:00:00+08', '2026-09-18 23:59:59+08', 'running'),
    (2, 'PR002', '直播间立减 200', 'live', 'amount', 200.00, '2026-09-01 00:00:00+08', '2026-09-30 23:59:59+08', 'running'),
    (3, 'PR003', '新用户立减 10 元', 'new_user', 'amount', 10.00, '2026-01-01 00:00:00+08', '2026-12-31 23:59:59+08', 'running');

-- 支付方式维
INSERT INTO public.dim_payment_method (
    payment_method_key,
    method_code,
    method_name,
    provider,
    supported_platform
) OVERRIDING SYSTEM VALUE
VALUES
    (1, 'wechat_pay', '微信支付', 'Tencent', 'iOS/Android/MiniProgram'),
    (2, 'alipay', '支付宝', 'Alipay', 'iOS/Android'),
    (3, 'apple_pay', 'Apple Pay', 'Apple', 'iOS'),
    (4, 'bank_card', '银行卡', 'UnionPay', 'iOS/Android');

-- 订单头
INSERT INTO public.fact_order (
    order_key,
    order_no,
    date_key,
    user_key,
    channel_key,
    shipping_region_key,
    promotion_key,
    order_status,
    is_shipped,
    goods_amount,
    discount_amount,
    freight_amount,
    pay_amount,
    item_count,
    order_created_at,
    paid_at,
    received_at,
    cancelled_at,
    completed_at
) OVERRIDING SYSTEM VALUE
VALUES
    (1, 'SO20260901001', 20260901, 1, 2, 4, 1, 'completed', true, 16998.00, 998.00, 0.00, 16000.00, 2,
     '2026-09-01 10:20:00+08', '2026-09-01 10:25:00+08', '2026-09-03 10:30:00+08', NULL, '2026-09-03 10:32:00+08'),
    (2, 'SO20260902001', 20260902, 2, 1, 7, NULL, 'shipped', true, 6499.00, 0.00, 0.00, 6499.00, 1,
     '2026-09-02 15:00:00+08', '2026-09-02 15:05:00+08', NULL, NULL, NULL),
    (3, 'SO20260903001', 20260903, 3, 3, 10, 3, 'pending_payment', false, 7998.00, 10.00, 30.00, 8018.00, 2,
     '2026-09-03 09:00:00+08', NULL, NULL, NULL, NULL);

-- 物流运单
INSERT INTO public.fact_logistics_order (
    logistics_order_key,
    logistics_no,
    order_key,
    logistics_company,
    current_status,
    current_status_time,
    shipped_at,
    signed_at,
    expected_arrival_at
) OVERRIDING SYSTEM VALUE
VALUES
    (1, 'SF202609011234', 1, '顺丰速运', 'signed', '2026-09-03 10:30:00+08', '2026-09-01 11:00:00+08', '2026-09-03 10:30:00+08', '2026-09-03 18:00:00+08'),
    (2, 'YT202609025678', 2, '圆通速递', 'in_transit', '2026-09-04 09:00:00+08', '2026-09-03 12:00:00+08', NULL, '2026-09-06 18:00:00+08');

-- 物流状态流水
INSERT INTO public.fact_logistics_trace (
    logistics_trace_key,
    logistics_order_key,
    order_key,
    trace_status,
    trace_status_cn,
    trace_time,
    location_name,
    operator_name,
    signed_name,
    trace_description
) OVERRIDING SYSTEM VALUE
VALUES
    (1, 1, 1, 'shipped', '已发货', '2026-09-01 11:00:00+08', '杭州西湖集散中心', '顺丰杭州', NULL, '商家已发货，顺丰已揽收'),
    (2, 1, 1, 'in_transit', '运输中', '2026-09-02 08:30:00+08', '杭州转运中心', '顺丰杭州转运', NULL, '快件已到达杭州转运中心'),
    (3, 1, 1, 'signed', '已签收', '2026-09-03 10:30:00+08', '杭州西湖区', '顺丰派送员', '林**', '快件已由本人签收'),
    (4, 2, 2, 'shipped', '已发货', '2026-09-03 12:00:00+08', '深圳南山集散中心', '圆通深圳', NULL, '商家已发货，圆通已揽收'),
    (5, 2, 2, 'in_transit', '运输中', '2026-09-04 09:00:00+08', '深圳转运中心', '圆通深圳转运', NULL, '快件已到达深圳转运中心');

-- 订单明细
INSERT INTO public.fact_order_item (
    order_item_key,
    order_key,
    order_item_no,
    date_key,
    product_key,
    merchant_key,
    promotion_key,
    quantity,
    unit_price,
    discount_amount,
    item_amount,
    item_status,
    order_status,
    paid_at,
    received_at,
    is_shipped,
    shipping_region_key,
    shipping_province_name,
    shipping_city_name,
    shipping_district_name,
    shipping_detail_address,
    recipient_name,
    recipient_phone,
    product_name_snapshot,
    category_path_snapshot,
    logistics_order_key
) OVERRIDING SYSTEM VALUE
VALUES
    (1, 1, '001', 20260901, 1, 1, NULL, 1, 6999.00, 0.00, 6999.00, 'normal', 'completed',
     '2026-09-01 10:25:00+08', '2026-09-03 10:30:00+08', true, 4,
     '浙江省', '杭州市', '西湖区', '文一西路 100 号 1 幢 201', '林**', '13812341234',
     'HUAWEI Mate 70 Pro', '手机数码/手机/5G手机', 1),
    (2, 1, '002', 20260901, 2, 2, 1, 1, 9999.00, 0.00, 9999.00, 'refunded', 'completed',
     '2026-09-01 10:25:00+08', '2026-09-03 10:30:00+08', true, 4,
     '浙江省', '杭州市', '西湖区', '文一西路 100 号 1 幢 201', '林**', '13812341234',
     'iPhone 15 Pro Max', '手机数码/手机/5G手机', 1),
    (3, 2, '001', 20260902, 3, 3, NULL, 1, 6499.00, 0.00, 6499.00, 'normal', 'shipped',
     '2026-09-02 15:05:00+08', NULL, true, 7,
     '广东省', '深圳市', '南山区', '科技南路 88 号', '周**', '13912345678',
     '联想小新 Pro 16', '电脑办公/笔记本电脑/轻薄本', 2),
    (4, 3, '001', 20260903, 4, 3, 3, 1, 3999.00, 0.00, 3999.00, 'normal', 'pending_payment',
     NULL, NULL, false, 10,
     '江苏省', '南京市', '玄武区', '中山路 188 号', '陈**', '13712349999',
     '美的 508L 冰箱', '家用电器/冰箱', NULL),
    (5, 3, '002', 20260903, 4, 3, 3, 1, 3999.00, 10.00, 3989.00, 'normal', 'pending_payment',
     NULL, NULL, false, 10,
     '江苏省', '南京市', '玄武区', '中山路 188 号', '陈**', '13712349999',
     '美的 508L 冰箱', '家用电器/冰箱', NULL);

-- 支付记录
INSERT INTO public.fact_payment (
    payment_key,
    payment_no,
    order_key,
    date_key,
    payment_method_key,
    pay_amount,
    payment_status,
    payment_started_at,
    payment_finished_at,
    payment_trade_no
) OVERRIDING SYSTEM VALUE
VALUES
    (1, 'PAY20260901001', 1, 20260901, 1, 16000.00, 'refunded',
     '2026-09-01 10:25:00+08', '2026-09-01 10:25:30+08', 'WX2026090112345678'),
    (2, 'PAY20260902001', 2, 20260902, 2, 6499.00, 'success',
     '2026-09-02 15:05:00+08', '2026-09-02 15:05:20+08', 'ALI2026090212345678');

-- 退款记录
INSERT INTO public.fact_refund (
    refund_key,
    refund_no,
    order_key,
    order_item_key,
    payment_key,
    date_key,
    user_key,
    refund_type,
    refund_reason_code,
    refund_reason,
    refund_amount,
    refund_status,
    applied_at,
    finished_at
) OVERRIDING SYSTEM VALUE
VALUES
    (1, 'RF20260904001', 1, 2, 1, 20260904, 1, 'item_only', 'NOT_AS_DESCRIBED',
     '商品与描述不符', 9999.00, 'refunded', '2026-09-04 09:00:00+08', '2026-09-04 14:00:00+08');

-- App 行为事件
INSERT INTO public.fact_app_event (
    event_key,
    event_id,
    date_key,
    user_key,
    channel_key,
    region_key,
    product_key,
    order_key,
    session_id,
    page_code,
    event_type,
    event_time,
    payload
) OVERRIDING SYSTEM VALUE
VALUES
    (1, 'EV202609010001', 20260901, 1, 2, 4, 1, NULL, 'SESS000001', 'product_detail', 'view_product',
     '2026-09-01 09:58:00+08', '{"source": "search"}'),
    (2, 'EV202609010002', 20260901, 1, 2, 4, NULL, 1, 'SESS000001', 'order_confirm', 'submit_order',
     '2026-09-01 10:20:00+08', '{"order_no": "SO20260901001"}'),
    (3, 'EV202609020001', 20260902, 2, 1, 7, 3, NULL, 'SESS000002', 'product_detail', 'add_cart',
     '2026-09-02 14:30:00+08', '{"quantity": 1}'),
    (4, 'EV202609020002', 20260902, 2, 1, 7, NULL, 2, 'SESS000002', 'order_confirm', 'pay_success',
     '2026-09-02 15:05:20+08', '{"order_no": "SO20260902001"}'),
    (5, 'EV202609030001', 20260903, 3, 3, 10, NULL, NULL, 'SESS000003', 'search_result', 'search',
     '2026-09-03 08:50:00+08', '{"keyword": "冰箱"}'),
    (6, 'EV202609030002', 20260903, 3, 3, 10, NULL, 3, 'SESS000003', 'order_confirm', 'submit_order',
     '2026-09-03 09:00:00+08', '{"order_no": "SO20260903001"}');

-- 扩展用户 mock 数据
INSERT INTO public.dim_user (
    user_key,
    user_id,
    nickname_masked,
    phone_masked,
    gender_code,
    age_group,
    member_level,
    default_region_key,
    register_channel_key,
    registration_date,
    status
) OVERRIDING SYSTEM VALUE
SELECT
    3 + i,
    'U2000' || lpad((3 + i)::text, 4, '0'),
    '用户' || (3 + i),
    '13' || lpad((10000000 + i)::text, 8, '0'),
    CASE i % 3 WHEN 0 THEN 'M' WHEN 1 THEN 'F' ELSE 'U' END,
    CASE i % 4 WHEN 0 THEN '18-24' WHEN 1 THEN '25-34'
               WHEN 2 THEN '35-44' ELSE '45+' END,
    CASE i % 3 WHEN 0 THEN 'gold' WHEN 1 THEN 'silver' ELSE 'normal' END,
    CASE i % 3 WHEN 0 THEN 4 WHEN 1 THEN 7 ELSE 10 END,
    1 + (i % 5),
    date '2026-01-01' + (i % 200),
    'active'
FROM generate_series(1, 10) AS i;

-- 扩展商品 mock 数据
INSERT INTO public.dim_product (
    product_key,
    product_id,
    sku_code,
    product_name,
    brand,
    spec,
    category_key,
    merchant_key,
    reference_price,
    cost_price,
    shelf_status,
    on_shelf_at
) OVERRIDING SYSTEM VALUE
VALUES
    (5, 'P20001', 'SKU-XM-1501', 'Xiaomi 15', '小米', '白色 12G 256G', 3, 1, 4299.00, 3600.00, 'on', '2026-01-10'),
    (6, 'P20002', 'SKU-OP-8001', 'OPPO Find X8', 'OPPO', '蓝色 12G 256G', 3, 1, 4499.00, 3800.00, 'on', '2026-02-01'),
    (7, 'P20003', 'SKU-HW-9001', 'HUAWEI MateBook X Pro', '华为', '深空灰 16G 1T', 6, 1, 8999.00, 7600.00, 'on', '2026-03-01'),
    (8, 'P20004', 'SKU-LX-9001', '联想拯救者 Y9000P', '联想', '钛晶灰 32G 1T', 5, 3, 8499.00, 7200.00, 'on', '2026-03-15'),
    (9, 'P20005', 'SKU-MD-2201', '美的 325L 冰吧', '美的', '银灰色 325L', 8, 3, 2999.00, 2200.00, 'on', '2026-04-01'),
    (10, 'P20006', 'SKU-HR-5001', '海尔 501L 冰箱', '海尔', '晶彩 501L', 8, 3, 4699.00, 3500.00, 'on', '2026-04-10');

-- 批量生成 2026 年 8 月订单 mock 数据
DO $$
DECLARE
    i integer;
    v_order_key bigint;
    v_order_no varchar(64);
    v_date_key integer;
    v_user_key bigint;
    v_channel_key bigint;
    v_region_key bigint;
    v_promotion_key bigint;
    v_product_key bigint;
    v_merchant_key bigint;
    v_product_name varchar(255);
    v_category_path varchar(255);
    v_price numeric(12,2);
    v_status varchar(16);
    v_quantity integer;
    v_goods_amount numeric(12,2);
    v_discount_amount numeric(12,2);
    v_freight_amount numeric(12,2);
    v_pay_amount numeric(12,2);
    v_order_created_at timestamptz;
    v_paid_at timestamptz;
    v_received_at timestamptz;
    v_logistics_key bigint;
BEGIN
    FOR i IN 1..40 LOOP
        v_order_key := 3 + i;
        v_order_no := 'MO202608' || lpad(i::text, 4, '0');
        v_date_key := (to_char(date '2026-08-01' + (i % 29), 'YYYYMMDD'))::integer;
        v_user_key := 1 + (i % 13);
        v_channel_key := 1 + (i % 5);
        v_region_key := CASE i % 3 WHEN 0 THEN 4 WHEN 1 THEN 7 ELSE 10 END;
        v_promotion_key := CASE WHEN i % 2 = 0 THEN 1 + (i % 3) ELSE NULL END;
        v_product_key := 1 + (i % 10);
        v_quantity := 1 + (i % 3);

        SELECT merchant_key, reference_price
        INTO v_merchant_key, v_price
        FROM public.dim_product
        WHERE product_key = v_product_key;

        v_product_name := (
            SELECT product_name
            FROM public.dim_product
            WHERE product_key = v_product_key
        );

        v_category_path := CASE
            WHEN v_product_key IN (1, 2, 5, 6) THEN '手机数码/手机/5G手机'
            WHEN v_product_key = 3 THEN '电脑办公/笔记本电脑/轻薄本'
            WHEN v_product_key = 4 THEN '家用电器/冰箱'
            WHEN v_product_key = 7 THEN '电脑办公/笔记本电脑/轻薄本'
            WHEN v_product_key = 8 THEN '电脑办公/笔记本电脑'
            ELSE '家用电器/冰箱'
        END;

        IF i % 6 = 0 THEN
            v_status := 'completed';
        ELSIF i % 6 = 1 THEN
            v_status := 'shipped';
        ELSIF i % 6 = 2 THEN
            v_status := 'paid';
        ELSIF i % 6 = 3 THEN
            v_status := 'cancelled';
        ELSE
            v_status := 'pending_payment';
        END IF;

        v_discount_amount := CASE WHEN v_promotion_key IS NOT NULL THEN 50.00 ELSE 0.00 END;
        v_freight_amount := CASE WHEN v_product_key IN (4, 9, 10) THEN 20.00 ELSE 0.00 END;
        v_goods_amount := round(v_price * v_quantity, 2) - v_discount_amount;
        v_pay_amount := v_goods_amount + v_freight_amount;
        v_order_created_at := (date '2026-08-01' + (i % 29))::timestamptz + interval '1 hour' + (i % 12) * interval '30 minute';
        v_paid_at := CASE
            WHEN v_status IN ('paid', 'shipped', 'completed') THEN v_order_created_at + interval '5 minute'
            ELSE NULL
        END;
        v_received_at := CASE WHEN v_status = 'completed' THEN v_order_created_at + interval '2 day' ELSE NULL END;

        INSERT INTO public.fact_order (
            order_key,
            order_no,
            date_key,
            user_key,
            channel_key,
            shipping_region_key,
            promotion_key,
            order_status,
            is_shipped,
            goods_amount,
            discount_amount,
            freight_amount,
            pay_amount,
            item_count,
            order_created_at,
            paid_at,
            received_at,
            cancelled_at,
            completed_at
        ) OVERRIDING SYSTEM VALUE
        VALUES (
            v_order_key,
            v_order_no,
            v_date_key,
            v_user_key,
            v_channel_key,
            v_region_key,
            v_promotion_key,
            v_status,
            v_status IN ('shipped', 'completed'),
            round(v_price * v_quantity, 2),
            v_discount_amount,
            v_freight_amount,
            v_pay_amount,
            v_quantity,
            v_order_created_at,
            v_paid_at,
            v_received_at,
            CASE WHEN v_status = 'cancelled' THEN v_order_created_at + interval '1 hour' ELSE NULL END,
            CASE WHEN v_status = 'completed' THEN v_received_at + interval '2 minute' ELSE NULL END
        );

        v_logistics_key := NULL;
        IF v_status IN ('shipped', 'completed') THEN
            v_logistics_key := 100 + i;
            INSERT INTO public.fact_logistics_order (
                logistics_order_key,
                logistics_no,
                order_key,
                logistics_company,
                current_status,
                current_status_time,
                shipped_at,
                signed_at,
                expected_arrival_at
            ) OVERRIDING SYSTEM VALUE
            VALUES (
                v_logistics_key,
                'MOCKLOG' || lpad(i::text, 6, '0'),
                v_order_key,
                CASE i % 3 WHEN 0 THEN '顺丰速运' WHEN 1 THEN '圆通速递' ELSE '中通快递' END,
                CASE WHEN v_status = 'completed' THEN 'signed' ELSE 'in_transit' END,
                CASE WHEN v_status = 'completed' THEN v_order_created_at + interval '2 day'
                     ELSE v_order_created_at + interval '1 day' END,
                v_order_created_at + interval '6 hour',
                CASE WHEN v_status = 'completed' THEN v_order_created_at + interval '2 day' ELSE NULL END,
                v_order_created_at + interval '3 day'
            );

            INSERT INTO public.fact_logistics_trace (
                logistics_trace_key,
                logistics_order_key,
                order_key,
                trace_status,
                trace_status_cn,
                trace_time,
                location_name,
                operator_name,
                signed_name,
                trace_description
            ) OVERRIDING SYSTEM VALUE
            VALUES (
                1000 + i,
                v_logistics_key,
                v_order_key,
                'shipped',
                '已发货',
                v_order_created_at + interval '6 hour',
                '发货仓库',
                '仓库操作员',
                NULL,
                '商家已发货，快递已揽收'
            );

            INSERT INTO public.fact_logistics_trace (
                logistics_trace_key,
                logistics_order_key,
                order_key,
                trace_status,
                trace_status_cn,
                trace_time,
                location_name,
                operator_name,
                signed_name,
                trace_description
            ) OVERRIDING SYSTEM VALUE
            VALUES (
                2000 + i,
                v_logistics_key,
                v_order_key,
                CASE WHEN v_status = 'completed' THEN 'signed' ELSE 'in_transit' END,
                CASE WHEN v_status = 'completed' THEN '已签收' ELSE '运输中' END,
                CASE WHEN v_status = 'completed' THEN v_order_created_at + interval '2 day'
                     ELSE v_order_created_at + interval '1 day' END,
                CASE v_region_key WHEN 4 THEN '杭州转运中心' WHEN 7 THEN '深圳转运中心' ELSE '南京转运中心' END,
                '物流网点',
                CASE WHEN v_status = 'completed' THEN '用户本人' ELSE NULL END,
                CASE WHEN v_status = 'completed' THEN '快件已由本人签收' ELSE '快件正在运输中' END
            );
        END IF;

        INSERT INTO public.fact_order_item (
            order_item_key,
            order_key,
            order_item_no,
            date_key,
            product_key,
            merchant_key,
            promotion_key,
            quantity,
            unit_price,
            discount_amount,
            item_amount,
            item_status,
            order_status,
            paid_at,
            received_at,
            is_shipped,
            shipping_region_key,
            shipping_province_name,
            shipping_city_name,
            shipping_district_name,
            shipping_detail_address,
            recipient_name,
            recipient_phone,
            product_name_snapshot,
            category_path_snapshot,
            logistics_order_key
        ) OVERRIDING SYSTEM VALUE
        VALUES (
            1000 + i,
            v_order_key,
            '001',
            v_date_key,
            v_product_key,
            v_merchant_key,
            v_promotion_key,
            v_quantity,
            v_price,
            v_discount_amount,
            v_goods_amount,
            'normal',
            v_status,
            v_paid_at,
            v_received_at,
            v_status IN ('shipped', 'completed'),
            v_region_key,
            CASE v_region_key WHEN 4 THEN '浙江省' WHEN 7 THEN '广东省' ELSE '江苏省' END,
            CASE v_region_key WHEN 4 THEN '杭州市' WHEN 7 THEN '深圳市' ELSE '南京市' END,
            CASE v_region_key WHEN 4 THEN '西湖区' WHEN 7 THEN '南山区' ELSE '玄武区' END,
            CASE v_region_key WHEN 4 THEN '文三路' || i || '号'
                              WHEN 7 THEN '高新南' || i || '道'
                              ELSE '中山东路' || i || '号' END,
            '收件人' || (1 + (i % 13)),
            '13' || lpad((20000000 + i)::text, 8, '0'),
            v_product_name,
            v_category_path,
            v_logistics_key
        );

        IF v_status IN ('paid', 'shipped', 'completed') THEN
            INSERT INTO public.fact_payment (
                payment_key,
                payment_no,
                order_key,
                date_key,
                payment_method_key,
                pay_amount,
                payment_status,
                payment_started_at,
                payment_finished_at,
                payment_trade_no
            ) OVERRIDING SYSTEM VALUE
            VALUES (
                200 + i,
                'MOCKPAY' || lpad(i::text, 6, '0'),
                v_order_key,
                v_date_key,
                1 + (i % 4),
                v_pay_amount,
                'success',
                v_paid_at,
                v_paid_at + interval '30 second',
                'MOCKTRADE' || lpad(i::text, 10, '0')
            );
        END IF;

        INSERT INTO public.fact_app_event (
            event_key,
            event_id,
            date_key,
            user_key,
            channel_key,
            region_key,
            product_key,
            order_key,
            session_id,
            page_code,
            event_type,
            event_time,
            payload
        ) OVERRIDING SYSTEM VALUE
        VALUES (
            500 + i,
            'MOCKEV' || lpad(i::text, 10, '0'),
            v_date_key,
            v_user_key,
            v_channel_key,
            v_region_key,
            v_product_key,
            v_order_key,
            'MOCKSESS' || lpad(i::text, 8, '0'),
            'order_confirm',
            'submit_order',
            v_order_created_at,
            jsonb_build_object('order_no', v_order_no)
        );
    END LOOP;
END;
$$;

-- 将所有显式插入的自增键同步到当前序列
DO $$
DECLARE
    col_record record;
BEGIN
    FOR col_record IN
        SELECT table_schema, table_name, column_name
        FROM information_schema.columns
        WHERE is_identity = 'YES'
    LOOP
        EXECUTE format(
            'SELECT setval(pg_get_serial_sequence(%L, %L), (SELECT max(%I) FROM %I.%I))',
            format('%I.%I', col_record.table_schema, col_record.table_name),
            col_record.column_name,
            col_record.column_name,
            col_record.table_schema,
            col_record.table_name
        );
    END LOOP;
END;
$$;
