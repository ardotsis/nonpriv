from dataclasses import dataclass

from ._protocol import Status


@dataclass(slots=True)
class Author:
    address: str
    port: int


@dataclass(slots=True)
class Response:
    status: Status
    data: bytes | dict = b""


@dataclass
class Client:
    address: str
    unique_id: str
    auth_key: str
    access_count: str
