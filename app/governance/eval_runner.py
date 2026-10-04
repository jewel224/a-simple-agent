import argparse

from app.governance.evaluation import EvaluationRunner


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    """解析评测命令行参数，limit 只用于运行评测子集。"""
    parser = argparse.ArgumentParser(description="执行治理版 Text-to-SQL 评测")
    parser.add_argument(
        "limit",
        nargs="?",
        type=int,
        help="运行前 N 条案例；不传则运行完整 50 条评测集",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> dict:
    args = parse_args(argv)
    report = EvaluationRunner().run(limit=args.limit)
    print(report)
    return report


if __name__ == "__main__":
    main()
