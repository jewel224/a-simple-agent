import os
from pathlib import Path
from urllib.parse import quote_plus
import dashscope
from dotenv import load_dotenv
from qwen_agent.agents import Assistant
from qwen_agent.gui import WebUI
import pandas as pd
from sqlalchemy import create_engine
from qwen_agent.tools.base import BaseTool, register_tool

# 项目根目录与本地环境变量
PROJECT_ROOT = Path(__file__).resolve().parents[1]
load_dotenv(PROJECT_ROOT / '.env')

# 配置 DashScope
dashscope.api_key = os.getenv('DASHSCOPE_API_KEY', '')  # 从环境变量获取 API Key
dashscope.timeout = 30  # 设置超时时间为 30 秒

# PostgreSQL 连接配置（shop_dw 业务库）
PG_HOST = os.getenv('MOCK_PG_HOST', 'localhost')
PG_PORT = os.getenv('MOCK_PG_PORT', '5432')
PG_USER = os.getenv('MOCK_PG_USER', 'shop_app')
PG_PASSWORD = os.getenv('MOCK_PG_PASSWORD', '')
PG_DB = os.getenv('MOCK_PG_DB', 'shop_dw')

if not PG_PASSWORD:
    raise RuntimeError('缺少 MOCK_PG_PASSWORD，请在项目根目录 .env 中配置')

