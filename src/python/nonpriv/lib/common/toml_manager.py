import os
import tomllib

import tomli_w  # type: ignore

type TomlDict = dict[str, any]


class TomlManager:
    __slots__ = ("_filepath", "_data")

    def __init__(
        self,
        filepath: str,
        default_toml_dict: TomlDict | None = None,
    ) -> None:
        self._filepath = filepath
        if os.path.exists(self._filepath):
            self._data = self._load(self._filepath)
        else:
            if default_toml_dict is None:
                self._data = {}
            else:
                self._data = default_toml_dict
            self.save()

    def get(self) -> TomlDict:
        return self._data

    def save(self) -> None:
        self._write(self._filepath, self._data)

    @staticmethod
    def _load(filepath: str) -> TomlDict:
        with open(filepath, "rb") as f:
            return tomllib.load(f)

    @staticmethod
    def _write(filepath: str, dct: TomlDict) -> None:
        with open(filepath, "wb") as f:
            tomli_w.dump(dct, f)
