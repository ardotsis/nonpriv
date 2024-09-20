from enum import IntEnum


class Operation(IntEnum):
    PING = 10
    DISCONNECT = 11
    AUTHENTICATE = 12
    JSON_REQUEST = 20

    @classmethod
    def auth_required_lv(cls) -> int:
        return 20


class Status(IntEnum):
    OK = 10
    BAD = 11
    # Exceptions
    UNAUTHORIZED_ERROR = 20
    INVALID_OPERATION_ERROR = 21
    INVALID_PAYLOAD_ERROR = 22
