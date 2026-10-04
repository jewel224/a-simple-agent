import unittest
from uuid import UUID

from app.governance.schemas import QueryResponse, UsedMetadata

from app.governance.errors import AgentExecutionError
from app.governance.service import GovernedAgentService


class AgentResponseExtractTest(unittest.TestCase):
    """验证 Agent 答案提取兼容 qwen-agent 的消息结构。"""

    def test_extracts_text_from_nested_message_list(self):
        service = GovernedAgentService.__new__(GovernedAgentService)
        messages = [
            [
                {"role": "user", "content": "查询品类金额"},
                {"role": "assistant", "content": [{"text": "11月品类金额如下"}]},
            ]
        ]
        self.assertEqual(service._extract_text(messages), "11月品类金额如下")

    def test_recognizes_explicit_safety_rejection(self):
        service = GovernedAgentService.__new__(GovernedAgentService)
        self.assertTrue(
            service._is_safety_rejection(
                "查询订单明细中的收件人姓名",
                "该请求包含敏感信息，无法提供收件人姓名。",
            )
        )
        self.assertFalse(
            service._is_safety_rejection(
                "2025年11月哪些省份订单量最高",
                "paid_at 被判定为敏感信息，无法提供。",
            )
        )

    def test_query_response_allows_empty_sql_for_safety_rejection(self):
        response = QueryResponse(
            trace_id=UUID("12345678-1234-4123-8123-123456789123"),
            session_id=UUID("12345678-1234-4123-8123-123456789123"),
            answer="该请求包含敏感信息，无法提供。",
            safety_rejected=True,
            used_metadata=UsedMetadata(),
        )
        self.assertIsNone(response.sql)
        self.assertEqual(response.columns, [])
        self.assertEqual(response.row_count, 0)

    def test_rejects_nested_messages_without_assistant_text(self):
        service = GovernedAgentService.__new__(GovernedAgentService)
        with self.assertRaises(AgentExecutionError):
            service._extract_text([[{"role": "user", "content": "查询品类金额"}]])


if __name__ == "__main__":
    unittest.main()
