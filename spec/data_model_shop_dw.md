# shop_dw 数据模型

## 1. 模型概览

`shop_dw` 是手机购物 App 的直接星型数仓，共 16 张表：9 张维度表、7 张事实表。

```text
维度表：
dim_date / dim_region / dim_channel / dim_user / dim_category
/ dim_merchant / dim_product / dim_promotion / dim_payment_method

事实表：
fact_order / fact_order_item / fact_payment / fact_refund
/ fact_app_event / fact_logistics_order / fact_logistics_trace
```

统一约定：

- `xxx_key` 为代理键，使用 `BIGINT GENERATED ALWAYS AS IDENTITY`。
- 业务编号使用 `VARCHAR + UNIQUE`。
- 金额使用 `NUMERIC(12,2)`，并设置非负 CHECK。
- 时间使用 `TIMESTAMPTZ`。
- 所有外键默认 `ON DELETE RESTRICT`。

## 2. 维度表

### dim_date 日期维

字段：`date_key`、`calendar_date`、`year`、`quarter`、`month`、`day`、`week_of_year`、`day_of_week`、`day_name_cn`、`is_weekend`、`is_holiday`。

被以下事实表引用：`fact_order.date_key`、`fact_order_item.date_key`、`fact_payment.date_key`、`fact_refund.date_key`、`fact_app_event.date_key`。

### dim_region 地区维

字段：`region_key`、`region_code`、`region_name`、`region_type`、`parent_region_key`、`level`、`region_path`、`status`、`created_at`。

外键：

- `parent_region_key` 自引用 `dim_region.region_key`。
- 被 `dim_user.default_region_key`、`dim_merchant.region_key`、`fact_order.shipping_region_key`、`fact_order_item.shipping_region_key`、`fact_app_event.region_key` 引用。

### dim_channel 渠道维

字段：`channel_key`、`channel_code`、`channel_name`、`channel_type`、`platform`、`device_platform`、`is_paid`、`status`、`created_at`。

被 `dim_user.register_channel_key`、`fact_order.channel_key`、`fact_app_event.channel_key` 引用。

### dim_user 用户维

字段：`user_key`、`user_id`、`nickname_masked`、`phone_masked`、`gender_code`、`age_group`、`member_level`、`default_region_key`、`register_channel_key`、`registration_date`、`status`、`created_at`、`updated_at`。

外键：`default_region_key` 引用 `dim_region`，`register_channel_key` 引用 `dim_channel`。

被 `fact_order.user_key`、`fact_refund.user_key`、`fact_app_event.user_key` 引用。

### dim_category 品类维

字段：`category_key`、`category_code`、`category_name`、`parent_category_key`、`category_level`、`sort_no`、`status`、`created_at`。

外键：`parent_category_key` 自引用 `dim_category.category_key`。

被 `dim_product.category_key` 引用。

### dim_merchant 商家维

字段：`merchant_key`、`merchant_id`、`merchant_name`、`merchant_type`、`merchant_level`、`region_key`、`service_score`、`status`、`opened_at`、`created_at`、`updated_at`。

外键：`region_key` 引用 `dim_region`。

被 `dim_product.merchant_key`、`fact_order_item.merchant_key` 引用。

### dim_product 商品维

字段：`product_key`、`product_id`、`sku_code`、`product_name`、`brand`、`spec`、`category_key`、`merchant_key`、`reference_price`、`cost_price`、`shelf_status`、`on_shelf_at`、`off_shelf_at`、`created_at`、`updated_at`。

外键：`category_key` 引用 `dim_category`，`merchant_key` 引用 `dim_merchant`。

被 `fact_order_item.product_key`、`fact_app_event.product_key` 引用。

### dim_promotion 促销维

字段：`promotion_key`、`promotion_id`、`promotion_name`、`promotion_type`、`discount_type`、`discount_value`、`start_at`、`end_at`、`status`、`created_at`。

被 `fact_order.promotion_key`、`fact_order_item.promotion_key` 引用，两者均可空。

### dim_payment_method 支付方式维

字段：`payment_method_key`、`method_code`、`method_name`、`provider`、`supported_platform`、`is_active`、`created_at`。

被 `fact_payment.payment_method_key` 引用。

## 3. 订单相关事实表

### fact_order 订单事实表

粒度：一行一个订单。

字段：

`order_key`、`order_no`、`date_key`、`user_key`、`channel_key`、`shipping_region_key`、`promotion_key`、`order_status`、`is_shipped`、`goods_amount`、`discount_amount`、`freight_amount`、`pay_amount`、`item_count`、`order_created_at`、`paid_at`、`received_at`、`cancelled_at`、`completed_at`、`updated_at`。

外键：

- `date_key` 引用 `dim_date`。
- `user_key` 引用 `dim_user`。
- `channel_key` 引用 `dim_channel`。
- `shipping_region_key` 引用 `dim_region`。
- `promotion_key` 引用 `dim_promotion`。

被 `fact_order_item.order_key`、`fact_payment.order_key`、`fact_refund.order_key`、`fact_app_event.order_key`、`fact_logistics_order.order_key`、`fact_logistics_trace.order_key` 引用。

### fact_order_item 订单明细事实表

粒度：一行一个订单中的一行商品明细。

字段：

`order_item_key`、`order_key`、`order_item_no`、`date_key`、`product_key`、`merchant_key`、`promotion_key`、`quantity`、`unit_price`、`discount_amount`、`item_amount`、`item_status`、`order_status`、`paid_at`、`received_at`、`is_shipped`、`shipping_region_key`、`shipping_province_name`、`shipping_city_name`、`shipping_district_name`、`shipping_detail_address`、`recipient_name`、`recipient_phone`、`product_name_snapshot`、`category_path_snapshot`、`logistics_order_key`、`created_at`、`updated_at`。

