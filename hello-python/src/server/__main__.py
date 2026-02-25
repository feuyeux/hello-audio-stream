"""Entry point: python -m server"""

import argparse
import asyncio
import logging

from . import run


def main() -> None:
    parser = argparse.ArgumentParser(description="Audio stream server")
    parser.add_argument("--host", default="0.0.0.0", help="Bind host")
    parser.add_argument("--port", type=int, default=8080, help="Bind port")
    parser.add_argument("--cache-dir", default="audio/output", help="Cache directory")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)-5s %(name)s - %(message)s",
    )

    asyncio.run(run(host=args.host, port=args.port, cache_dir=args.cache_dir))


if __name__ == "__main__":
    main()
