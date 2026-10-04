class ApiError(Exception):
    """带 HTTP 状态码和业务错误码的应用异常。"""

    def __init__(self, status_code: int, code: str, message: str):
        self.status_code = status_code
        self.code = code
        self.message = message
        super().__init__(message)


class SQLValidationError(ApiError):
    def __init__(self, message: str):
        super().__init__(400, "INVALID_SQL", message)


class SQLTimeoutError(ApiError):
    def __init__(self, message: str):
        super().__init__(504, "SQL_TIMEOUT", message)


class SQLExecutionError(ApiError):
    def __init__(self, message: str):
        super().__init__(400, "SQL_EXECUTION_FAILED", message)


class SemanticMetadataError(ApiError):
    def __init__(self, message: str):
        super().__init__(503, "SEMANTIC_METADATA_UNAVAILABLE", message)


class AgentExecutionError(ApiError):
    def __init__(self, message: str):
        super().__init__(502, "AGENT_EXECUTION_FAILED", message)
