import json
import os.path
from typing import Any


class JsonManager:
    __slots__ = ("_filepath", "_data")

    def __init__(self, filepath: str, data: dict) -> None:
        self._filepath = filepath
        self._data = data

        if os.path.exists(self._filepath):
            self._data = self._load(self._filepath)
        else:
            self._data = {}

    def save(self) -> None:
        self._write(self._filepath, self._data)

    @staticmethod
    def _load(filepath: str) -> dict:
        with open(filepath, "r", encoding="utf-8") as f:
            return json.load(f)

    @staticmethod
    def _write(filepath: str, data: dict[str, Any]) -> None:
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
