"""Registry of active audio streams."""
import os
import threading
import time
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Dict, Optional, Tuple

from .mmap_cache import MmapCache

MAX_STREAMS = 1000
MAX_IDLE_SECS = 24 * 3600
MAX_UPLOADING_SECS = 3600


class StreamStatus(Enum):
    UPLOADING = "UPLOADING"
    READY = "READY"
    ERROR = "ERROR"


@dataclass
class Stream:
    id: str
    cache: MmapCache
    offset: int = 0
    created: float = field(default_factory=time.time)
    last_access: float = field(default_factory=time.time)
    status: StreamStatus = StreamStatus.UPLOADING
    lock: threading.Lock = field(default_factory=threading.Lock)


@dataclass
class Stats:
    total: int = 0
    uploading: int = 0
    ready: int = 0
    error: int = 0


class StreamManager:
    """Manages multiple concurrent audio streams."""

    def __init__(
        self,
        cache_dir: str,
        max_streams: int = MAX_STREAMS,
        max_idle_secs: float = MAX_IDLE_SECS,
        max_uploading_secs: float = MAX_UPLOADING_SECS,
    ):
        self._cache_dir = cache_dir
        self._max_streams = max_streams
        self._max_idle_secs = max_idle_secs
        self._max_uploading_secs = max_uploading_secs
        self._streams: Dict[str, Stream] = {}
        self._lock = threading.Lock()
        os.makedirs(cache_dir, exist_ok=True)

    def create(self, stream_id: str) -> None:
        with self._lock:
            if len(self._streams) >= self._max_streams:
                raise RuntimeError(f"Max streams ({self._max_streams}) reached")
            if stream_id in self._streams:
                raise RuntimeError(f"Stream already exists: {stream_id}")
            cache_path = os.path.join(self._cache_dir, f"{stream_id}.cache")
            cache = MmapCache(cache_path)
            cache.create()
            self._streams[stream_id] = Stream(id=stream_id, cache=cache)

    def write(self, stream_id: str, data: bytes) -> None:
        s = self._get(stream_id)
        with s.lock:
            if s.status != StreamStatus.UPLOADING:
                raise RuntimeError(f"Stream {stream_id} is not uploading")
            s.cache.write(s.offset, data)
            s.offset += len(data)
            s.last_access = time.time()

    def complete(self, stream_id: str) -> None:
        s = self._get(stream_id)
        with s.lock:
            if s.status != StreamStatus.UPLOADING:
                raise RuntimeError(f"Stream {stream_id} is not uploading")
            s.cache.finalize(s.offset)
            s.status = StreamStatus.READY
            s.last_access = time.time()

    def read(self, stream_id: str, offset: int, length: int) -> bytes:
        s = self._get(stream_id)
        with s.lock:
            if s.status != StreamStatus.READY:
                raise RuntimeError(f"Stream {stream_id} is not ready")
            s.last_access = time.time()
            return s.cache.read(offset, length)

    def delete(self, stream_id: str) -> None:
        with self._lock:
            s = self._streams.pop(stream_id, None)
            if s is None:
                raise RuntimeError(f"Stream not found: {stream_id}")
        s.cache.close()
        path = os.path.join(self._cache_dir, f"{stream_id}.cache")
        if os.path.exists(path):
            os.remove(path)

    def mark_error(self, stream_id: str) -> None:
        s = self._streams.get(stream_id)
        if s and s.status == StreamStatus.UPLOADING:
            s.status = StreamStatus.ERROR

    def status_of(self, stream_id: str) -> Tuple[StreamStatus, int]:
        s = self._get(stream_id)
        return s.status, s.offset

    def list(self) -> str:
        with self._lock:
            return ",".join(self._streams.keys())

    def cleanup(self) -> None:
        now = time.time()
        to_remove = []
        with self._lock:
            for sid, s in self._streams.items():
                idle = now - s.last_access
                age = now - s.created
                if s.status in (StreamStatus.READY, StreamStatus.ERROR) and idle > self._max_idle_secs:
                    to_remove.append(sid)
                elif s.status == StreamStatus.UPLOADING and age > self._max_uploading_secs:
                    to_remove.append(sid)
            for sid in to_remove:
                s = self._streams.pop(sid)
                s.cache.close()
                path = os.path.join(self._cache_dir, f"{sid}.cache")
                if os.path.exists(path):
                    os.remove(path)
                print(f"Cleaned up stream: {sid}", flush=True)

    def stats(self) -> Stats:
        st = Stats()
        with self._lock:
            st.total = len(self._streams)
            for s in self._streams.values():
                if s.status == StreamStatus.UPLOADING:
                    st.uploading += 1
                elif s.status == StreamStatus.READY:
                    st.ready += 1
                else:
                    st.error += 1
        return st

    def _get(self, stream_id: str) -> Stream:
        s = self._streams.get(stream_id)
        if s is None:
            raise RuntimeError(f"Stream not found: {stream_id}")
        return s