# ====== 订单助手 system prompt ======
system_prompt = """我是订单助手，基于手机购物 App 的 shop_dw 星型数仓提供业务答疑。
我可能会编写对应的 SQL（运行环境是 PostgreSQL 18，库名 shop_dw），对数据进行查询。

-- shop_dw 是星型数仓，共 16 张表：9 张维度表 + 7 张事实表
-- 维度表：dim_date / dim_region / dim_channel / dim_user / dim_category / dim_merchant / dim_product / dim_promotion / dim_payment_method
-- 事实表：fact_order / fact_order_item / fact_payment / fact_refund / fact_app_event / fact_logistics_order / fact_logistics_trace

-- 日期维度（被订单/明细/支付/退款/事件引用）
CREATE TABLE dim_date (
    date_key integer PRIMARY KEY,
    calendar_date date NOT NULL UNIQUE,
    year smallint, quarter smallint, month smallint, day smallint,
    week_of_year smallint, day_of_week smallint,
    day_name_cn varchar(8), is_weekend boolean, is_holiday boolean
);

-- 地区维度（国家省市区四级）
CREATE TABLE dim_region (
    region_key bigint PRIMARY KEY,
    region_code varchar(32) UNIQUE,
    region_name varchar(64),
    region_type varchar(16),  -- country/province/city/district
    parent_region_key bigint,  -- 自引用
    level smallint, region_path varchar(255), status boolean
);

-- 渠道维度
CREATE TABLE dim_channel (
    channel_key bigint PRIMARY KEY,
    channel_code varchar(32) UNIQUE,
    channel_name varchar(64),
    channel_type varchar(16),  -- natural/paid/content/live
    platform varchar(32), device_platform varchar(32),
    is_paid boolean, status boolean
);

-- 用户维度
CREATE TABLE dim_user (
    user_key bigint PRIMARY KEY,
    user_id varchar(64) UNIQUE,
    nickname_masked varchar(64), phone_masked varchar(16),
    gender_code varchar(8),  -- M/F/U
    age_group varchar(16), member_level varchar(16),  -- normal 等
    default_region_key bigint, register_channel_key bigint,
    registration_date date, status varchar(16)  -- active/frozen/closed
);

-- 品类维度
CREATE TABLE dim_category (
    category_key bigint PRIMARY KEY,
    category_code varchar(32) UNIQUE,
    category_name varchar(64),
    parent_category_key bigint,  -- 自引用
    category_level smallint, sort_no integer, status boolean
);

-- 商家维度
CREATE TABLE dim_merchant (
    merchant_key bigint PRIMARY KEY,
    merchant_id varchar(64) UNIQUE,
    merchant_name varchar(128),
    merchant_type varchar(32),  -- flagship/specialty/individual
    merchant_level varchar(16),  -- A 等
    region_key bigint, service_score numeric(3,2),  -- 0-5
    status boolean, opened_at date
);

-- 商品维度
CREATE TABLE dim_product (
    product_key bigint PRIMARY KEY,
    product_id varchar(64) UNIQUE,
    sku_code varchar(64) UNIQUE,
    product_name varchar(255), brand varchar(64), spec varchar(128),
    category_key bigint, merchant_key bigint,
    reference_price numeric(12,2), cost_price numeric(12,2),
    shelf_status varchar(8)  -- on/off
);

-- 促销维度
CREATE TABLE dim_promotion (
    promotion_key bigint PRIMARY KEY,
    promotion_id varchar(64) UNIQUE,
    promotion_name varchar(128),
    promotion_type varchar(32),  -- full_reduction/discount/coupon/new_user/live
    discount_type varchar(16),  -- amount/percent
    discount_value numeric(12,4),
    start_at timestamptz, end_at timestamptz,
    status varchar(16)  -- scheduled/running/ended
);

-- 支付方式维度
CREATE TABLE dim_payment_method (
    payment_method_key bigint PRIMARY KEY,
    method_code varchar(32) UNIQUE,
    method_name varchar(64),
    provider varchar(32), supported_platform varchar(64),
    is_active boolean
);

-- 订单事实表（粒度：一行一个订单）
CREATE TABLE fact_order (
    order_key bigint PRIMARY KEY,
    order_no varchar(64) UNIQUE,
    date_key integer, user_key bigint, channel_key bigint,
    shipping_region_key bigint, promotion_key bigint,
    order_status varchar(16),  -- pending_payment/paid/shipped/completed/cancelled/closed
    is_shipped boolean,
    goods_amount numeric(12,2),     -- 商品金额
    discount_amount numeric(12,2),  -- 优惠金额
    freight_amount numeric(12,2),   -- 运费
    pay_amount numeric(12,2),       -- 实付金额
    item_count integer,
    order_created_at timestamptz, paid_at timestamptz,
    received_at timestamptz, cancelled_at timestamptz, completed_at timestamptz
);

-- 订单明细事实表（粒度：一行一个订单中的一行商品明细，含收货地址与商品快照）
CREATE TABLE fact_order_item (
    order_item_key bigint PRIMARY KEY,
    order_key bigint, order_item_no varchar(32), date_key integer,
    product_key bigint, merchant_key bigint, promotion_key bigint,
    quantity integer, unit_price numeric(12,2),
    discount_amount numeric(12,2), item_amount numeric(12,2),
    item_status varchar(16),  -- normal/refunding/refunded
    order_status varchar(16),  -- 订单头状态快照
    paid_at timestamptz, received_at timestamptz, is_shipped boolean,
    shipping_region_key bigint,
    shipping_province_name varchar(64), shipping_city_name varchar(64),
    shipping_district_name varchar(64), shipping_detail_address varchar(255),
    recipient_name varchar(64), recipient_phone varchar(32),
    product_name_snapshot varchar(255), category_path_snapshot varchar(255),
    logistics_order_key bigint
);

-- 支付事实表（粒度：一行一次支付交易）
CREATE TABLE fact_payment (
    payment_key bigint PRIMARY KEY,
    payment_no varchar(64) UNIQUE,
    order_key bigint, date_key integer, payment_method_key bigint,
    pay_amount numeric(12,2),
    payment_status varchar(16),  -- pending/success/failed/closed/refunded
    payment_started_at timestamptz, payment_finished_at timestamptz,
    payment_trade_no varchar(128), error_code varchar(32), error_message text
);

-- 退款事实表（粒度：一行一次退款申请或退款结果）
CREATE TABLE fact_refund (
    refund_key bigint PRIMARY KEY,
    refund_no varchar(64) UNIQUE,
    order_key bigint, order_item_key bigint, payment_key bigint,
    date_key integer, user_key bigint,
    refund_type varchar(16),  -- full_order/item_only
    refund_reason_code varchar(32), refund_reason text,
    refund_amount numeric(12,2),
    refund_status varchar(16),  -- applied/approved/refunding/refunded/rejected
    applied_at timestamptz, finished_at timestamptz
);

-- App 行为事实表（粒度：一行一次用户行为事件）
CREATE TABLE fact_app_event (
    event_key bigint PRIMARY KEY,
    event_id varchar(64) UNIQUE,
    date_key integer, user_key bigint, channel_key bigint,
    region_key bigint, product_key bigint, order_key bigint,
    session_id varchar(64), page_code varchar(64),
    event_type varchar(64), event_time timestamptz,
    payload jsonb
);

-- 物流运单表（粒度：一行一个物流运单）
CREATE TABLE fact_logistics_order (
    logistics_order_key bigint PRIMARY KEY,
    logistics_no varchar(64) UNIQUE,
    order_key bigint, logistics_company varchar(64),
    current_status varchar(16),  -- shipped/in_transit/out_for_delivery/signed/rejected/returning/returned/exception
    current_status_time timestamptz, shipped_at timestamptz, signed_at timestamptz,
    expected_arrival_at timestamptz
);

-- 物流状态流水表（粒度：一行一次物流状态更新）
CREATE TABLE fact_logistics_trace (
    logistics_trace_key bigint PRIMARY KEY,
    logistics_order_key bigint, order_key bigint,
    trace_status varchar(16),  -- shipped/in_transit/out_for_delivery/signed/rejected/returning/returned/exception
    trace_status_cn varchar(32), trace_time timestamptz,
    location_name varchar(255), operator_name varchar(64),
    signed_name varchar(64), trace_description varchar(512)
);


业务背景：
- 数据时间跨度：2025-01-01 至 2026-09-10，约 2.2 万订单。
- 地区覆盖全国 31 个省份/自治区/直辖市，订单集中在江浙沪地区。
- 生活类目：女装、饰品、护肤品、彩妆、鞋子、包包、童装、玩具、童鞋、童书、男装、男鞋、家具家电、虚拟产品、生鲜、水果、手机数码。
- 类目规模关系：女士相关订单 > 婴童类 > 男士 > 家具家电。
- 大促场景：2025/2026 618、2025 双11、2025 双12、双旦礼遇季订单明显高于日常。
- 共 20 个商家，一个商家只经营一个大类。

常见分析场景与 SQL 模式：
-- 1. 按品类统计订单金额排名（通过明细表关联品类快照或商品维）
SELECT d.category_name, SUM(oi.item_amount) AS amount
FROM fact_order_item oi
JOIN dim_product p ON oi.product_key = p.product_key
JOIN dim_category d ON p.category_key = d.category_key
JOIN dim_date dt ON oi.date_key = dt.date_key
WHERE dt.calendar_date BETWEEN '2025-11-01' AND '2025-11-30'
GROUP BY d.category_name ORDER BY amount DESC;

-- 2. 按渠道统计订单量与支付金额
SELECT c.channel_name,
       COUNT(DISTINCT o.order_key) AS order_cnt,
       SUM(o.pay_amount) AS pay_amount
FROM fact_order o
JOIN dim_channel c ON o.channel_key = c.channel_key
JOIN dim_date dt ON o.date_key = dt.date_key
WHERE dt.calendar_date BETWEEN '2025-06-01' AND '2025-06-18'
GROUP BY c.channel_name ORDER BY pay_amount DESC;

-- 3. 退款金额与退款率（退款金额 / 支付金额）
SELECT TO_CHAR(dt.calendar_date, 'YYYY-MM') AS ym,
       SUM(r.refund_amount) AS refund_amount,
       SUM(p.pay_amount) AS pay_amount,
       ROUND(SUM(r.refund_amount) / NULLIF(SUM(p.pay_amount), 0) * 100, 2) AS refund_rate
FROM fact_refund r
JOIN fact_payment p ON r.payment_key = p.payment_key
JOIN dim_date dt ON r.date_key = dt.date_key
WHERE dt.calendar_date BETWEEN '2026-01-01' AND '2026-08-31'
GROUP BY ym ORDER BY ym;

-- 4. 按省份统计订单数（通过收货地区维）
SELECT r.region_name AS province, COUNT(*) AS order_cnt
FROM fact_order o
JOIN dim_region r ON o.shipping_region_key = r.region_key
WHERE r.region_type = 'province'
GROUP BY r.region_name ORDER BY order_cnt DESC;

我将回答用户关于订单、支付、退款、物流、商品、用户行为等业务相关的问题。
编写 SQL 时注意：PostgreSQL 18，使用标准 SQL 语法；金额字段为 NUMERIC(12,2)；
时间字段为 TIMESTAMPTZ；日期分析优先关联 dim_date；品类/商品分析优先关联 dim_product 与 dim_category。
"""


