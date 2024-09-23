import json
import os.path


class JsonManager:
    __slots__ = ("_filepath", "_data")

    def __init__(self, filepath: str, default_dict: dict | None = None) -> None:
        self._filepath = filepath

        if os.path.exists(self._filepath):
            self._data = self._load(self._filepath)
        else:
            if default_dict is None:
                self._data = {}
            else:
                self._data = default_dict
            self.save()

    def get(self) -> dict:
        return self._data

    def save(self) -> None:
        self._write(self._filepath, self._data)

    @staticmethod
    def _load(filepath: str) -> dict:
        with open(filepath, encoding="utf-8") as f:
            return json.load(f)

    @staticmethod
    def _write(filepath: str, dct: dict) -> None:
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(dct, f, indent=2, ensure_ascii=False)
