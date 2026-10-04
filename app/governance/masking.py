from typing import Any


MASK_RULES = {
    "recipient_name": "name",
    "recipient_phone": "phone",
    "shipping_detail_address": "address",
}


def mask_value(rule: str, value: Any) -> Any:
    if value is None:
        return None
    text = str(value)
    if rule == "name":
        return text[:1] + "*" * max(len(text) - 1, 0)
    if rule == "phone":
        return text[:3] + "****" + text[-4:] if len(text) >= 7 else "****"
    if rule == "address":
        return text[:6] + "****"
    return value


def mask_sensitive_rows(columns: list[str], rows: list[list[Any]]) -> list[list[Any]]:
    """对模型返回结果中直接暴露的敏感列做应用层二次脱敏。"""
    indexes = {
        index: MASK_RULES[column.lower()]
        for index, column in enumerate(columns)
        if column.lower() in MASK_RULES and not column.lower().endswith("_masked")
    }
    if not indexes:
        return rows
    return [
        [mask_value(rule, value) if index in indexes else value for index, value in enumerate(row)]
        for row in rows
    ]