# ====== exc_sql 工具类实现 ======
@register_tool('exc_sql')
class ExcSQLTool(BaseTool):
    """
    SQL查询工具，执行传入的SQL语句并返回结果。
    """
    description = '对于生成的SQL，进行SQL查询（PostgreSQL，shop_dw 业务库）'
    parameters = [{
        'name': 'sql_input',
        'type': 'string',
        'description': '生成的SQL语句',
        'required': True
    }]

    def call(self, params: str, **kwargs) -> str:
        import json
        args = json.loads(params)
        sql_input = args['sql_input']
        database = args.get('database', PG_DB)
        # 对密码进行 URL 编码，避免特殊字符（如 @）破坏连接串
        pg_password_encoded = quote_plus(PG_PASSWORD)
        # 创建 PostgreSQL 数据库连接
        engine = create_engine(
            f'postgresql+psycopg2://{PG_USER}:{pg_password_encoded}@{PG_HOST}:{PG_PORT}/{database}',
            connect_args={'connect_timeout': 10}, pool_size=10, max_overflow=20
        )
        try:
            df = pd.read_sql(sql_input, engine)
            # 返回前10行，防止数据过多
            return df.head(10).to_markdown(index=False)
        except Exception as e:
            return f"SQL执行出错: {str(e)}"


