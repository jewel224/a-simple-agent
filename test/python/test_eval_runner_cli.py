import unittest

from app.governance.eval_runner import parse_args


class EvalRunnerCliTest(unittest.TestCase):
    """验证评测命令行参数解析。"""

    def test_limit_argument_is_parsed(self):
        self.assertEqual(parse_args(["12"]).limit, 12)

    def test_limit_is_optional(self):
        self.assertIsNone(parse_args([]).limit)


if __name__ == "__main__":
    unittest.main()
