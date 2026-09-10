-- shop_dw：手机购物 App 星型数仓
-- 执行角色：shop_app，连接数据库：shop_dw

-- 日期维度
CREATE TABLE IF NOT EXISTS public.dim_date (
    date_key integer PRIMARY KEY,
    calendar_date date NOT NULL UNIQUE,
    year smallint NOT NULL,
    quarter smallint NOT NULL CHECK (quarter BETWEEN 1 AND 4),
    month smallint NOT NULL CHECK (month BETWEEN 1 AND 12),
    day smallint NOT NULL CHECK (day BETWEEN 1 AND 31),
    week_of_year smallint NOT NULL CHECK (week_of_year BETWEEN 1 AND 53),
    day_of_week smallint NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    day_name_cn varchar(8) NOT NULL,
    is_weekend boolean NOT NULL,
    is_holiday boolean NOT NULL DEFAULT false
);

COMMENT ON TABLE public.dim_date IS '日期维度，用于订单、支付、退款和事件按日期分析';

-- 地区维度
CREATE TABLE IF NOT EXISTS public.dim_region (
    region_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    region_code varchar(32) NOT NULL UNIQUE,
    region_name varchar(64) NOT NULL,
    region_type varchar(16) NOT NULL CHECK (region_type IN ('country', 'province', 'city', 'district')),
    parent_region_key bigint,
    level smallint NOT NULL,
    region_path varchar(255),
    status boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_dim_region_parent FOREIGN KEY (parent_region_key)
        REFERENCES public.dim_region(region_key) ON DELETE RESTRICT
);

COMMENT ON TABLE public.dim_region IS '国家省市区四级地区维度';

-- 渠道维度
CREATE TABLE IF NOT EXISTS public.dim_channel (
    channel_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    channel_code varchar(32) NOT NULL UNIQUE,
    channel_name varchar(64) NOT NULL,
    channel_type varchar(16) NOT NULL CHECK (channel_type IN ('natural', 'paid', 'content', 'live')),
    platform varchar(32),
    device_platform varchar(32),
    is_paid boolean NOT NULL DEFAULT false,
    status boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.dim_channel IS '订单与行为事件所属的渠道维度';

-- 用户维度
CREATE TABLE IF NOT EXISTS public.dim_user (
    user_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id varchar(64) NOT NULL UNIQUE,
    nickname_masked varchar(64),
    phone_masked varchar(16),
    gender_code varchar(8) NOT NULL DEFAULT 'U' CHECK (gender_code IN ('M', 'F', 'U')),
    age_group varchar(16),
    member_level varchar(16) NOT NULL DEFAULT 'normal',
    default_region_key bigint,
    register_channel_key bigint,
    registration_date date NOT NULL,
    status varchar(16) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'frozen', 'closed')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_dim_user_region FOREIGN KEY (default_region_key)
        REFERENCES public.dim_region(region_key) ON DELETE RESTRICT,
    CONSTRAINT fk_dim_user_channel FOREIGN KEY (register_channel_key)
        REFERENCES public.dim_channel(channel_key) ON DELETE RESTRICT
);

COMMENT ON TABLE public.dim_user IS '购物 App 注册用户维度';

-- 品类维度
CREATE TABLE IF NOT EXISTS public.dim_category (
    category_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_code varchar(32) NOT NULL UNIQUE,
    category_name varchar(64) NOT NULL,
    parent_category_key bigint,
    category_level smallint NOT NULL,
    sort_no integer NOT NULL DEFAULT 0,
    status boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_dim_category_parent FOREIGN KEY (parent_category_key)
        REFERENCES public.dim_category(category_key) ON DELETE RESTRICT
);

COMMENT ON TABLE public.dim_category IS '商品类目层级维度';

