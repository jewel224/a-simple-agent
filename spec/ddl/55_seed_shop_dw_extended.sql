-- shop_dw 扩展 mock 数据：全国地区、日常类目、大促场景与批量订单
-- 执行角色：shop_app，连接数据库：shop_dw

-- 补充全国省份、省会城市与主要区县
WITH region_values(region_name, city_name, district_name) AS (
    VALUES
        ('河北省', '石家庄市', '长安区'),
        ('山西省', '太原市', '小店区'),
        ('辽宁省', '沈阳市', '和平区'),
        ('吉林省', '长春市', '朝阳区'),
        ('黑龙江省', '哈尔滨市', '南岗区'),
        ('安徽省', '合肥市', '蜀山区'),
        ('福建省', '福州市', '鼓楼区'),
        ('江西省', '南昌市', '东湖区'),
        ('山东省', '济南市', '历下区'),
        ('河南省', '郑州市', '金水区'),
        ('湖北省', '武汉市', '武昌区'),
        ('湖南省', '长沙市', '芙蓉区'),
        ('广西壮族自治区', '南宁市', '青秀区'),
        ('海南省', '海口市', '美兰区'),
        ('四川省', '成都市', '武侯区'),
        ('贵州省', '贵阳市', '南明区'),
        ('云南省', '昆明市', '官渡区'),
        ('西藏自治区', '拉萨市', '城关区'),
        ('陕西省', '西安市', '雁塔区'),
        ('甘肃省', '兰州市', '城关区'),
        ('青海省', '西宁市', '城中区'),
        ('宁夏回族自治区', '银川市', '兴庆区'),
        ('新疆维吾尔自治区', '乌鲁木齐市', '天山区'),
        ('内蒙古自治区', '呼和浩特市', '新城区'),
        ('北京市', '北京市', '朝阳区'),
        ('天津市', '天津市', '和平区'),
        ('重庆市', '重庆市', '渝中区'),
        ('上海市', '上海市', '浦东新区')
),
ranked_regions AS (
    SELECT region_name, city_name, district_name, row_number() OVER () AS region_no
    FROM region_values
)
INSERT INTO public.dim_region (
    region_key,
    region_code,
    region_name,
    region_type,
    parent_region_key,
    level,
    region_path,
    status,
    created_at
) OVERRIDING SYSTEM VALUE
SELECT
    11 + (region_no - 1) * 3,
    'PROV_' || lpad(region_no::text, 3, '0'),
    region_name,
    'province',
    1,
    2,
    '中国/' || region_name,
    true,
    now()
FROM ranked_regions
UNION ALL
SELECT
    12 + (region_no - 1) * 3,
    'CITY_' || lpad(region_no::text, 3, '0'),
    city_name,
    'city',
    11 + (region_no - 1) * 3,
    3,
    '中国/' || region_name || '/' || city_name,
    true,
    now()
FROM ranked_regions
UNION ALL
SELECT
    13 + (region_no - 1) * 3,
    'DIST_' || lpad(region_no::text, 3, '0'),
    district_name,
    'district',
    12 + (region_no - 1) * 3,
    4,
    '中国/' || region_name || '/' || city_name || '/' || district_name,
    true,
    now()
FROM ranked_regions;

-- 补充专业化产业带地区：温州鞋服、广州美妆皮具、澄海玩具、湖州童装、泉州鞋服、佛山家电
INSERT INTO public.dim_region (
    region_key,
    region_code,
    region_name,
    region_type,
    parent_region_key,
    level,
    region_path,
    status,
    created_at
) OVERRIDING SYSTEM VALUE
VALUES
    (95, 'REG_WZ_CITY', '温州市', 'city', 2, 3, '中国/浙江省/温州市', true, now()),
    (96, 'REG_WZ_DIST', '鹿城区', 'district', 95, 4, '中国/浙江省/温州市/鹿城区', true, now()),
    (97, 'REG_GZ_CITY', '广州市', 'city', 5, 3, '中国/广东省/广州市', true, now()),
    (98, 'REG_GZ_DIST', '天河区', 'district', 97, 4, '中国/广东省/广州市/天河区', true, now()),
    (99, 'REG_ST_CITY', '汕头市', 'city', 5, 3, '中国/广东省/汕头市', true, now()),
    (100, 'REG_ST_DIST', '澄海区', 'district', 99, 4, '中国/广东省/汕头市/澄海区', true, now()),
    (101, 'REG_FS_CITY', '佛山市', 'city', 5, 3, '中国/广东省/佛山市', true, now()),
    (102, 'REG_FS_DIST', '顺德区', 'district', 101, 4, '中国/广东省/佛山市/顺德区', true, now()),
    (103, 'REG_HU_CITY', '湖州市', 'city', 2, 3, '中国/浙江省/湖州市', true, now()),
    (104, 'REG_HU_DIST', '吴兴区', 'district', 103, 4, '中国/浙江省/湖州市/吴兴区', true, now()),
    (105, 'REG_QZ_CITY', '泉州市', 'city', 29, 3, '中国/福建省/泉州市', true, now()),
    (106, 'REG_QZ_DIST', '晋江市', 'district', 105, 4, '中国/福建省/泉州市/晋江市', true, now());

