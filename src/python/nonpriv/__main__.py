import asyncio
from logging import getLogger

from nonpriv.app import agent_server, http_server
from nonpriv.config import CONFIG

_logger = getLogger("nonpriv")


async def main() -> None:
    _logger.info("Start process")

    host = CONFIG["host"]
    agent_port = CONFIG["agent_port"]
    _logger.debug(f"Load system config - Host: {host}, Agent port: {agent_port}")

    # fmt: off
    await asyncio.gather(
        http_server.HTTPServer(host, 80).run(),
        agent_server.AgentServer(host, agent_port).run()
    )
    # fmt: on


if __name__ == "__main__":
    asyncio.run(main())
