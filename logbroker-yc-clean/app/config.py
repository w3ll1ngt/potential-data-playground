from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    clickhouse_scheme: str
    clickhouse_host: str
    clickhouse_port: int
    clickhouse_user: str
    clickhouse_password: str
    data_dir: Path
    flush_interval_seconds: float
    request_timeout_seconds: float
    instance_name: str



def get_settings() -> Settings:
    return Settings(
        clickhouse_scheme=os.getenv("LOGBROKER_CH_SCHEME", "http"),
        clickhouse_host=os.getenv("LOGBROKER_CH_HOST", "127.0.0.1"),
        clickhouse_port=int(os.getenv("LOGBROKER_CH_PORT", "8123")),
        clickhouse_user=os.getenv("LOGBROKER_CH_USER", "logbroker"),
        clickhouse_password=os.getenv("LOGBROKER_CH_PASSWORD", ""),
        data_dir=Path(os.getenv("LOGBROKER_DATA_DIR", "/var/lib/logbroker")),
        flush_interval_seconds=float(os.getenv("LOGBROKER_FLUSH_INTERVAL_SECONDS", "1.0")),
        request_timeout_seconds=float(os.getenv("LOGBROKER_REQUEST_TIMEOUT_SECONDS", "10.0")),
        instance_name=os.getenv("LOGBROKER_INSTANCE_NAME", "logbroker"),
    )