-- 补充生活类目
INSERT INTO public.dim_category (
    category_key,
    category_code,
    category_name,
    parent_category_key,
    category_level,
    sort_no,
    status,
    created_at
) OVERRIDING SYSTEM VALUE
VALUES
    (9, 'CAT_WOMEN', '女装', NULL, 1, 20, true, now()),
    (10, 'CAT_JEWELRY', '饰品', NULL, 1, 21, true, now()),
    (11, 'CAT_SKINCARE', '护肤品', NULL, 1, 22, true, now()),
    (12, 'CAT_MAKEUP', '彩妆', NULL, 1, 23, true, now()),
    (13, 'CAT_SHOES', '鞋子', NULL, 1, 24, true, now()),
    (14, 'CAT_BAGS', '包包', NULL, 1, 25, true, now()),
    (15, 'CAT_KIDS_CLOTHING', '童装', NULL, 1, 30, true, now()),
    (16, 'CAT_TOYS', '玩具', NULL, 1, 31, true, now()),
    (17, 'CAT_KIDS_SHOES', '童鞋', NULL, 1, 32, true, now()),
    (18, 'CAT_KIDS_BOOK', '童书', NULL, 1, 33, true, now()),
    (19, 'CAT_MEN', '男装', NULL, 1, 40, true, now()),
    (20, 'CAT_MEN_SHOES', '男鞋', NULL, 1, 41, true, now()),
    (21, 'CAT_FURNITURE', '家具家电', NULL, 1, 50, true, now()),
    (22, 'CAT_VIRTUAL', '虚拟产品', NULL, 1, 60, true, now()),
    (23, 'CAT_FRESH', '生鲜', NULL, 1, 61, true, now()),
    (24, 'CAT_FRUIT', '水果', NULL, 1, 62, true, now()),
    (25, 'CAT_PHONE_DIGITAL_NEW', '手机数码', NULL, 1, 10, true, now());

-- 补充商家
INSERT INTO public.dim_merchant (
    merchant_key,
    merchant_id,
    merchant_name,
    merchant_type,
    merchant_level,
    region_key,
    service_score,
    opened_at,
    status,
    created_at,
    updated_at
) OVERRIDING SYSTEM VALUE
VALUES
    (4, 'M1004', '悦己杭派女装旗舰店', 'flagship', 'S', 3, 4.85, '2025-01-01', true, now(), now()),
    (5, 'M1005', '水贝银饰旗舰店', 'flagship', 'A', 6, 4.80, '2025-01-01', true, now(), now()),
    (6, 'M1006', '花语沪上护肤旗舰店', 'flagship', 'A', 93, 4.90, '2025-01-01', true, now(), now()),
    (7, 'M1007', '花语彩妆旗舰店', 'flagship', 'A', 98, 4.85, '2025-01-01', true, now(), now()),
    (8, 'M1008', '温州步履鞋业旗舰店', 'specialty', 'A', 96, 4.75, '2025-01-01', true, now(), now()),
    (9, 'M1009', '广府拎爱皮具旗舰店', 'flagship', 'A', 98, 4.80, '2025-01-01', true, now(), now()),
    (10, 'M1010', '湖州萌宝童装旗舰店', 'flagship', 'A', 104, 4.90, '2025-01-01', true, now(), now()),
    (11, 'M1011', '澄海拼趣玩具旗舰店', 'specialty', 'A', 100, 4.85, '2025-01-01', true, now(), now()),
    (12, 'M1012', '晋江小脚丫童鞋旗舰店', 'flagship', 'A', 106, 4.80, '2025-01-01', true, now(), now()),
    (13, 'M1013', '京城童阅童书旗舰店', 'flagship', 'A', 85, 4.95, '2025-01-01', true, now(), now()),
    (14, 'M1014', '杭州简仕男装旗舰店', 'flagship', 'A', 3, 4.75, '2025-01-01', true, now(), now()),
    (15, 'M1015', '晋江足下男鞋旗舰店', 'flagship', 'A', 106, 4.80, '2025-01-01', true, now(), now()),
    (16, 'M1016', '顺德理想家家电旗舰店', 'flagship', 'S', 102, 4.90, '2025-01-01', true, now(), now()),
    (17, 'M1017', '杭州云享虚拟商品店', 'specialty', 'A', 3, 4.70, '2025-01-01', true, now(), now()),
    (18, 'M1018', '胶东鲜选生鲜店', 'specialty', 'A', 37, 4.85, '2025-01-01', true, now(), now()),
    (19, 'M1019', '新疆果乐园水果店', 'specialty', 'A', 79, 4.88, '2025-01-01', true, now(), now()),
    (20, 'M1020', '深圳声界数码旗舰店', 'flagship', 'A', 7, 4.82, '2025-01-01', true, now(), now());

