from dataclasses import dataclass, field
from enum import IntEnum


class Status(IntEnum):
    def __new__(cls, value: int, phrase: str):
        obj = int.__new__(cls, value)
        obj._value_ = value
        obj.phrase = phrase  # type: ignore
        return obj

    OK = (200, "OK")
    MOVED_PERMANENTLY = (301, "Moved Permanently")
    BAD_REQUEST = (400, "Bad Request")
    NOT_FOUND = (404, "Not Found")


@dataclass(frozen=True, slots=True)
class Request:
    address: str
    port: int
    method: str
    path: str
    version: str
    headers: dict[str, str]


@dataclass(slots=True)
class Response:
    status: Status
    version: str = "HTTP/1.1"
    headers: dict[str, str] = field(default_factory=dict)
    body: str = ""