字段语义：

- `order_status/paid_at/received_at/is_shipped` 是订单头状态快照，便于明细级直接分析。
- 收货字段是收货地址快照，保留下单时信息。
- `product_name_snapshot/category_path_snapshot` 是下单时商品名称与类目路径快照。
- `logistics_order_key` 关联该明细对应的物流运单，v1 中一个明细对应一个运单。

外键：

- `order_key` 引用 `fact_order`。
- `date_key` 引用 `dim_date`。
- `product_key` 引用 `dim_product`。
- `merchant_key` 引用 `dim_merchant`。
- `promotion_key` 引用 `dim_promotion`。
- `shipping_region_key` 引用 `dim_region`。
- `logistics_order_key` 引用 `fact_logistics_order`。

被 `fact_refund.order_item_key` 引用。

### fact_payment 支付事实表

粒度：一行一次支付交易。

字段：`payment_key`、`payment_no`、`order_key`、`date_key`、`payment_method_key`、`pay_amount`、`payment_status`、`payment_started_at`、`payment_finished_at`、`payment_trade_no`、`error_code`、`error_message`、`updated_at`。

外键：`order_key` 引用 `fact_order`，`date_key` 引用 `dim_date`，`payment_method_key` 引用 `dim_payment_method`。

被 `fact_refund.payment_key` 引用。

### fact_refund 退款事实表

粒度：一行一次退款申请或退款结果。

字段：`refund_key`、`refund_no`、`order_key`、`order_item_key`、`payment_key`、`date_key`、`user_key`、`refund_type`、`refund_reason_code`、`refund_reason`、`refund_amount`、`refund_status`、`applied_at`、`finished_at`、`updated_at`。

外键：`order_key` 引用 `fact_order`，`order_item_key` 引用 `fact_order_item`，`payment_key` 引用 `fact_payment`，`date_key` 引用 `dim_date`，`user_key` 引用 `dim_user`。

### fact_app_event App 行为事实表

粒度：一行一次用户行为事件。

字段：`event_key`、`event_id`、`date_key`、`user_key`、`channel_key`、`region_key`、`product_key`、`order_key`、`session_id`、`page_code`、`event_type`、`event_time`、`payload`。

外键：`date_key` 引用 `dim_date`，`user_key` 引用 `dim_user`，`channel_key` 引用 `dim_channel`，`region_key/product_key/order_key` 可空并分别引用 `dim_region/dim_product/fact_order`。

## 4. 物流事实表

### fact_logistics_order 物流运单表

粒度：一行一个物流运单。

字段：`logistics_order_key`、`logistics_no`、`order_key`、`logistics_company`、`current_status`、`current_status_time`、`shipped_at`、`signed_at`、`expected_arrival_at`、`created_at`、`updated_at`。

外键：`order_key` 引用 `fact_order`。

被 `fact_order_item.logistics_order_key`、`fact_logistics_trace.logistics_order_key` 引用。

### fact_logistics_trace 物流状态流水表

粒度：一行一次物流状态更新。

字段：`logistics_trace_key`、`logistics_order_key`、`order_key`、`trace_status`、`trace_status_cn`、`trace_time`、`location_name`、`operator_name`、`signed_name`、`trace_description`、`created_at`。

状态值：`shipped` 已发货、`in_transit` 运输中、`out_for_delivery` 派送中、`signed` 已签收、`rejected` 拒收、`returning` 退回中、`returned` 已退回、`exception` 物流异常。

外键：`logistics_order_key` 引用 `fact_logistics_order`，`order_key` 引用 `fact_order`。

`fact_logistics_order.current_status` 由最新一条流水同步维护。

## 5. 关键关联汇总

- 用户、商家、商品等维度通过代理键被事实表引用。
- 订单明细同时引用订单、商品、商家、地区、促销和物流运单。
- 支付、退款、事件与物流都能通过订单事实表串联。
- 一个订单可拆多个物流运单，一个运单属于一个订单。
- 一个订单明细对应一个物流运单，同一运单可包含多个订单明细。

## 6. 扩展 Mock 场景

扩展种子数据用于模拟贴近真实购物 App 的订单分布：

- 时间跨度：2025-01-01 至 2026-09-10。
- 当前规模：约 2.2 万订单，对应明细、支付、物流运单、物流状态流水与 App 事件同步增长。
- 地区范围：覆盖全国 31 个省份/自治区/直辖市及主要产业带城市，订单集中在江浙沪地区。
- 生活类目：`女装`、`饰品`、`护肤品`、`彩妆`、`鞋子`、`包包`、`童装`、`玩具`、`童鞋`、`童书`、`男装`、`男鞋`、`家具家电`、`虚拟产品`、`生鲜`、`水果`、`手机数码`。
- 类目规模关系：女士相关订单 > 婴童类 > 男士 > 家具家电。
- 大促场景：2025/2026 618、2025 双11、2025 双12、双旦礼遇季订单明显高于日常。
- 收件地址场景：用户 1 拥有多个订单量差异明显的收件地址；家庭用户共享收件地址与手机号；100 人公司共享同一公司收件地址，但手机号不共用。
- 手机号场景：10 个手机号各由 2 人共用，5 个手机号各由 3 人共用。
- 商家场景：共 20 个商家，一个商家只经营一个大类；分布参考杭州女装、深圳饰品与数码、上海护肤、广州彩妆皮具、温州鞋业、澄海玩具、湖州童装、晋江鞋服、佛山家电等现实产业带。