-- 补充商品：覆盖女士、婴童、男士、家具家电、虚拟产品、生鲜与水果
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
    on_shelf_at,
    created_at,
    updated_at
) OVERRIDING SYSTEM VALUE
VALUES
    (11, 'P30001', 'SKU-W1', '夏季真丝连衣裙', '悦己', 'M 雾蓝', 9, 4, 499.00, 220.00, 'on', '2025-01-01', now(), now()),
    (12, 'P30002', 'SKU-W2', '法式针织开衫', '悦己', 'L 米白', 9, 4, 299.00, 120.00, 'on', '2025-01-01', now(), now()),
    (13, 'P30003', 'SKU-W3', '淡水珍珠耳环', '悦己', '银色', 10, 4, 199.00, 60.00, 'on', '2025-01-01', now(), now()),
    (14, 'P30004', 'SKU-W4', '925银锁骨链', '悦己', '18寸', 10, 4, 259.00, 90.00, 'on', '2025-01-01', now(), now()),
    (15, 'P30005', 'SKU-W5', '玻尿酸保湿面霜', '花语', '50g', 11, 4, 329.00, 150.00, 'on', '2025-01-01', now(), now()),
    (16, 'P30006', 'SKU-W6', '清爽防晒霜', '花语', 'SPF50', 11, 4, 189.00, 80.00, 'on', '2025-01-01', now(), now()),
    (17, 'P30007', 'SKU-W7', '丝绒口红礼盒', '花语', '六支装', 12, 4, 399.00, 180.00, 'on', '2025-01-01', now(), now()),
    (18, 'P30008', 'SKU-W8', '大地色眼影盘', '花语', '18色', 12, 4, 259.00, 100.00, 'on', '2025-01-01', now(), now()),
    (19, 'P30009', 'SKU-W9', '女式小白鞋', '步履', '36-39 白色', 13, 4, 269.00, 110.00, 'on', '2025-01-01', now(), now()),
    (20, 'P30010', 'SKU-W10', '女式切尔西短靴', '步履', '37 棕色', 13, 4, 399.00, 170.00, 'on', '2025-01-01', now(), now()),
    (21, 'P30011', 'SKU-W11', '头层牛皮单肩包', '拎爱', '黑色', 14, 4, 599.00, 260.00, 'on', '2025-01-01', now(), now()),
    (22, 'P30012', 'SKU-W12', '大容量通勤托特包', '拎爱', '米色', 14, 4, 329.00, 130.00, 'on', '2025-01-01', now(), now()),
    (23, 'P30013', 'SKU-B1', '儿童纯棉短袖T恤', '萌宝', '110cm', 15, 5, 79.00, 25.00, 'on', '2025-01-01', now(), now()),
    (24, 'P30014', 'SKU-B2', '儿童轻薄羽绒服', '萌宝', '130cm', 15, 5, 329.00, 140.00, 'on', '2025-01-01', now(), now()),
    (25, 'P30015', 'SKU-B3', '森林木质积木', '拼趣', '300粒', 16, 5, 159.00, 60.00, 'on', '2025-01-01', now(), now()),
    (26, 'P30016', 'SKU-B4', '遥控越野车', '拼趣', '充电款', 16, 5, 199.00, 80.00, 'on', '2025-01-01', now(), now()),
    (27, 'P30017', 'SKU-B5', '儿童透气运动鞋', '小脚丫', '31码', 17, 5, 189.00, 70.00, 'on', '2025-01-01', now(), now()),
    (28, 'P30018', 'SKU-B6', '儿童机能鞋', '小脚丫', '26码', 17, 5, 219.00, 90.00, 'on', '2025-01-01', now(), now()),
    (29, 'P30019', 'SKU-B7', '幼儿习惯养成绘本', '童阅', '10册', 18, 5, 129.00, 45.00, 'on', '2025-01-01', now(), now()),
    (30, 'P30020', 'SKU-B8', '少儿科普百科全书', '童阅', '精装', 18, 5, 299.00, 120.00, 'on', '2025-01-01', now(), now()),
    (31, 'P30021', 'SKU-M1', '男士商务免烫衬衫', '简仕', 'XL 白色', 19, 6, 259.00, 90.00, 'on', '2025-01-01', now(), now()),
    (32, 'P30022', 'SKU-M2', '男士休闲夹克', '简仕', 'L 藏青', 19, 6, 399.00, 160.00, 'on', '2025-01-01', now(), now()),
    (33, 'P30023', 'SKU-M3', '男士正装皮鞋', '足下', '42 黑色', 20, 6, 499.00, 210.00, 'on', '2025-01-01', now(), now()),
    (34, 'P30024', 'SKU-M4', '男士缓震运动鞋', '足下', '43 灰色', 20, 6, 369.00, 140.00, 'on', '2025-01-01', now(), now()),
    (35, 'P30025', 'SKU-F1', '全自动扫地机器人', '理想家', '激光导航', 21, 7, 2499.00, 1500.00, 'on', '2025-01-01', now(), now()),
    (36, 'P30026', 'SKU-F2', '75寸智能电视', '理想家', '4K', 21, 7, 4599.00, 3300.00, 'on', '2025-01-01', now(), now()),
    (37, 'P30027', 'SKU-V1', '视频平台年卡', '云享', '12个月', 22, 8, 258.00, 100.00, 'on', '2025-01-01', now(), now()),
    (38, 'P30028', 'SKU-V2', '云存储会员年卡', '云享', '2TB', 22, 8, 198.00, 70.00, 'on', '2025-01-01', now(), now()),
    (39, 'P30029', 'SKU-S1', '冷鲜牛肉家庭套餐', '鲜选', '2kg', 23, 8, 199.00, 120.00, 'on', '2025-01-01', now(), now()),
    (40, 'P30030', 'SKU-S2', '鲜活基围虾', '鲜选', '500g', 23, 8, 89.00, 50.00, 'on', '2025-01-01', now(), now()),
    (41, 'P30031', 'SKU-FR1', '山东红富士苹果', '果乐园', '5kg', 24, 8, 49.90, 30.00, 'on', '2025-01-01', now(), now()),
    (42, 'P30032', 'SKU-FR2', '海南贵妃芒果', '果乐园', '2.5kg', 24, 8, 59.90, 35.00, 'on', '2025-01-01', now(), now()),
    (43, 'P30033', 'SKU-P1', '真无线蓝牙耳机', '声界', '白色', 25, 8, 299.00, 150.00, 'on', '2025-01-01', now(), now()),
    (44, 'P30034', 'SKU-P2', '智能运动手表', '声界', '黑色', 25, 8, 899.00, 520.00, 'on', '2025-01-01', now(), now());

