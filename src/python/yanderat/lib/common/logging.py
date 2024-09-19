import logging
from copy import copy

from yanderat.lib.common.color import Color

_LEVELNAME_MAX_LENGTH = 8  # "CRITICAL"
_LEVELNAME_COLORS = {
    logging.DEBUG: Color.WHITE,
    logging.INFO: Color.GREEN,
    logging.WARNING: Color.YELLOW,
    logging.ERROR: Color.RED,
    logging.CRITICAL: Color.BG_RED,
}


class Formatter(logging.Formatter):
    def __init__(
        self, fmt: str = "%(message)s", colored: bool = False, aligned: bool = False
    ) -> None:
        super().__init__()
        self.fmt = fmt
        self.colored = colored
        self.aligned = aligned

    def format(self, record: logging.LogRecord):
        copied_record = copy(record)
        levelname_length = _LEVELNAME_MAX_LENGTH

        if self.colored:
            color = _LEVELNAME_COLORS.get(copied_record.levelno)
            if color is not None:
                levelname_length += len(color + Color.RESET)
                copied_record.levelname = (
                    f"{color}{copied_record.levelname}{Color.RESET}"
                )

        if self.aligned:
            copied_record.levelname = copied_record.levelname.ljust(levelname_length)

        formatter = logging.Formatter(self.fmt)
        return formatter.format(copied_record)
