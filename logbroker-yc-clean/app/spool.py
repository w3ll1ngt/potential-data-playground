from __future__ import annotations

import json
import os
import shutil
import threading
import time
from pathlib import Path
from typing import Iterable, Iterator


class DiskSpool:
    def __init__(self, base_dir: Path) -> None:
        self.base_dir = base_dir
        self.pending_path = self.base_dir / "pending.ndjson"
        self._lock = threading.Lock()

    def initialize(self) -> None:
        self.base_dir.mkdir(parents=True, exist_ok=True)
        if not self.pending_path.exists():
            self.pending_path.touch()
            self._fsync_dir()
        self.recover_processing_files()

    def append(self, items: Iterable[dict]) -> None:
        payload = b"".join(
            (json.dumps(item, ensure_ascii=False, separators=(",", ":")) + "\n").encode("utf-8")
            for item in items
        )
        if not payload:
            return

        with self._lock:
            with self.pending_path.open("ab") as handle:
                handle.write(payload)
                handle.flush()
                os.fsync(handle.fileno())
            self._fsync_dir()

    def take_for_flush(self) -> Path | None:
        with self._lock:
            if not self.pending_path.exists() or self.pending_path.stat().st_size == 0:
                return None

            processing_path = self.base_dir / f"processing-{time.time_ns()}.ndjson"
            os.replace(self.pending_path, processing_path)
            self.pending_path.touch()
            self._fsync_dir()
            return processing_path

    def restore(self, processing_path: Path) -> None:
        if not processing_path.exists():
            return

        with self._lock:
            with self.pending_path.open("ab") as pending_handle:
                with processing_path.open("rb") as processing_handle:
                    shutil.copyfileobj(processing_handle, pending_handle)
                pending_handle.flush()
                os.fsync(pending_handle.fileno())

            processing_path.unlink(missing_ok=True)
            self._fsync_dir()

    def recover_processing_files(self) -> None:
        processing_files = sorted(self.base_dir.glob("processing-*.ndjson"))
        if not processing_files:
            return

        with self._lock:
            with self.pending_path.open("ab") as pending_handle:
                for path in processing_files:
                    with path.open("rb") as processing_handle:
                        shutil.copyfileobj(processing_handle, pending_handle)
                    path.unlink(missing_ok=True)
                pending_handle.flush()
                os.fsync(pending_handle.fileno())
            self._fsync_dir()

    @staticmethod
    def iter_items(path: Path) -> Iterator[dict]:
        with path.open("r", encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                yield json.loads(line)

    def _fsync_dir(self) -> None:
        dir_fd = os.open(self.base_dir, os.O_RDONLY)
        try:
            os.fsync(dir_fd)
        finally:
            os.close(dir_fd)