-- 调整原有商家与商品的所属大类，保证一个商家只经营一个大类
UPDATE public.dim_merchant
SET region_key = 85,
    updated_at = now()
WHERE merchant_key = 3;

UPDATE public.dim_product
SET merchant_key = 16
WHERE product_key IN (4, 9, 10);

UPDATE public.dim_product
SET merchant_key = 3,
    category_key = 6
WHERE product_key = 7;

UPDATE public.dim_product
SET category_key = 6
WHERE product_key = 8;

UPDATE public.dim_product
SET category_key = 21
WHERE product_key IN (4, 9, 10);

UPDATE public.dim_product
SET merchant_key = CASE category_key
    WHEN 9 THEN 4
    WHEN 10 THEN 5
    WHEN 11 THEN 6
    WHEN 12 THEN 7
    WHEN 13 THEN 8
    WHEN 14 THEN 9
    WHEN 15 THEN 10
    WHEN 16 THEN 11
    WHEN 17 THEN 12
    WHEN 18 THEN 13
    WHEN 19 THEN 14
    WHEN 20 THEN 15
    WHEN 21 THEN 16
    WHEN 22 THEN 17
    WHEN 23 THEN 18
    WHEN 24 THEN 19
    WHEN 25 THEN 20
    ELSE merchant_key
