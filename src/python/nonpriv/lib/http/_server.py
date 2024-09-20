import asyncio
import ssl
from logging import getLogger
from typing import Awaitable, Callable

from ..common.async_server import AsyncServer
from ._decorators import ON_ACCESS_ATTR, PAGE_ATTR
from ._exceptions import InvalidHttpFormatError
from ._models import Request, Response, Status

_logger = getLogger(__name__)

SEP: str = "\r\n"
SEP_B: bytes = SEP.encode()
RECV_CHUNK: int = 1024

type OnAccess = Callable[[Request], Awaitable[Response | bool]]
type Route = Callable[[Request], Awaitable[Response]] | Response


class Server(AsyncServer):
    __slots__ = (
        "__on_access",
        "_routes",
    )

    @property
    def protocol(self) -> str:
        return "https" if self._port == 443 else "http"

    def __init__(
        self, host: str, port: int, ssl_context: ssl.SSLContext | None = None
    ) -> None:
        super().__init__(host, port, self.__new_conn, ssl_context)
        self.__on_access: OnAccess | None = None
        self._routes: dict[str, Route] = {}
        self.__register_decos()

    async def __new_conn(
        self,
        reader: asyncio.StreamReader,
        writer: asyncio.StreamWriter,
        addr: str,
        port: int,
    ) -> None:
        recv = await reader.read(RECV_CHUNK)
        if recv == b"":  # Client may send ping
            _logger.warning(f"{addr}:{port} sends empty byte")
            return

        try:
            method, path, version, headers = self.__parse_recv(recv)
        except InvalidHttpFormatError:
            _logger.error(
                f"{addr}:{port} - Cannot parse received bytes into http format"
            )
            return

        req = Request(addr, port, method, path, version, headers)

        resp = None
        if self.__on_access is not None:
            resp = await self.__on_access(req)
            if resp is False:
                return

        # resp: None, True
        if not isinstance(resp, Response):
            route = self._routes.get(req.path)
            if route is None:
                resp = Response(Status.NOT_FOUND)
            elif isinstance(route, Response):
                resp = route
            else:
                resp = await route(req)

        resp_bytes = self.__create_resp_bytes(resp)
        writer.write(resp_bytes)
        await writer.drain()

        log = f"{addr}:{port} - {resp.status} - {req}"
        if resp.status >= 400:
            _logger.warning(log)
        else:
            _logger.info(log)

    @staticmethod
    def __parse_recv(recv: bytes) -> tuple[str, str, str, dict[str, str]]:
        try:
            # Ignore request body
            start_line_b, headers_b = recv.split(SEP_B, 1)
            # Parse start line bytes
            method, path, version = [b.decode() for b in start_line_b.split(b" ")]
            # Parse headers bytes
            headers = {}
            for header in headers_b.split(SEP_B):
                if not header:
                    continue
                name, value = [b.decode() for b in header.split(b": ")]
                headers[name.lower()] = value
        except (IndexError, ValueError):
            raise InvalidHttpFormatError

        return method, path, version, headers

    @staticmethod
    def __create_resp_bytes(resp: Response) -> bytes:
        start_line = f"{resp.version} {resp.status} {resp.status.phrase}{SEP}"  # type: ignore

        headers = resp.headers.copy()
        headers["Content-Length"] = str(len(resp.body.encode()))

        str_headers = ""
        for name, value in reversed(headers.items()):
            str_headers += f"{name}: {value}{SEP}"
        str_headers += SEP

        return (start_line + str_headers + resp.body).encode()

    def __register_decos(self) -> None:
        for attr_name in dir(self):
            try:
                func = getattr(self, attr_name)
            except AttributeError:
                continue

            if hasattr(func, ON_ACCESS_ATTR):
                if self.__on_access is not None:
                    raise TypeError("'on_access' method is already registered")
                self.__on_access = func
                _logger.debug(f"Set 'on_access' route to '{func.__name__}' function")
            elif hasattr(func, PAGE_ATTR):
                path = getattr(func, PAGE_ATTR)
                if self._routes.get(path) is not None:
                    raise TypeError(f"'{path}' is already registered")
                self._routes[path] = func
                _logger.debug(f"Set '{path}' page to '{func.__name__}' function")
