from logging import getLogger
from pathlib import Path
from typing import TypedDict, cast

from yanderat.lib.common.toml_manager import TomlDict, TomlManager

_logger = getLogger(__name__)

MODULE_DIR = Path(__file__).parent
SRC_DIR = MODULE_DIR.parent.parent
ROOT_DIR = SRC_DIR.parent
POWERSHELL_DIR = SRC_DIR / "powershell"
CONFIGS_DIR = ROOT_DIR / "configs"
LOGS_DIR = ROOT_DIR / "logs"
CONFIG_PATH = CONFIGS_DIR / "config.toml"


class Config(TypedDict):
    host: str
    agent_port: int
    discord_webhook_url: str
    sqlite_file_url: str
    humans_path: str


# fmt: off
DEFAULT_CONFIG: Config = {
    "host": "127.0.0.1",
    "agent_port": 5555,
    "discord_webhook_url": "",
    "sqlite_file_url": "",
    "humans_path": str(ROOT_DIR / "humans")
}
# fmt: on


def _get_config() -> Config:
    toml = TomlManager(str(CONFIG_PATH))
    if CONFIG_PATH.exists():
        return cast(Config, toml.load())
    else:
        toml.write(cast(TomlDict, DEFAULT_CONFIG))
        return DEFAULT_CONFIG


CONFIG = _get_config()
