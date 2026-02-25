"""Entry point: python -m client"""

import argparse
import asyncio
import logging
import os
import time
from pathlib import Path

from .client import run


def main() -> None:
    parser = argparse.ArgumentParser(description="Audio stream client")
    parser.add_argument("-i", "--input", required=True, help="Input audio file")
    parser.add_argument("-s", "--server", default="ws://localhost:8080",
                        help="WebSocket server URI")
    parser.add_argument("-o", "--output", help="Output file path")
    parser.add_argument("--stream-id", help="Stream ID (auto-generated if omitted)")
    args = parser.parse_args()

    if not os.path.exists(args.input):
        parser.error(f"Input file not found: {args.input}")

    if not args.output:
        ts = time.strftime("%Y%m%d-%H%M%S")
        name = Path(args.input).name
        args.output = f"audio/output/output-{ts}-{name}"

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)-5s %(name)s - %(message)s",
    )

    asyncio.run(run(
        server=args.server,
        input_file=args.input,
        output_file=args.output,
        stream_id=args.stream_id,
    ))


if __name__ == "__main__":
    main()
