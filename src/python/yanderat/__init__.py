import logging.handlers
import os
import sys

from yanderat.lib.common import logging as yanderat_logging
from yanderat.path import CONFIGS_DIR, LOGS_DIR

for d in [CONFIGS_DIR, LOGS_DIR]:
    if not d.exists():
        os.mkdir(d)

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
