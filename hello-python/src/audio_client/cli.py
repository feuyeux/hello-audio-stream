"""CLI argument parser"""

import argparse
import os
from datetime import datetime
from pathlib import Path


def parse_args():
    """Parse command-line arguments"""
    parser = argparse.ArgumentParser(
        prog="audio-stream-client",
        description="Audio Stream Cache Client - Python Implementation"
    )
    
    parser.add_argument(
        "-i", "--input",
        required=True,
        help="Input audio file path"
    )
    parser.add_argument(
        "-s", "--server",
        default="ws://localhost:8080/audio",
        help="WebSocket server URI (default: ws://localhost:8080/audio)"
    )
    parser.add_argument(
        "-o", "--output",
        help="Output file path (auto-generated if not specified)"
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable verbose logging"
    )
    
    args = parser.parse_args()
    
    # Validate input file exists
    if not os.path.exists(args.input):
        parser.error(f"Input file not found: {args.input}")
    
    # Generate output path if not provided
    if not args.output:
        timestamp = datetime.now().strftime("%Y-%m-%dT%H-%M-%S")
        basename = Path(args.input).name
        args.output = f"audio/output/output-{timestamp}-{basename}"
    
    return args