END
WHERE product_key BETWEEN 11 AND 44;

-- 补充 2025-2026 大促
INSERT INTO public.dim_promotion (
    promotion_key,
    promotion_id,
    promotion_name,
    promotion_type,
    discount_type,
    discount_value,
    start_at,
    end_at,
    status,
    created_at
) OVERRIDING SYSTEM VALUE
VALUES
    (4, 'PR2025_618', '2025 618 年中大促', 'full_reduction', 'amount', 50.00, '2025-06-01 00:00:00+08', '2025-06-20 23:59:59+08', 'ended', now()),
    (5, 'PR2025_1111', '2025 双11 狂欢节', 'full_reduction', 'amount', 80.00, '2025-10-20 00:00:00+08', '2025-11-12 23:59:59+08', 'ended', now()),
    (6, 'PR2025_1212', '2025 双12 盛典', 'full_reduction', 'amount', 60.00, '2025-12-01 00:00:00+08', '2025-12-13 23:59:59+08', 'ended', now()),
    (7, 'PR2026_DD', '双旦礼遇季', 'coupon', 'amount', 40.00, '2025-12-20 00:00:00+08', '2026-01-03 23:59:59+08', 'ended', now()),
    (8, 'PR2026_618', '2026 618 年中大促', 'full_reduction', 'amount', 60.00, '2026-06-01 00:00:00+08', '2026-06-20 23:59:59+08', 'ended', now());

-- 补充用户：100 人公司收件场景 + 100 人全国普通用户
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
    status,
    created_at,
    updated_at
) OVERRIDING SYSTEM VALUE
SELECT
    13 + i,
    'U30000' || lpad((13 + i)::text, 4, '0'),
    CASE WHEN i <= 100 THEN '公司同事' || i ELSE '网友' || i END,
    '15' || lpad((30000000 + i)::text, 8, '0'),
    CASE i % 3 WHEN 0 THEN 'M' WHEN 1 THEN 'F' ELSE 'U' END,
    CASE i % 4 WHEN 0 THEN '18-24' WHEN 1 THEN '25-34'
               WHEN 2 THEN '35-44' ELSE '45+' END,
    CASE WHEN i % 3 = 0 THEN 'gold' WHEN i % 4 = 0 THEN 'silver' ELSE 'normal' END,
    CASE WHEN i <= 100 THEN 94 ELSE 4 + ((i + 3) % 3) * 3 END,
    1 + (i % 5),
    date '2025-01-01' + (i % 600),
    'active',
    now(),
    now()
FROM generate_series(1, 200) AS i;

SELECT setval(pg_get_serial_sequence('public.dim_region', 'region_key'), (SELECT max(region_key) FROM public.dim_region));
SELECT setval(pg_get_serial_sequence('public.dim_category', 'category_key'), (SELECT max(category_key) FROM public.dim_category));
SELECT setval(pg_get_serial_sequence('public.dim_merchant', 'merchant_key'), (SELECT max(merchant_key) FROM public.dim_merchant));
SELECT setval(pg_get_serial_sequence('public.dim_product', 'product_key'), (SELECT max(product_key) FROM public.dim_product));
SELECT setval(pg_get_serial_sequence('public.dim_promotion', 'promotion_key'), (SELECT max(promotion_key) FROM public.dim_promotion));
SELECT setval(pg_get_serial_sequence('public.dim_user', 'user_key'), (SELECT max(user_key) FROM public.dim_user));

-- 批量生成 2025-01-01 至脚本运行当日（Asia/Shanghai）的订单
DO $$
DECLARE
    v_day integer;
    v_max_day integer;
    v_order_seq bigint := 0;
    v_date date;
    v_date_key integer;
    v_orders_today integer;
    v_order_index integer;
    v_order_key bigint;
    v_order_no varchar(64);
    v_user_key bigint;
    v_channel_key bigint;
    v_region_key bigint;
    v_promotion_key bigint;
    v_category_key bigint;
    v_product_key bigint;
    v_merchant_key bigint;
    v_product_name varchar(255);
    v_category_name varchar(64);
    v_price numeric(12,2);
    v_quantity integer;
    v_goods_amount numeric(12,2);
    v_discount_amount numeric(12,2);
    v_freight_amount numeric(12,2);
    v_pay_amount numeric(12,2);
    v_status varchar(16);
    v_order_created_at timestamptz;
    v_paid_at timestamptz;
    v_received_at timestamptz;
    v_completed_at timestamptz;
    v_logistics_key bigint;
    v_logistics_company varchar(64);
    v_province_name varchar(64);
    v_city_name varchar(64);
    v_district_name varchar(64);
    v_detail_address varchar(255);
    v_recipient_name varchar(64);
    v_recipient_phone varchar(32);
    v_roll numeric;
    v_phone_group integer;
    v_district_pool bigint[];
