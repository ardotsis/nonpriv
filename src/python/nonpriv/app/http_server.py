import os
import ssl
from logging import getLogger

from nonpriv.config import POWERSHELL_DIR
from nonpriv.lib import http
from nonpriv.lib.http import Request, Response, Status

_logger = getLogger(__name__)

ROOT_FILE = "entry"

# fmt: off
VARIABLE_MAP: dict[str, str] = {
    "REMOTE_HOST": "",
    "PORT": ""
}
# fmt: on


class HTTPServer(http.Server):
    def __init__(
        self,
        host: str,
        port: int,
        ssl_ctx: ssl.SSLContext | None = None,
    ) -> None:
        super().__init__(host, port, ssl_ctx)

    @http.on_access
    async def _on_access(self, req: Request) -> Response | bool:
        return True

    @http.route("/")
    async def _root_page(self, req: Request) -> Response:
        return Response(Status.NOT_FOUND, body="")

    @http.route("/main")
    async def _main_script_page(self, req: Request) -> Response:
        return Response(Status.OK, body="<h1>hi!<h1/>")

    def _add_script_pages(self) -> None:
        for item in os.listdir(POWERSHELL_DIR):
            fullpath = POWERSHELL_DIR / item

            if fullpath.is_file():
                with open(fullpath, "r", encoding="utf-8") as f:
                    script = f.read()

                resp = Response(Status.OK, body=script)
                _base_log = f"Set '{fullpath.name}' to {self.protocol}://{self._host}"
                filename = fullpath.name[:-4]
                if filename == ROOT_FILE:
                    self._routes["/"] = resp
                    _logger.debug(_base_log)
                else:
                    self._routes[f"/{filename}"] = resp
                    _logger.debug(f"{_base_log}/{filename}")
