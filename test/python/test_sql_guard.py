import json
import unittest

from app.governance.sql_guard import scoped_sql_validation, validate_sql
from app.governance.tool import GovernedSQLTool, SQLToolResult, _last_tool_result, reset_last_tool_result


class SQLGuardScopeTest(unittest.TestCase):
    """验证 SQLGuard 的全局安全规则和请求级语义范围。"""

    def test_scoped_query_allows_hit_tables_columns_and_join_keys(self):
        tables = {"fact_payment", "dim_payment_method", "dim_date"}
        columns = {
            ("fact_payment", "pay_amount"),
            ("dim_payment_method", "method_name"),
            ("dim_date", "year"),
            ("dim_date", "month"),
        }
        sql = """
        SELECT pm.method_name, SUM(fp.pay_amount) AS pay_amount, COUNT(*) AS payment_count
        FROM fact_payment fp
        JOIN dim_payment_method pm ON fp.payment_method_key = pm.payment_method_key
        JOIN dim_date dt ON fp.date_key = dt.date_key
        WHERE dt.year = 2025 AND dt.month = 11
        GROUP BY pm.method_name
        """
        with scoped_sql_validation(tables, columns):
            normalized = validate_sql(sql)
        self.assertIn("fact_payment", normalized)

    def test_scoped_query_allows_dimension_business_columns_for_hit_tables(self):
        tables = {"fact_order_item", "dim_category", "dim_date"}
        columns = {("fact_order_item", "item_amount")}
        sql = """
        SELECT dc.category_name, dt.year, dt.month, SUM(foi.item_amount) AS order_amount
        FROM fact_order_item foi
        JOIN dim_category dc ON foi.category_key = dc.category_key
        JOIN dim_date dt ON foi.date_key = dt.date_key
        WHERE dt.year = 2025 AND dt.month = 11
        GROUP BY dc.category_name, dt.year, dt.month
        """
        with scoped_sql_validation(tables, columns):
            normalized = validate_sql(sql)
        self.assertIn("category_name", normalized)

    def test_scoped_query_rejects_other_columns_on_hit_dimension(self):
        tables = {"dim_category"}
        columns = set()
        with scoped_sql_validation(tables, columns):
            with self.assertRaisesRegex(Exception, "当前问题不允许访问字段"):
                validate_sql("SELECT category_name FROM dim_category WHERE status = true LIMIT 1")

    def test_scoped_query_allows_cte_output_columns_in_outer_query(self):
        tables = {"fact_order_item", "dim_category", "dim_date"}
        columns = {("fact_order_item", "item_amount")}
        sql = """
        WITH category_monthly AS (
            SELECT dc.category_name, SUM(cm.item_amount) AS order_amount
            FROM fact_order_item cm
            JOIN dim_category dc ON cm.category_key = dc.category_key
            JOIN dim_date dt ON cm.date_key = dt.date_key
            WHERE dt.year = 2025 AND dt.month = 11
            GROUP BY dc.category_name
        )
        SELECT cm.category_name, cm.order_amount
        FROM category_monthly AS cm
        ORDER BY cm.order_amount DESC
        """
        with scoped_sql_validation(tables, columns):
            normalized = validate_sql(sql)
        self.assertIn("category_monthly", normalized)

    def test_scoped_query_allows_select_alias_in_order_by(self):
        tables = {"fact_order_item", "dim_category"}
        columns = {("fact_order_item", "item_amount")}
        sql = """
        SELECT dc.category_name, SUM(foi.item_amount) AS order_amount
        FROM fact_order_item foi
        JOIN dim_category dc ON foi.category_key = dc.category_key
        GROUP BY dc.category_name
        ORDER BY order_amount DESC
        """
        with scoped_sql_validation(tables, columns):
            normalized = validate_sql(sql)
        self.assertIn("order_amount", normalized)

    def test_scoped_query_rejects_table_outside_semantic_context(self):
        with scoped_sql_validation({"dim_date"}, {("dim_date", "year")}):
            with self.assertRaisesRegex(Exception, "当前问题不允许访问表"):
                validate_sql("SELECT order_no FROM fact_order LIMIT 1")

    def test_scoped_query_rejects_column_outside_semantic_context(self):
        tables = {"fact_payment", "dim_date"}
        columns = {("fact_payment", "pay_amount"), ("dim_date", "year")}
        with scoped_sql_validation(tables, columns):
            with self.assertRaisesRegex(Exception, "当前问题不允许访问字段"):
                validate_sql("SELECT fp.refund_amount FROM fact_payment fp LIMIT 1")

    def test_scoped_query_rejects_select_star(self):
        tables = {"fact_payment"}
        columns = {("fact_payment", "pay_amount")}
        with scoped_sql_validation(tables, columns):
            with self.assertRaisesRegex(Exception, "不允许 SELECT"):
                validate_sql("SELECT * FROM fact_payment LIMIT 1")

    def test_fact_order_item_rejects_select_star_but_allows_count_star(self):
        with self.assertRaisesRegex(Exception, "不允许 SELECT"):
            validate_sql("SELECT * FROM fact_order_item LIMIT 1")
        validate_sql("SELECT COUNT(*) FROM fact_order_item")

    def test_tool_validation_error_returns_structured_json(self):
        reset_last_tool_result()
        result = json.loads(GovernedSQLTool().call(json.dumps({"sql_input": "SELECT * FROM fact_order_item"})))
        self.assertEqual(result["error"]["code"], "INVALID_SQL")
        self.assertEqual(result["row_count"], 0)
        self.assertIsNone(_last_tool_result.get())

    def test_tool_result_is_reset(self):
        _last_tool_result.set(SQLToolResult(sql="SELECT 1"))
        reset_last_tool_result()
        self.assertIsNone(_last_tool_result.get())


if __name__ == "__main__":
    unittest.main()
