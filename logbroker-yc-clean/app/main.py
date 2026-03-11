from __future__ import annotations

import logging
import threading
from contextlib import asynccontextmanager
from typing import Annotated

from fastapi import FastAPI, HTTPException, Query, Response
from fastapi.responses import JSONResponse, PlainTextResponse

from clickhouse_http import ClickHouseError, ClickHouseHttpClient
from config import get_settings
from models import TABLE_NAME_RE, WriteLogItem
from spool import DiskSpool

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
)
logger = logging.getLogger("logbroker")
settings = get_settings()
spool = DiskSpool(settings.data_dir)
clickhouse = ClickHouseHttpClient(
    scheme=settings.clickhouse_scheme,
    host=settings.clickhouse_host,
    port=settings.clickhouse_port,
    user=settings.clickhouse_user,
    password=settings.clickhouse_password,
    timeout_seconds=settings.request_timeout_seconds,
)
flush_lock = threading.Lock()
stop_event = threading.Event()
worker_thread: threading.Thread | None = None



def validate_table_name(table_name: str) -> str:
    if not TABLE_NAME_RE.fullmatch(table_name):
        raise HTTPException(status_code=422, detail="invalid table_name")
    return table_name



def flush_once() -> bool:
    processing_path = None
    with flush_lock:
        processing_path = spool.take_for_flush()
        if processing_path is None:
            return False

        grouped: dict[tuple[str, str], list] = {}
        try:
            for item in spool.iter_items(processing_path):
                key = (item["table_name"], item["format"])
                grouped.setdefault(key, []).extend(item["rows"])

            for (table_name, item_format), rows in grouped.items():
                if item_format == "json":
                    clickhouse.insert_json_rows(table_name, rows)
                else:
                    clickhouse.insert_list_rows(table_name, rows)

            processing_path.unlink(missing_ok=True)
            logger.info(
                "flushed %s buffered insert group(s) from %s",
                len(grouped),
                processing_path.name,
            )
            return True
        except Exception as exc:  # noqa: BLE001
            logger.exception("flush failed for %s: %s", processing_path, exc)
            spool.restore(processing_path)
            return False



def flush_worker() -> None:
    while not stop_event.wait(settings.flush_interval_seconds):
        flush_once()


@asynccontextmanager
async def lifespan(_: FastAPI):
    global worker_thread

    spool.initialize()
    flush_once()

    stop_event.clear()
    worker_thread = threading.Thread(target=flush_worker, name="flush-worker", daemon=True)
    worker_thread.start()
    logger.info("logbroker %s started", settings.instance_name)

    try:
        yield
    finally:
        stop_event.set()
        if worker_thread is not None:
            worker_thread.join(timeout=settings.flush_interval_seconds + 2)
        flush_once()
        logger.info("logbroker %s stopped", settings.instance_name)


app = FastAPI(lifespan=lifespan)


@app.get("/healthcheck")
def healthcheck() -> Response:
    return Response(status_code=200)


@app.get("/show_create_table")
def show_create_table(
    table_name: Annotated[str, Query(..., min_length=1)],
) -> PlainTextResponse:
    validate_table_name(table_name)
    try:
        ddl = clickhouse.show_create_table(table_name)
        return PlainTextResponse(ddl)
    except ClickHouseError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@app.post("/write_log")
def write_log(items: list[WriteLogItem]) -> JSONResponse:
    accepted_items = [item.model_dump(mode="json") for item in items]
    try:
        spool.append(accepted_items)
    except OSError as exc:
        logger.exception("failed to persist accepted log batch")
        raise HTTPException(status_code=500, detail=f"failed to persist accepted log batch: {exc}") from exc

    logger.info("accepted %s logical log batch(es)", len(accepted_items))
    return JSONResponse(["" for _ in accepted_items])