BEGIN
    PERFORM setseed(0.20260910);

    v_district_pool := ARRAY[
        13, 16, 19, 22, 25, 28, 31, 34, 37, 40, 43, 46, 49, 52, 55,
        58, 61, 64, 67, 70, 73, 76, 79, 82, 85, 88, 91, 4, 10, 94
    ];

    -- 以上海时区当日为上限；日期维度当前覆盖到 2027-12-31。
    v_max_day := greatest(
        0,
        least(
            (current_timestamp AT TIME ZONE 'Asia/Shanghai')::date,
            date '2027-12-31'
        ) - date '2025-01-01'
    );

    FOR v_day IN 0..v_max_day LOOP
        v_date := date '2025-01-01' + v_day;
        v_date_key := (to_char(v_date, 'YYYYMMDD'))::integer;

        v_orders_today := 18 + floor(random() * 18)::integer;

        IF (v_date BETWEEN date '2025-06-01' AND date '2025-06-18')
           OR (v_date BETWEEN date '2026-06-01' AND date '2026-06-18') THEN
            v_orders_today := 70 + floor(random() * 70)::integer;
        ELSIF v_date BETWEEN date '2025-10-20' AND date '2025-11-12' THEN
            v_orders_today := 60 + floor(random() * 64)::integer;
        ELSIF v_date BETWEEN date '2025-12-01' AND date '2025-12-13' THEN
            v_orders_today := 50 + floor(random() * 52)::integer;
        ELSIF v_date BETWEEN date '2025-12-20' AND date '2026-01-03' THEN
            v_orders_today := 45 + floor(random() * 46)::integer;
        END IF;

        FOR v_order_index IN 1..v_orders_today LOOP
            v_order_seq := v_order_seq + 1;
            v_order_key := 100000 + v_order_seq;
            v_order_no := 'XM' || v_date_key || lpad(v_order_seq::text, 7, '0');
            v_promotion_key := NULL;

            v_roll := random();
            IF v_roll < 0.15 THEN
                v_user_key := 1 + floor(random() * 4)::integer;
            ELSIF v_roll < 0.45 THEN
                v_user_key := 14 + floor(random() * 100)::integer;
            ELSIF v_roll < 0.70 THEN
                v_user_key := 5 + floor(random() * 9)::integer;
            ELSE
                v_user_key := 114 + floor(random() * 100)::integer;
            END IF;

            v_channel_key := 1 + floor(random() * 5)::integer;

            v_roll := random();
            IF v_roll < 0.25 THEN
                v_region_key := (ARRAY[4, 10, 94])[1 + floor(random() * 3)::integer];
            ELSE
                v_region_key := v_district_pool[1 + floor(random() * array_length(v_district_pool, 1))::integer];
            END IF;

            v_recipient_name := '收件人' || v_user_key;
            v_recipient_phone := '136' || lpad((10000000 + v_user_key)::text, 8, '0');
            v_detail_address := v_district_name || '示例路' || (v_order_seq % 900 + 1) || '号';

            IF v_user_key BETWEEN 1 AND 4 THEN
                v_roll := random();
                IF v_user_key = 1 THEN
                    v_recipient_name := '张女士';
                    IF v_roll < 0.60 THEN
                        v_region_key := 4;
                        v_detail_address := '文一西路100号 1幢201';
                    ELSIF v_roll < 0.85 THEN
                        v_region_key := 94;
                        v_detail_address := '世纪大道100号 2801室';
                    ELSE
                        v_region_key := 13;
                        v_detail_address := '中山东路12号 3幢502';
                    END IF;
                ELSE
                    v_recipient_name := '张女士';
                    IF v_roll < 0.80 THEN
                        v_region_key := 4;
                        v_detail_address := '文一西路100号 1幢201';
                    END IF;
                END IF;
            ELSIF v_user_key BETWEEN 14 AND 113 THEN
                v_recipient_name := '王女士';
                IF random() < 0.85 THEN
                    v_region_key := 94;
                    v_detail_address := '张江高科技园区博云路2号 A座';
                END IF;
            END IF;

            IF v_user_key BETWEEN 1 AND 3 THEN
                v_recipient_phone := '13800001111';
            ELSIF v_user_key = 4 THEN
                v_recipient_phone := '13711112222';
            ELSIF v_user_key BETWEEN 114 AND 133 THEN
                v_phone_group := floor((v_user_key - 114) / 2)::integer + 1;
                v_recipient_phone := '136' || lpad((20000000 + v_phone_group)::text, 8, '0');
            ELSIF v_user_key BETWEEN 134 AND 145 THEN
                v_phone_group := floor((v_user_key - 134) / 3)::integer + 1;
                v_recipient_phone := '137' || lpad((30000000 + v_phone_group)::text, 8, '0');
            END IF;

            SELECT
                split_part(region_path, '/', 2),
                split_part(region_path, '/', 3),
                split_part(region_path, '/', 4)
            INTO v_province_name, v_city_name, v_district_name
            FROM public.dim_region
            WHERE region_key = v_region_key;

            IF v_detail_address IS NULL OR v_detail_address = '' THEN
                v_detail_address := v_district_name || '示例路' || (v_order_seq % 900 + 1) || '号';
            END IF;

            IF v_date BETWEEN date '2025-06-01' AND date '2025-06-18'
               AND random() < 0.80 THEN
                v_promotion_key := 4;
            ELSIF v_date BETWEEN date '2025-10-20' AND date '2025-11-12'
               AND random() < 0.80 THEN
                v_promotion_key := 5;
            ELSIF v_date BETWEEN date '2025-12-01' AND date '2025-12-13'
               AND random() < 0.80 THEN
                v_promotion_key := 6;
            ELSIF v_date BETWEEN date '2025-12-20' AND date '2026-01-03'
               AND random() < 0.80 THEN
                v_promotion_key := 7;
            ELSIF v_date BETWEEN date '2026-06-01' AND date '2026-06-18'
               AND random() < 0.80 THEN
                v_promotion_key := 8;
            END IF;

            v_roll := random() * 100;
            IF v_roll < 30 THEN
                v_category_key := 9 + floor(random() * 6)::integer;
            ELSIF v_roll < 52 THEN
                v_category_key := 15 + floor(random() * 4)::integer;
            ELSIF v_roll < 67 THEN
                v_category_key := 19 + floor(random() * 2)::integer;
            ELSIF v_roll < 76 THEN
                v_category_key := 21;
            ELSE
                v_category_key := 22 + floor(random() * 4)::integer;
            END IF;

            SELECT product_key
            INTO v_product_key
            FROM public.dim_product
            WHERE category_key = v_category_key
            ORDER BY random()
            LIMIT 1;

            SELECT product_name, merchant_key, reference_price
            INTO v_product_name, v_merchant_key, v_price
            FROM public.dim_product
            WHERE product_key = v_product_key;

            SELECT category_name
            INTO v_category_name
            FROM public.dim_category
            WHERE category_key = v_category_key;

            v_quantity := 1 + floor(random() * 2)::integer;
            v_goods_amount := round(v_price * v_quantity, 2);
            v_discount_amount := 0;
            IF v_promotion_key IS NOT NULL AND random() < 0.50 THEN
                v_discount_amount := LEAST(
                    CASE v_promotion_key
                        WHEN 4 THEN 30
                        WHEN 5 THEN 60
                        WHEN 6 THEN 40
                        WHEN 7 THEN 25
                        ELSE 45
                    END,
                    round(v_goods_amount * 0.20, 2)
                );
            END IF;
            v_freight_amount := CASE
                WHEN v_category_key = 21 THEN 50
                WHEN v_category_key IN (23, 24) THEN 10
                ELSE 0
            END;
            v_pay_amount := v_goods_amount - v_discount_amount + v_freight_amount;

            v_roll := random();
            IF v_roll < 0.45 THEN
                v_status := 'completed';
            ELSIF v_roll < 0.65 THEN
                v_status := 'shipped';
            ELSIF v_roll < 0.80 THEN
                v_status := 'paid';
            ELSIF v_roll < 0.92 THEN
                v_status := 'pending_payment';
            ELSE
                v_status := 'cancelled';
            END IF;

            v_order_created_at := (
                (v_date + time '09:30:00')
                + (v_order_seq % 10) * interval '1 hour'
                + (v_order_seq % 60) * interval '1 minute'
            )::timestamptz;
            v_paid_at := CASE
                WHEN v_status IN ('paid', 'shipped', 'completed')
                    THEN v_order_created_at + interval '6 minute'
                ELSE NULL
            END;
            v_received_at := CASE
                WHEN v_status = 'completed' THEN v_order_created_at + interval '2 day'
                ELSE NULL
            END;
            v_completed_at := CASE
                WHEN v_status = 'completed' THEN v_received_at + interval '3 minute'
                ELSE NULL
            END;

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
                v_goods_amount,
                v_discount_amount,
                v_freight_amount,
                v_pay_amount,
                v_quantity,
                v_order_created_at,
                v_paid_at,
                v_received_at,
                CASE WHEN v_status = 'cancelled' THEN v_order_created_at + interval '1 hour' ELSE NULL END,
                v_completed_at
            );

            v_logistics_key := NULL;
            IF v_status IN ('shipped', 'completed') THEN
                v_logistics_key := 200000 + v_order_seq;
                v_logistics_company := CASE
                    WHEN v_order_seq % 3 = 0 THEN '顺丰速运'
                    WHEN v_order_seq % 3 = 1 THEN '圆通速递'
                    ELSE '中通快递'
                END;

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
                    'EXLOG' || lpad(v_order_seq::text, 9, '0'),
                    v_order_key,
                    v_logistics_company,
                    CASE WHEN v_status = 'completed' THEN 'signed' ELSE 'in_transit' END,
                    CASE WHEN v_status = 'completed' THEN v_received_at ELSE v_order_created_at + interval '1 day' END,
                    v_order_created_at + interval '8 hour',
                    CASE WHEN v_status = 'completed' THEN v_received_at ELSE NULL END,
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
                    300000 + v_order_seq,
                    v_logistics_key,
                    v_order_key,
                    'shipped',
                    '已发货',
                    v_order_created_at + interval '8 hour',
                    v_province_name,
                    '发货仓',
                    NULL,
                    '商家已发货'
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
                    400000 + v_order_seq,
                    v_logistics_key,
                    v_order_key,
                    CASE WHEN v_status = 'completed' THEN 'signed' ELSE 'in_transit' END,
                    CASE WHEN v_status = 'completed' THEN '已签收' ELSE '运输中' END,
                    CASE WHEN v_status = 'completed' THEN v_received_at ELSE v_order_created_at + interval '1 day' END,
                    v_city_name,
                    '物流网点',
                    CASE WHEN v_status = 'completed' THEN v_recipient_name ELSE NULL END,
                    CASE WHEN v_status = 'completed' THEN '快件已签收' ELSE '快件运输中' END
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
                500000 + v_order_seq,
                v_order_key,
                '001',
                v_date_key,
                v_product_key,
                v_merchant_key,
                v_promotion_key,
                v_quantity,
                v_price,
                v_discount_amount,
                v_goods_amount - v_discount_amount,
                'normal',
                v_status,
                v_paid_at,
                v_received_at,
                v_status IN ('shipped', 'completed'),
                v_region_key,
                v_province_name,
                v_city_name,
                v_district_name,
                v_detail_address,
                v_recipient_name,
                v_recipient_phone,
                v_product_name,
                v_category_name,
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
                    600000 + v_order_seq,
                    'EXPAY' || lpad(v_order_seq::text, 10, '0'),
                    v_order_key,
                    v_date_key,
                    1 + floor(random() * 4)::integer,
                    v_pay_amount,
                    'success',
                    v_paid_at,
                    v_paid_at + interval '30 second',
                    'EXTRADE' || lpad(v_order_seq::text, 12, '0')
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
                700000 + v_order_seq,
                'EXEV' || lpad(v_order_seq::text, 10, '0'),
                v_date_key,
                v_user_key,
                v_channel_key,
                v_region_key,
                v_product_key,
                v_order_key,
                'EXSESS' || lpad(v_order_seq::text, 9, '0'),
                'order_confirm',
                'submit_order',
                v_order_created_at,
                jsonb_build_object('order_no', v_order_no)
            );
        END LOOP;
    END LOOP;
END;
$$;

-- 同步所有显式插入的自增键
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