-- 商家维度
CREATE TABLE IF NOT EXISTS public.dim_merchant (
    merchant_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    merchant_id varchar(64) NOT NULL UNIQUE,
    merchant_name varchar(128) NOT NULL,
    merchant_type varchar(32) NOT NULL DEFAULT 'flagship'
        CHECK (merchant_type IN ('flagship', 'specialty', 'individual')),
    merchant_level varchar(16) NOT NULL DEFAULT 'A',
    region_key bigint,
    service_score numeric(3,2) NOT NULL DEFAULT 5.00 CHECK (service_score BETWEEN 0 AND 5),
    status boolean NOT NULL DEFAULT true,
    opened_at date NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_dim_merchant_region FOREIGN KEY (region_key)
        REFERENCES public.dim_region(region_key) ON DELETE RESTRICT
);

COMMENT ON TABLE public.dim_merchant IS '平台内商家店铺维度';

-- 商品维度
CREATE TABLE IF NOT EXISTS public.dim_product (
    product_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id varchar(64) NOT NULL UNIQUE,
    sku_code varchar(64) NOT NULL UNIQUE,
    product_name varchar(255) NOT NULL,
    brand varchar(64),
    spec varchar(128),
    category_key bigint NOT NULL,
    merchant_key bigint NOT NULL,
    reference_price numeric(12,2) NOT NULL CHECK (reference_price >= 0),
    cost_price numeric(12,2) NOT NULL CHECK (cost_price >= 0),
    shelf_status varchar(8) NOT NULL DEFAULT 'on' CHECK (shelf_status IN ('on', 'off')),
    on_shelf_at timestamptz,
    off_shelf_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_dim_product_category FOREIGN KEY (category_key)
        REFERENCES public.dim_category(category_key) ON DELETE RESTRICT,
    CONSTRAINT fk_dim_product_merchant FOREIGN KEY (merchant_key)
        REFERENCES public.dim_merchant(merchant_key) ON DELETE RESTRICT
);

COMMENT ON TABLE public.dim_product IS '商品 SKU 维度';