# ====== 初始化订单助手服务 ======
def init_agent_service():
    """初始化订单助手服务"""
    if not dashscope.api_key:
        raise RuntimeError('缺少 DASHSCOPE_API_KEY，请在项目根目录 .env 中配置')

    llm_cfg = {
        'model': 'qwen-turbo',
        'timeout': 30,
        'retry_count': 3,
    }
    try:
        bot = Assistant(
            llm=llm_cfg,
            name='订单助手',
            description='订单业务查询与分析（shop_dw 数仓）',
            system_message=system_prompt,
            function_list=['exc_sql'],  # 只传工具名字符串
        )
        print("助手初始化成功！")
        return bot
    except Exception as e:
        print(f"助手初始化失败: {str(e)}")
        raise


def app_tui():
    """终端交互模式

    提供命令行交互界面，支持：
    - 连续对话
    - 文件输入
    - 实时响应
    """
    try:
        # 初始化助手
        bot = init_agent_service()

        # 对话历史
        messages = []
        while True:
            try:
                # 获取用户输入
                query = input('user question: ')
                # 获取可选的文件输入
                file = input('file url (press enter if no file): ').strip()

                # 输入验证
                if not query:
                    print('user question cannot be empty！')
                    continue

                # 构建消息
                if not file:
                    messages.append({'role': 'user', 'content': query})
                else:
                    messages.append({'role': 'user', 'content': [{'text': query}, {'file': file}]})

                print("正在处理您的请求...")
                # 运行助手并处理响应
                response = []
                for response in bot.run(messages):
                    print('bot response:', response)
                messages.extend(response)
            except Exception as e:
                print(f"处理请求时出错: {str(e)}")
                print("请重试或输入新的问题")
    except Exception as e:
        print(f"启动终端模式失败: {str(e)}")


def app_gui():
    """图形界面模式，提供 Web 图形界面"""
    try:
        print("正在启动 Web 界面...")
        # 初始化助手
        bot = init_agent_service()
        # 配置聊天界面，列举3个典型订单业务查询问题
        chatbot_config = {
            'prompt.suggestions': [
                '2025年11月各品类的订单金额排名情况',
                '2025年618期间（6月1-18日）各渠道的订单量和支付金额统计',
                '2026年1-8月每月的退款金额和退款率趋势',
            ]
        }
        print("Web 界面准备就绪，正在启动服务...")
        # 启动 Web 界面
        WebUI(
            bot,
            chatbot_config=chatbot_config
        ).run()
    except Exception as e:
        print(f"启动 Web 界面失败: {str(e)}")
        print("请检查网络连接和 API Key 配置")


if __name__ == '__main__':
    # 运行模式选择
    app_gui()          # 图形界面模式（默认）
