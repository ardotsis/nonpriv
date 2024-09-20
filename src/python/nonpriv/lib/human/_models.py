from dataclasses import dataclass, field
from uuid import uuid4


@dataclass
class Device:
    auth_key: str
    ip_addresses: list[str]
    id: str = str(uuid4())


@dataclass
class Name:
    first: str | None = None
    last: str | None = None


@dataclass
class Birth:
    year: int | None = None
    month: int | None = None
    day: int | None = None


class Gender:
    Male = "male"
    Female = "female"


@dataclass
class Human:
    id: str = str(uuid4())
    discord_webhook_token: str | None = None
    name: Name = field(default_factory=Name)
    gender: Gender | None = None
    age: int | None = None
    birth: Birth = field(default_factory=Birth)
    height: int | None = None
    phone_number: str | None = None
    devices: list[Device] = field(default_factory=list)
    description: str = ""
