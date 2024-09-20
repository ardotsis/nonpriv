import asyncio
import json
import ssl
from abc import abstractmethod
from logging import getLogger
from typing import Literal

from ..common.async_server import AsyncServer
from ._models import Author, Response
from ._protocol import Operation, Status

_logger = getLogger(__name__)

OP_LEN: int = 2
STATUS_LEN: int = 2
PAYLOAD_SIZE_LEN: int = 4

BYTEORDER: Literal["big", "little"] = "little"


# todo: USE @overload decorator -> https://qiita.com/suzuki_sh/items/0f05d3e6d3c4c6f12c26
class Server(AsyncServer):
    def __init__(
        self, host: str, port: int, ssl_context: ssl.SSLContext | None = None
    ) -> None:
        super().__init__(host, port, self.__new_conn, ssl_context)

    @abstractmethod
    async def on_ping(self, author: Author) -> None:
        raise NotImplementedError

    @abstractmethod
    async def on_disconnect(self, author: Author) -> None:
        raise NotImplementedError

    @abstractmethod
    async def on_authenticate(self, author: Author, key: bytes) -> bool:
        raise NotImplementedError

    @abstractmethod
    async def on_json_request(self, author: Author, data: dict) -> Response:
        raise NotImplementedError

    async def __new_conn(
        self,
        reader: asyncio.StreamReader,
        writer: asyncio.StreamWriter,
        addr: str,
        port: int,
    ) -> None:
        pn = f"{addr}:{port}"
        author = Author(addr, port)
        is_client_authed = False

        while True:
            ignore_payload = False
            try:
                op_int = self.__bytes_to_int(await reader.read(OP_LEN))
                payload_size = self.__bytes_to_int(await reader.read(PAYLOAD_SIZE_LEN))
            except ValueError:
                _logger.error(f"{pn} sends an unknown int bytes - goodbye")
                return

            _logger.debug(f"OP Int: {op_int} Payload Size: {payload_size}")

            try:
                req_op = Operation(op_int)
            except ValueError:
                _logger.error(f"{pn} sends an unknown operation code ({op_int})")
                await self.__send_a_status(writer, Status.INVALID_OPERATION_ERROR)
                continue

            if req_op >= Operation.auth_required_lv() and not is_client_authed:
                _logger.error(f"{pn} requests {req_op.name} without authentication")
                await self.__send_a_status(writer, Status.UNAUTHORIZED_ERROR)
                ignore_payload = True

            if payload_size > 0:
                payload = await reader.read(payload_size)
            else:
                payload = b""

            if ignore_payload:
                _logger.warning(f"Ignore {pn} payload")
                continue

            resp_bytes: bytes | None = None
            if req_op == Operation.PING:
                await self.on_ping(author)
                resp_bytes = self.__get_resp_bytes(Status.OK)
            elif req_op == Operation.DISCONNECT:
                await self.on_disconnect(author)
                return
            elif req_op == Operation.AUTHENTICATE:
                if await self.on_authenticate(author, payload):
                    is_client_authed = True
                    await self.__send_a_status(writer, Status.OK)
                else:
                    await self.__send_a_status(writer, Status.BAD)
            elif req_op == Operation.JSON_REQUEST:
                try:
                    dct = json.loads(payload)
                except json.JSONDecodeError:
                    await self.__send_a_status(writer, Status.INVALID_PAYLOAD_ERROR)
                    continue
                resp = await self.on_json_request(author, dct)
                if not isinstance(resp.data, dict):
                    raise TypeError
                resp.data = json.dumps(resp.data).encode()
                resp_bytes = self.__get_resp_bytes(resp.status, resp.data)

            if resp_bytes is not None:
                await self.__send(writer, resp_bytes)

    def __get_resp_bytes(self, status: Status, payload: bytes = b"") -> bytes:
        status_b = self.__int_to_bytes(status, STATUS_LEN)
        payload_size_b = self.__int_to_bytes(len(payload), PAYLOAD_SIZE_LEN)
        return status_b + payload_size_b + payload

    async def __send_a_status(
        self, writer: asyncio.StreamWriter, status: Status
    ) -> None:
        resp = self.__get_resp_bytes(status)
        await self.__send(writer, resp)

    @staticmethod
    async def __send(writer: asyncio.StreamWriter, data: bytes) -> None:
        writer.write(data)
        await writer.drain()

    @staticmethod
    def __bytes_to_int(bytes_: bytes) -> int:
        return int.from_bytes(bytes_, BYTEORDER)

    @staticmethod
    def __int_to_bytes(int_: int, length: int) -> bytes:
        return int.to_bytes(int_, length, BYTEORDER)
