-- v2 退款扩展种子：为 2026 年以来截至今日的支付提供可分析的趋势数据
-- 执行角色：shop_app，连接数据库：shop_dw

WITH candidate_payments AS (
    SELECT
        p.payment_key,
        p.order_key,
        p.pay_amount,
        dt.calendar_date,
        dt.year,
        dt.month,
        row_number() OVER (
            PARTITION BY dt.year, dt.month
            ORDER BY p.payment_key
        ) AS month_sequence
    FROM public.fact_payment p
    JOIN public.dim_date dt ON p.date_key = dt.date_key
    WHERE dt.calendar_date >= date '2026-01-01'
      -- 退款日期为支付日期加 3-7 天；限定候选支付不晚于今日前 7 天。
      AND dt.calendar_date <= ((current_timestamp AT TIME ZONE 'Asia/Shanghai')::date - 7)
      AND p.payment_status = 'success'
),
selected_payments AS (
    SELECT
        *,
        row_number() OVER (
            ORDER BY calendar_date, payment_key
        ) AS refund_sequence
    FROM candidate_payments
    WHERE month_sequence % 20 = 0
),
refund_rows AS (
    SELECT
        800000 + sp.refund_sequence AS refund_key,
        'EXRF' || lpad(sp.refund_sequence::text, 8, '0') AS refund_no,
        sp.order_key,
        (
            SELECT oi.order_item_key
            FROM public.fact_order_item oi
            WHERE oi.order_key = sp.order_key
            ORDER BY oi.order_item_key
            LIMIT 1
        ) AS order_item_key,
        sp.payment_key,
        (to_char(sp.calendar_date + ((sp.payment_key % 5) + 3) * interval '1 day', 'YYYYMMDD'))::integer AS date_key,
        o.user_key,
        CASE WHEN sp.payment_key % 3 = 0 THEN 'full_order' ELSE 'item_only' END AS refund_type,
        CASE
            WHEN sp.payment_key % 9 = 0 THEN 'NOT_AS_DESCRIBED'
            WHEN sp.payment_key % 9 = 1 THEN 'QUALITY_ISSUE'
            WHEN sp.payment_key % 9 = 2 THEN 'SIZE_MISMATCH'
            WHEN sp.payment_key % 9 = 3 THEN 'CHANGE_OF_MIND'
            ELSE 'LOGISTICS_TIMEOUT'
        END AS refund_reason_code,
        CASE
            WHEN sp.payment_key % 9 = 0 THEN '商品与描述不符'
            WHEN sp.payment_key % 9 = 1 THEN '商品质量问题'
            WHEN sp.payment_key % 9 = 2 THEN '尺码不合适'
            WHEN sp.payment_key % 9 = 3 THEN '不想要了'
            ELSE '物流超时'
        END AS refund_reason,
        CASE
            WHEN sp.payment_key % 3 = 0 THEN sp.pay_amount
            ELSE round(sp.pay_amount * (0.25 + (sp.payment_key % 40) / 100.0), 2)
        END AS refund_amount,
        CASE WHEN sp.payment_key % 12 = 0 THEN 'approved' ELSE 'refunded' END AS refund_status,
        sp.calendar_date + (((sp.refund_sequence % 8) + 8) * interval '1 hour') AS applied_at,
        CASE
            WHEN sp.payment_key % 12 = 0 THEN NULL
            ELSE sp.calendar_date + (((sp.refund_sequence % 8) + 16) * interval '1 hour')
        END AS finished_at
    FROM selected_payments sp
    JOIN public.fact_order o ON sp.order_key = o.order_key
)
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
SELECT
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
    applied_at AT TIME ZONE 'Asia/Shanghai',
    finished_at AT TIME ZONE 'Asia/Shanghai'
FROM refund_rows
ON CONFLICT (refund_no) DO NOTHING;

-- 显式插入自增键后同步序列，避免后续自动生成退款 ID 冲突
SELECT setval(
    pg_get_serial_sequence('public.fact_refund', 'refund_key'),
    (SELECT max(refund_key) FROM public.fact_refund)
);
