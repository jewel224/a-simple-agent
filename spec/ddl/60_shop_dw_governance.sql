-- v2 业务库治理对象：只读授权与脱敏视图
-- 执行角色：shop_app，连接数据库：shop_dw

GRANT USAGE ON SCHEMA public TO shop_ro;

-- 维度表和普通事实表直接授予只读权限
GRANT SELECT ON
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
    public.fact_payment,
    public.fact_refund,
    public.fact_app_event,
    public.fact_logistics_order,
    public.fact_logistics_trace
TO shop_ro;

-- 订单明细表包含敏感收货信息，只授予非敏感字段
GRANT SELECT (
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
    product_name_snapshot,
    category_path_snapshot,
    logistics_order_key
) ON public.fact_order_item TO shop_ro;

-- 脱敏视图暴露收件人、手机号与详细地址
CREATE OR REPLACE VIEW public.v_fact_order_item_masked AS
SELECT
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
    CASE
        WHEN recipient_name IS NULL THEN NULL
        ELSE left(recipient_name, 1) || repeat('*', greatest(length(recipient_name) - 1, 0))
    END AS recipient_name_masked,
    CASE
        WHEN recipient_phone IS NULL THEN NULL
        ELSE left(recipient_phone, 3) || '****' || right(recipient_phone, 4)
    END AS recipient_phone_masked,
    CASE
        WHEN shipping_detail_address IS NULL THEN NULL
        ELSE left(shipping_detail_address, 6) || '****'
    END AS shipping_detail_address_masked,
    product_name_snapshot,
    category_path_snapshot,
    logistics_order_key
FROM public.fact_order_item;

GRANT SELECT ON public.v_fact_order_item_masked TO shop_ro;
