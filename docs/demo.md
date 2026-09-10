# 演示脚本

本文档给出一组可以直接向订单助手提问的问题、对应 SQL 和预期结果。

## 场景 1：订单总量与客单价

提问：

```text
当前一共有多少订单？平均实付金额是多少？
```

SQL：

```sql
SELECT count(*) AS order_count,
       round(avg(pay_amount), 2) AS avg_pay_amount
FROM fact_order;
```

预期结果：

| order_count | avg_pay_amount |
| ---: | ---: |
| 22307 | 934.53 |

预期解释：

```text
当前共有 22307 个订单，平均实付金额为 934.53 元。
```

## 场景 2：收货省份排名

提问：

```text
哪些省份的订单最多？列出前五名。
```

SQL：

```sql
SELECT shipping_province_name,
       count(*) AS item_count
FROM fact_order_item
GROUP BY shipping_province_name
ORDER BY item_count DESC
LIMIT 5;
```

预期结果：

| 省份 | 明细数 |
| --- | ---: |
| 上海市 | 7314 |
| 浙江省 | 4123 |
| 江苏省 | 1585 |
| 河北省 | 445 |
| 西藏自治区 | 378 |

预期结论：

```text
订单主要集中在江浙沪地区，其中上海、浙江、江苏排在前三位。
```

## 场景 3：类目订单结构

提问：

```text
女士相关、婴童类、男士相关和家具家电，哪一类订单最多？
```

SQL：

```sql
SELECT CASE
         WHEN p.category_key BETWEEN 9 AND 14 THEN '女士相关'
         WHEN p.category_key BETWEEN 15 AND 18 THEN '婴童类'
         WHEN p.category_key BETWEEN 19 AND 20 THEN '男士相关'
         WHEN p.category_key = 21 THEN '家具家电'
         ELSE '其他'
       END AS category_group,
       count(*) AS item_count
FROM fact_order_item oi
JOIN dim_product p ON p.product_key = oi.product_key
GROUP BY 1
ORDER BY item_count DESC;
```

预期结果：

| 类目组 | 明细数 |
| --- | ---: |
| 女士相关 | 6804 |
| 其他 | 5331 |
| 婴童类 | 4800 |
| 男士相关 | 3356 |
| 家具家电 | 2018 |

预期结论：

```text
女士相关商品订单最多，其次是婴童类，之后是男士相关，家具家电最少。
```

## 场景 4：大促订单量

提问：

```text
2025 年双11 期间有多少订单？和普通日期相比是否明显更多？
```

SQL：

```sql
SELECT count(*) AS order_count
FROM fact_order
WHERE date_key BETWEEN 20251020 AND 20251112;
```

预期结果约为：

```text
1800 单左右
```

预期解释：

```text
2025 双11 覆盖约 24 天，订单量明显超过普通日期的平均水平。
```

## 场景 5：商家与类目

提问：

```text
哪些商家经营的类目最集中？一个商家是否只经营一个大类？
```

预期结论：

```text
共 20 个商家，每个商家只经营一个大类。
```

参考 SQL：

```sql
SELECT m.merchant_name,
       count(DISTINCT p.category_key) AS category_count
FROM dim_merchant m
JOIN dim_product p ON p.merchant_key = m.merchant_key
GROUP BY m.merchant_name
ORDER BY category_count DESC, m.merchant_name;
```

## 新手观察重点

- 大模型每次生成的 SQL 可能略有不同，但查询结果应保持一致。
- 如果 Agent 给出业务结论，应同时检查它使用的数据是否来自 SQL 工具。
- 遇到金额、订单量、退款率等问题，优先要求 Agent 展示 SQL。
- 如果 SQL 执行失败，让 Agent 根据错误信息修正字段或表名。