-- 促销维度
CREATE TABLE IF NOT EXISTS public.dim_promotion (
    promotion_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    promotion_id varchar(64) NOT NULL UNIQUE,
    promotion_name varchar(128) NOT NULL,
    promotion_type varchar(32) NOT NULL CHECK (promotion_type IN ('full_reduction', 'discount', 'coupon', 'new_user', 'live')),
    discount_type varchar(16) NOT NULL CHECK (discount_type IN ('amount', 'percent')),
    discount_value numeric(12,4) NOT NULL CHECK (discount_value >= 0),
    start_at timestamptz NOT NULL,
    end_at timestamptz NOT NULL,
    status varchar(16) NOT NULL DEFAULT 'running' CHECK (status IN ('scheduled', 'running', 'ended')),
    created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.dim_promotion IS '满减、折扣、优惠券等促销活动维度';

-- 支付方式维度
CREATE TABLE IF NOT EXISTS public.dim_payment_method (
    payment_method_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    method_code varchar(32) NOT NULL UNIQUE,
    method_name varchar(64) NOT NULL,
    provider varchar(32),
    supported_platform varchar(64),
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.dim_payment_method IS '微信支付、支付宝等支付方式维度';

-- 订单事实表
CREATE TABLE IF NOT EXISTS public.fact_order (
    order_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_no varchar(64) NOT NULL UNIQUE,
    date_key integer NOT NULL,
    user_key bigint NOT NULL,
    channel_key bigint NOT NULL,
    shipping_region_key bigint,
    promotion_key bigint,
    order_status varchar(16) NOT NULL
        CHECK (order_status IN ('pending_payment', 'paid', 'shipped', 'completed', 'cancelled', 'closed')),
    is_shipped boolean NOT NULL DEFAULT false,
    goods_amount numeric(12,2) NOT NULL DEFAULT 0 CHECK (goods_amount >= 0),
    discount_amount numeric(12,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    freight_amount numeric(12,2) NOT NULL DEFAULT 0 CHECK (freight_amount >= 0),
    pay_amount numeric(12,2) NOT NULL CHECK (pay_amount >= 0),
    item_count integer NOT NULL DEFAULT 0 CHECK (item_count >= 0),
    order_created_at timestamptz NOT NULL DEFAULT now(),
    paid_at timestamptz,
    received_at timestamptz,
    cancelled_at timestamptz,
    completed_at timestamptz,
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_fact_order_date FOREIGN KEY (date_key)
        REFERENCES public.dim_date(date_key) ON DELETE RESTRICT,
    CONSTRAINT fk_fact_order_user FOREIGN KEY (user_key)
        REFERENCES public.dim_user(user_key) ON DELETE RESTRICT,
    CONSTRAINT fk_fact_order_channel FOREIGN KEY (channel_key)
        REFERENCES public.dim_channel(channel_key) ON DELETE RESTRICT,
    CONSTRAINT fk_fact_order_region FOREIGN KEY (shipping_region_key)
        REFERENCES public.dim_region(region_key) ON DELETE RESTRICT,
    CONSTRAINT fk_fact_order_promotion FOREIGN KEY (promotion_key)
        REFERENCES public.dim_promotion(promotion_key) ON DELETE RESTRICT
);

COMMENT ON TABLE public.fact_order IS '手机购物 App 订单头事实表';

-- 物流运单事实表
CREATE TABLE IF NOT EXISTS public.fact_logistics_order (
    logistics_order_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    logistics_no varchar(64) NOT NULL UNIQUE,
    order_key bigint NOT NULL,
    logistics_company varchar(64) NOT NULL,
    current_status varchar(16) NOT NULL DEFAULT 'shipped'
        CHECK (current_status IN ('shipped', 'in_transit', 'out_for_delivery', 'signed', 'rejected', 'returning', 'returned', 'exception')),
    current_status_time timestamptz,
    shipped_at timestamptz,
    signed_at timestamptz,
    expected_arrival_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_fact_logistics_order_order FOREIGN KEY (order_key)
        REFERENCES public.fact_order(order_key) ON DELETE RESTRICT
);

COMMENT ON TABLE public.fact_logistics_order IS '一行一个物流运单，记录订单发货的运单与当前状态';

-- 物流状态流水事实表
CREATE TABLE IF NOT EXISTS public.fact_logistics_trace (
    logistics_trace_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    logistics_order_key bigint NOT NULL,
    order_key bigint NOT NULL,
    trace_status varchar(16) NOT NULL
        CHECK (trace_status IN ('shipped', 'in_transit', 'out_for_delivery', 'signed', 'rejected', 'returning', 'returned', 'exception')),
    trace_status_cn varchar(32) NOT NULL,
    trace_time timestamptz NOT NULL,
    location_name varchar(255),
    operator_name varchar(64),
    signed_name varchar(64),
    trace_description varchar(512),
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_fact_logistics_trace_logistics FOREIGN KEY (logistics_order_key)
        REFERENCES public.fact_logistics_order(logistics_order_key) ON DELETE RESTRICT,
    CONSTRAINT fk_fact_logistics_trace_order FOREIGN KEY (order_key)
        REFERENCES public.fact_order(order_key) ON DELETE RESTRICT
);

COMMENT ON TABLE public.fact_logistics_trace IS '物流状态流水，一行一次发货、运输或签收等状态更新';

-- 订单明细事实表
CREATE TABLE IF NOT EXISTS public.fact_order_item (
    order_item_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_key bigint NOT NULL,
    order_item_no varchar(32) NOT NULL,
    date_key integer NOT NULL,
    product_key bigint NOT NULL,
    merchant_key bigint NOT NULL,
    promotion_key bigint,
    quantity integer NOT NULL CHECK (quantity > 0),
    unit_price numeric(12,2) NOT NULL CHECK (unit_price >= 0),
    discount_amount numeric(12,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    item_amount numeric(12,2) NOT NULL CHECK (item_amount >= 0),
    item_status varchar(16) NOT NULL DEFAULT 'normal' CHECK (item_status IN ('normal', 'refunding', 'refunded')),
    order_status varchar(16) NOT NULL,
    paid_at timestamptz,
    received_at timestamptz,
    is_shipped boolean NOT NULL DEFAULT false,
    shipping_region_key bigint,
    shipping_province_name varchar(64) NOT NULL,
    shipping_city_name varchar(64) NOT NULL,
    shipping_district_name varchar(64) NOT NULL,
    shipping_detail_address varchar(255) NOT NULL,
    recipient_name varchar(64) NOT NULL,
    recipient_phone varchar(32) NOT NULL,
    product_name_snapshot varchar(255) NOT NULL,
    category_path_snapshot varchar(255) NOT NULL,
    logistics_order_key bigint,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_fact_order_item_no UNIQUE (order_key, order_item_no),
    CONSTRAINT fk_fact_order_item_order FOREIGN KEY (order_key)
        REFERENCES public.fact_order(order_key) ON DELETE RESTRICT,
    CONSTRAINT fk_fact_order_item_date FOREIGN KEY (date_key)
        REFERENCES public.dim_date(date_key) ON DELETE RESTRICT,
    CONSTRAINT fk_fact_order_item_product FOREIGN KEY (product_key)
        REFERENCES public.dim_product(product_key) ON DELETE RESTRICT,
    CONSTRAINT fk_fact_order_item_merchant FOREIGN KEY (merchant_key)
        REFERENCES public.dim_merchant(merchant_key) ON DELETE RESTRICT,
    CONSTRAINT fk_fact_order_item_promotion FOREIGN KEY (promotion_key)
        REFERENCES public.dim_promotion(promotion_key) ON DELETE RESTRICT,
    CONSTRAINT fk_fact_order_item_region FOREIGN KEY (shipping_region_key)
        REFERENCES public.dim_region(region_key) ON DELETE RESTRICT,
    CONSTRAINT fk_fact_order_item_logistics FOREIGN KEY (logistics_order_key)
        REFERENCES public.fact_logistics_order(logistics_order_key) ON DELETE RESTRICT
);

COMMENT ON TABLE public.fact_order_item IS '订单明细事实表，含订单头状态、收货信息、商品快照与物流关联';

-- 支付事实表
CREATE TABLE IF NOT EXISTS public.fact_payment (
    payment_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payment_no varchar(64) NOT NULL UNIQUE,
    order_key bigint NOT NULL,
    date_key integer NOT NULL,
    payment_method_key bigint NOT NULL,
    pay_amount numeric(12,2) NOT NULL CHECK (pay_amount >= 0),
    payment_status varchar(16) NOT NULL
        CHECK (payment_status IN ('pending', 'success', 'failed', 'closed', 'refunded')),
    payment_started_at timestamptz NOT NULL DEFAULT now(),
    payment_finished_at timestamptz,
    payment_trade_no varchar(128),
    error_code varchar(32),
    error_message text,
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_fact_payment_order FOREIGN KEY (order_key)
        REFERENCES public.fact_order(order_key) ON DELETE RESTRICT,
    CONSTRAINT fk_fact_payment_date FOREIGN KEY (date_key)
        REFERENCES public.dim_date(date_key) ON DELETE RESTRICT,
    CONSTRAINT fk_fact_payment_method FOREIGN KEY (payment_method_key)
        REFERENCES public.dim_payment_method(payment_method_key) ON DELETE RESTRICT
);

COMMENT ON TABLE public.fact_payment IS '支付事实表，一行一次支付交易';

-- 退款事实表
CREATE TABLE IF NOT EXISTS public.fact_refund (
    refund_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    refund_no varchar(64) NOT NULL UNIQUE,
    order_key bigint NOT NULL,
    order_item_key bigint,
    payment_key bigint,
    date_key integer NOT NULL,
    user_key bigint NOT NULL,
    refund_type varchar(16) NOT NULL CHECK (refund_type IN ('full_order', 'item_only')),
    refund_reason_code varchar(32),
    refund_reason text,
    refund_amount numeric(12,2) NOT NULL CHECK (refund_amount >= 0),
    refund_status varchar(16) NOT NULL
        CHECK (refund_status IN ('applied', 'approved', 'refunding', 'refunded', 'rejected')),
    applied_at timestamptz NOT NULL DEFAULT now(),
    finished_at timestamptz,
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_fact_refund_order FOREIGN KEY (order_key)
        REFERENCES public.fact_order(order_key) ON DELETE RESTRICT,
    CONSTRAINT fk_fact_refund_order_item FOREIGN KEY (order_item_key)
        REFERENCES public.fact_order_item(order_item_key) ON DELETE RESTRICT,
    CONSTRAINT fk_fact_refund_payment FOREIGN KEY (payment_key)
        REFERENCES public.fact_payment(payment_key) ON DELETE RESTRICT,
    CONSTRAINT fk_fact_refund_date FOREIGN KEY (date_key)
        REFERENCES public.dim_date(date_key) ON DELETE RESTRICT,
    CONSTRAINT fk_fact_refund_user FOREIGN KEY (user_key)
        REFERENCES public.dim_user(user_key) ON DELETE RESTRICT
);

COMMENT ON TABLE public.fact_refund IS '退款事实表，支持整单退款或按明细退款';

-- App 行为事实表
CREATE TABLE IF NOT EXISTS public.fact_app_event (
    event_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_id varchar(64) NOT NULL UNIQUE,
    date_key integer NOT NULL,
    user_key bigint NOT NULL,
    channel_key bigint NOT NULL,
    region_key bigint,
    product_key bigint,
    order_key bigint,
    session_id varchar(64) NOT NULL,
    page_code varchar(64) NOT NULL,
    event_type varchar(64) NOT NULL,
    event_time timestamptz NOT NULL,
    payload jsonb NOT NULL DEFAULT '{}',
    CONSTRAINT fk_fact_app_event_date FOREIGN KEY (date_key)
        REFERENCES public.dim_date(date_key) ON DELETE RESTRICT,
    CONSTRAINT fk_fact_app_event_user FOREIGN KEY (user_key)
        REFERENCES public.dim_user(user_key) ON DELETE RESTRICT,
    CONSTRAINT fk_fact_app_event_channel FOREIGN KEY (channel_key)
        REFERENCES public.dim_channel(channel_key) ON DELETE RESTRICT,
    CONSTRAINT fk_fact_app_event_region FOREIGN KEY (region_key)
        REFERENCES public.dim_region(region_key) ON DELETE RESTRICT,
    CONSTRAINT fk_fact_app_event_product FOREIGN KEY (product_key)
        REFERENCES public.dim_product(product_key) ON DELETE RESTRICT,
    CONSTRAINT fk_fact_app_event_order FOREIGN KEY (order_key)
        REFERENCES public.fact_order(order_key) ON DELETE RESTRICT
);

COMMENT ON TABLE public.fact_app_event IS 'App 行为事件事实表，记录浏览、搜索、加购、支付等行为';

-- 物流状态同步函数与触发器
CREATE OR REPLACE FUNCTION public.sync_logistics_current_status()
RETURNS trigger AS $$
BEGIN
    UPDATE public.fact_logistics_order
    SET current_status = NEW.trace_status,
        current_status_time = NEW.trace_time,
        signed_at = CASE WHEN NEW.trace_status = 'signed' THEN NEW.trace_time ELSE signed_at END,
        updated_at = now()
    WHERE logistics_order_key = NEW.logistics_order_key;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_logistics_current_status ON public.fact_logistics_trace;

CREATE TRIGGER trg_sync_logistics_current_status
AFTER INSERT ON public.fact_logistics_trace
FOR EACH ROW EXECUTE FUNCTION public.sync_logistics_current_status();

COMMENT ON FUNCTION public.sync_logistics_current_status() IS '新增物流状态流水后同步物流运单当前状态';
