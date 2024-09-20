import tomllib
from typing import Any

import tomli_w  # type: ignore

type TomlDict = dict[str, Any]


class TomlManager:
    __slots__ = ("_filepath",)

    def __init__(self, filepath: str) -> None:
        self._filepath = filepath

    def load(self) -> TomlDict:
        with open(self._filepath, "rb") as f:
            return tomllib.load(f)

    def write(self, data: TomlDict) -> None:
        with open(self._filepath, "wb") as f:
            tomli_w.dump(data, f)
