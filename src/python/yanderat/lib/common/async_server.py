import asyncio
import ssl
from logging import getLogger
from typing import Awaitable, Callable

_logger = getLogger(__name__)

type ClientConnectedCB = Callable[
    [asyncio.StreamReader, asyncio.StreamWriter, str, int], Awaitable[None]
]


class AsyncServer:
    __slots__ = (
        "_host",
        "_port",
        "_client_connected_cb",
        "_ssl_ctx",
    )

    def __init__(
        self,
        host: str,
        port: int,
        client_connected_cb: ClientConnectedCB,
        ssl_ctx: ssl.SSLContext | None = None,
    ) -> None:
        self._host = host
        self._port = port
        self._client_connected_cb = client_connected_cb
        self._ssl_ctx = ssl_ctx

    async def run(self) -> None:
        server = await asyncio.start_server(
            self._client_connected_cb_manager,
            self._host,
            self._port,
            ssl=self._ssl_ctx,
        )
        # https://stackoverflow.com/q/56424648
        async with server:
            await server.serve_forever()

    async def _client_connected_cb_manager(
        self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter
    ) -> None:
        pn = writer.get_extra_info("peername")
        try:
            await self._client_connected_cb(reader, writer, pn[0], pn[1])
        except ConnectionError as err:
            writer.close()
            _logger.error(f"{pn[0]}:{pn[1]} - {err}")
        else:
            writer.close()
            await writer.wait_closed()
