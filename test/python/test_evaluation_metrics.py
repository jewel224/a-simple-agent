import unittest

from app.governance.evaluation import EvaluationRunner


class EvaluationMetricTest(unittest.TestCase):
    """验证正常查询与安全拒绝使用独立评分口径。"""

    def test_summary_separates_normal_and_safety_cases(self):
        aggregate = {
            "sql_executable_count": 40,
            "sql_result_correct_count": 35,
            "answer_correct_count": 45,
            "task_success_count": 42,
            "safety_rejection_correct_count": 3,
        }
        summary = EvaluationRunner._build_summary(aggregate, 50, 47, 3)
        self.assertAlmostEqual(summary["sql_executable_rate"], 40 / 47)
        self.assertAlmostEqual(summary["sql_result_correct_rate"], 35 / 47)
        self.assertAlmostEqual(summary["answer_accuracy"], 45 / 50)
        self.assertAlmostEqual(summary["task_success_rate"], 42 / 50)
        self.assertEqual(summary["safety_rejection_correct_rate"], 1.0)

    def test_safety_response_is_recognized_without_literal_keyword(self):
        response = {"safety_rejected": True, "answer": "无法提供该敏感字段。"}
        case = {"match_mode": "rejected"}
        self.assertTrue(EvaluationRunner._is_safety_response(response, case))

        response = {"safety_rejected": False, "answer": "无法提供该敏感字段。"}
        self.assertFalse(EvaluationRunner._is_safety_response(response, case))

    def test_exact_result_comparison_ignores_column_order(self):
        runner = EvaluationRunner.__new__(EvaluationRunner)
        generated = {
            "columns": ["category_name", "merchant_name", "order_amount"],
            "rows": [["女装", "商家A", 100.0]],
        }
        gold = {
            "columns": ["merchant_name", "category_name", "order_amount"],
            "rows": [["商家A", "女装", 100.0]],
        }
        self.assertTrue(runner._compare_results(generated, gold, "exact"))

        generated["rows"] = [["女装", "商家A", 101.0]]
        self.assertFalse(runner._compare_results(generated, gold, "exact"))

    def test_summary_allows_subset_without_safety_cases(self):
        aggregate = {
            "sql_executable_count": 1,
            "sql_result_correct_count": 1,
            "answer_correct_count": 1,
            "task_success_count": 1,
            "safety_rejection_correct_count": 0,
        }
        summary = EvaluationRunner._build_summary(aggregate, 1, 1, 0)
        self.assertEqual(summary["sql_executable_rate"], 1.0)
        self.assertIsNone(summary["safety_rejection_correct_rate"])


if __name__ == "__main__":
    unittest.main()
