import logging.handlers
import os
import sys

from nonpriv.config import CONFIGS_DIR, LOGS_DIR
from nonpriv.lib.common import logging as yanderat_logging

for dir_ in [CONFIGS_DIR, LOGS_DIR]:
    if not dir_.exists():
        os.mkdir(dir_)

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
stream_handler = logging.StreamHandler(sys.stdout)
stream_handler.setLevel(logging.DEBUG)
file_handler = logging.handlers.TimedRotatingFileHandler(
    LOGS_DIR / "logs.log", encoding="utf-8", when="MIDNIGHT", backupCount=8
)
file_handler.setLevel(logging.DEBUG)
fmt = "[%(asctime)s] [%(levelname)s] %(message)s [%(name)s - %(funcName)s:%(lineno)d]"
stream_handler.setFormatter(yanderat_logging.Formatter(fmt, colored=True, aligned=True))
file_handler.setFormatter(yanderat_logging.Formatter(fmt, aligned=True))
logger.addHandler(stream_handler)
logger.addHandler(file_handler)
