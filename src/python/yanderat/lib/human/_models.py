"""VERY EXPERIMENTAL FEATURE"""

from dataclasses import dataclass, asdict
from enum import StrEnum
from uuid import uuid4


# Social -------------------
@dataclass
class X:
    name: str
    user_id: str


@dataclass
class Discord:
    name: str
    user_id: str
    unique_id: str


@dataclass
class Social:
    x: list[X]
    discord: list[Discord]


# Device -------------------
@dataclass
class Yanderat:
    uuid: str
    ip_addresses: list[str]
    auth_key: str
    access_count: int


@dataclass
class Device:
    yanderat: Yanderat


# Personal info -----------
@dataclass
class Name:
    first: str
    last: str


@dataclass
class Birth:
    year: int
    month: int
    day: int


class Gender(StrEnum):
    Man = "Man"
    Woman = "Woman"


@dataclass
class Human:
    id: str
    discord_webhook_token: str

    name: Name | None = None
    age: int | None = None
    gender: Gender | None = None
    birth: Birth | None = None
    height: int | None = None
    phone_number: str | None = None
    #
    devices: list[Device] | None = None
    social: Social | None = None
    #
    description: str | None = None
