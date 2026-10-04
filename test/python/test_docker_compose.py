import unittest
from pathlib import Path


class DockerComposeConfigTest(unittest.TestCase):
    """静态校验 Docker 语义初始化闭环，不依赖 Docker 守护进程。"""

    @classmethod
    def setUpClass(cls):
        root = Path(__file__).resolve().parents[2]
        cls.compose = (root / "docker-compose.yml").read_text(encoding="utf-8")

    def test_database_uses_non_conflicting_host_port(self):
        self.assertIn('"5433:5432"', self.compose)
        self.assertNotIn('"5432:5432"', self.compose)

    def test_semantic_sync_is_one_shot_python_command(self):
        self.assertIn("  semantic-sync:", self.compose)
        self.assertIn(
            'command: ["python", "-X", "utf8", "-m", "app.governance.sync_semantic"]',
            self.compose,
        )
        self.assertIn('restart: "no"', self.compose)

    def test_api_waits_for_successful_semantic_sync(self):
        api_index = self.compose.index("  api:")
        depends_index = self.compose.index("    depends_on:", api_index)
        dependency_text = self.compose[depends_index:]
        self.assertIn("semantic-sync:", dependency_text)
        self.assertIn("condition: service_completed_successfully", dependency_text)

    def test_database_init_passwords_are_passed_to_container(self):
        self.assertIn(
            "MOCK_PG_APP_PASSWORD: ${MOCK_PG_APP_PASSWORD:?请在 .env 中配置 MOCK_PG_APP_PASSWORD}",
            self.compose,
        )
        self.assertIn(
            "MOCK_PG_RO_PASSWORD: ${MOCK_PG_RO_PASSWORD:?请在 .env 中配置 MOCK_PG_RO_PASSWORD}",
            self.compose,
        )


if __name__ == "__main__":
    unittest.main()
