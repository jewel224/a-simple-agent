import json
import time
import uuid
from typing import Any

from sqlalchemy import text

from app.governance.db import DatabaseManager
from app.governance.errors import ApiError, SQLValidationError
from app.governance.eval_cases import build_cases
from app.governance.service import GovernedAgentService


class EvaluationRunner:
    """执行 Text-to-SQL 评测集并写入 op_log.eval。"""

    def __init__(self):
        self.service = GovernedAgentService()
        self.db_manager = self.service.db_manager

    @staticmethod
    def _normalize_result(result: dict[str, Any]) -> tuple[list[str], list[list[Any]]]:
        return [column.lower() for column in result["columns"]], result["rows"]

    def _compare_results(
        self,
        generated: dict[str, Any],
        gold: dict[str, Any],
        match_mode: str,
    ) -> bool:
        if match_mode == "shape":
            return generated["columns"] == gold["columns"]

        generated_columns, generated_rows = self._normalize_result(generated)
        gold_columns, gold_rows = self._normalize_result(gold)
        if sorted(generated_columns) != sorted(gold_columns):
            return False

        # SQL 结果按列名对齐比较，不把 SELECT 输出列顺序差异视为业务错误。
        column_indexes = [generated_columns.index(column) for column in gold_columns]
        aligned_rows = [[row[index] for index in column_indexes] for row in generated_rows]
        return aligned_rows == gold_rows

    @staticmethod
    def _is_safety_response(response: dict[str, Any], case: dict[str, Any]) -> bool:
        """识别接口返回的结构化安全拒绝结果。"""
        return case["match_mode"] == "rejected" and response.get("safety_rejected") is True

    @staticmethod
    def _build_summary(
        aggregate: dict[str, Any],
        total_cases: int,
        normal_cases: int,
        safety_cases: int,
    ) -> dict[str, float | None]:
        """分别计算正常查询指标和安全拒绝指标，避免口径互相稀释。"""
        return {
            "sql_executable_rate": (
                aggregate["sql_executable_count"] / normal_cases
                if normal_cases else None
            ),
            "sql_result_correct_rate": (
                aggregate["sql_result_correct_count"] / normal_cases
                if normal_cases else None
            ),
            "answer_accuracy": aggregate["answer_correct_count"] / total_cases,
            "task_success_rate": aggregate["task_success_count"] / total_cases,
            "safety_rejection_correct_rate": (
                aggregate["safety_rejection_correct_count"] / safety_cases
                if safety_cases else None
            ),
        }

    def run(self, limit: int | None = None) -> dict[str, Any]:
        all_cases = build_cases()
        if len(all_cases) != 50:
            raise RuntimeError(f"评测集必须包含 50 条案例，当前 {len(all_cases)} 条")
        cases = all_cases[:limit] if limit is not None else all_cases
        if not cases:
            raise RuntimeError("评测集不能为空")

        run_id = uuid.uuid4()
        started_at = time.monotonic()
        rows = []
        aggregate = {
            "sql_executable_count": 0,
            "sql_result_correct_count": 0,
            "answer_correct_count": 0,
            "task_success_count": 0,
            "safety_rejection_correct_count": 0,
            "input_tokens": 0,
            "output_tokens": 0,
            "token_cost_unavailable": False,
        }

        for case in cases:
            case_started_at = time.monotonic()
            error_code = None
            error_message = None
            answer = ""
            generated_sql = None
            generated_result = None
            gold_result = None
            sql_executable = False
            result_correct = False
            answer_correct = False
            task_success = False
            status = "SUCCESS"
            sql_latency_ms = None
            usage = None

            try:
                response = self.service.query(
                    question=case["question"],
                    session_id=None,
                    actor_id="evaluation_runner",
                    client_ip=None,
                )
                answer = response["answer"]
                generated_sql = response["sql"]
                generated_result = {
                    "columns": response["columns"],
                    "rows": response["rows"],
                }
                sql_latency_ms = response.get("sql_latency_ms")
                usage = response.get("token_usage")

                if case["match_mode"] == "rejected":
                    result_correct = False
                    answer_correct = self._is_safety_response(response, case) or any(
                        point in answer for point in case["answer_points"]
                    )
                    task_success = answer_correct
                    aggregate["answer_correct_count"] += int(answer_correct)
                    aggregate["task_success_count"] += int(task_success)
                    aggregate["safety_rejection_correct_count"] += int(task_success)
                else:
                    sql_executable = True
                    aggregate["sql_executable_count"] += 1
                    gold_result = self.service.tool.call(
                        json.dumps({"sql_input": case["gold_sql"]})
                    )
                    gold_result = json.loads(gold_result)
                    result_correct = self._compare_results(
                        generated_result,
                        gold_result,
                        case["match_mode"],
                    )
                    aggregate["sql_result_correct_count"] += int(result_correct)
                    answer_correct = all(point in answer for point in case["answer_points"])
                    aggregate["answer_correct_count"] += int(answer_correct)
                    task_success = sql_executable and result_correct and answer_correct
                    aggregate["task_success_count"] += int(task_success)
            except SQLValidationError as exc:
                status = "FAILED"
                error_code = exc.code
                error_message = exc.message
                if case["match_mode"] == "rejected":
                    sql_executable = False
                    result_correct = True
                    answer_correct = True
                    task_success = True
                    aggregate["answer_correct_count"] += 1
                    aggregate["task_success_count"] += 1
                    aggregate["safety_rejection_correct_count"] += 1
                    status = "SUCCESS"
                    answer = exc.message
            except ApiError as exc:
                error_code = exc.code
                error_message = exc.message
                if case["match_mode"] == "rejected" and exc.code in {
                    "INVALID_SQL", "SQL_EXECUTION_FAILED", "AGENT_EXECUTION_FAILED"
                }:
                    sql_executable = False
                    result_correct = True
                    answer_correct = True
                    task_success = True
                    aggregate["answer_correct_count"] += 1
                    aggregate["task_success_count"] += 1
                    aggregate["safety_rejection_correct_count"] += 1
                    status = "SUCCESS"
                    answer = exc.message
                else:
                    status = "FAILED"
            except Exception as exc:
                status = "FAILED"
                error_code = type(exc).__name__
                error_message = str(exc)

            if usage and isinstance(usage.get("input_tokens"), int):
                aggregate["input_tokens"] += usage["input_tokens"]
                aggregate["token_cost_unavailable"] = False
            else:
                aggregate["token_cost_unavailable"] = True
            if usage and isinstance(usage.get("output_tokens"), int):
                aggregate["output_tokens"] += usage["output_tokens"]

            rows.append(
                {
                    "run_id": run_id,
                    "case_id": case["id"],
                    "question": case["question"],
                    "generated_sql": generated_sql,
                    "result_status": status,
                    "sql_executable": sql_executable,
                    "sql_result_correct": result_correct,
                    "answer_correct": answer_correct,
                    "task_success": task_success,
                    "sql_latency_ms": sql_latency_ms,
                    "total_latency_ms": int((time.monotonic() - case_started_at) * 1000),
                    "input_tokens": usage.get("input_tokens") if usage else None,
                    "output_tokens": usage.get("output_tokens") if usage else None,
                    "token_cost_unavailable": usage is None,
                    "error_code": error_code,
                    "error_message": error_message,
                }
            )

        total_duration_ms = int((time.monotonic() - started_at) * 1000)
        normal_case_count = sum(
            case["match_mode"] != "rejected" for case in cases
        )
        safety_case_count = len(cases) - normal_case_count
        summary = self._build_summary(
            aggregate,
            len(cases),
            normal_case_count,
            safety_case_count,
        )
        avg_sql_latency = (
            sum(row["sql_latency_ms"] or 0 for row in rows) / len(rows)
            if rows else None
        )
        avg_total_latency = sum(row["total_latency_ms"] for row in rows) / len(rows) if rows else None

        with self.db_manager.engine("op_log").begin() as conn:
            conn.execute(
                text(
                    """
                    INSERT INTO eval.eval_runs (
                        run_id, model_name, finished_at, total_duration_ms, total_cases,
                        sql_executable_count, sql_result_correct_count, answer_correct_count,
                        task_success_count, avg_sql_latency_ms, avg_total_latency_ms,
                        input_tokens, output_tokens, token_cost_unavailable, summary
                    ) VALUES (
                        :run_id, :model_name, now(), :total_duration_ms, :total_cases,
                        :sql_executable_count, :sql_result_correct_count, :answer_correct_count,
                        :task_success_count, :avg_sql_latency_ms, :avg_total_latency_ms,
                        :input_tokens, :output_tokens, :token_cost_unavailable,
                        CAST(:summary AS jsonb)
                    )
                    """
                ),
                {
                    "run_id": str(run_id),
                    "model_name": self.service.settings.qwen_model,
                    "total_duration_ms": total_duration_ms,
                    "total_cases": len(cases),
                    "sql_executable_count": aggregate["sql_executable_count"],
                    "sql_result_correct_count": aggregate["sql_result_correct_count"],
                    "answer_correct_count": aggregate["answer_correct_count"],
                    "task_success_count": aggregate["task_success_count"],
                    "input_tokens": aggregate["input_tokens"],
                    "output_tokens": aggregate["output_tokens"],
                    "token_cost_unavailable": aggregate["token_cost_unavailable"],
                    "avg_sql_latency_ms": avg_sql_latency,
                    "avg_total_latency_ms": avg_total_latency,
                    "summary": json.dumps(summary, ensure_ascii=False),
                },
            )
            for row in rows:
                conn.execute(
                    text(
                        """
                        INSERT INTO eval.eval_case_results (
                            run_id, case_id, question, generated_sql, result_status,
                            sql_executable, sql_result_correct, answer_correct, task_success,
                            sql_latency_ms, total_latency_ms, input_tokens, output_tokens,
                            token_cost_unavailable, error_code, error_message
                        ) VALUES (
                            :run_id, :case_id, :question, :generated_sql, :result_status,
                            :sql_executable, :sql_result_correct, :answer_correct, :task_success,
                            :sql_latency_ms, :total_latency_ms, :input_tokens, :output_tokens,
                            :token_cost_unavailable, :error_code, :error_message
                        )
                        """
                    ),
                    {**row, "run_id": str(run_id)},
                )

        return {
            "run_id": str(run_id),
            "total_cases": len(cases),
            "total_duration_ms": total_duration_ms,
            "summary": summary,
            "token_cost_unavailable": aggregate["token_cost_unavailable"],
        }


