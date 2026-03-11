from __future__ import annotations

import csv
import io
import json
from typing import Any, Iterable

import requests


class ClickHouseError(RuntimeError):
    pass


class ClickHouseHttpClient:
    def __init__(
        self,
        scheme: str,
        host: str,
        port: int,
        user: str,
        password: str,
        timeout_seconds: float,
    ) -> None:
        self.base_url = f"{scheme}://{host}:{port}/"
        self.auth = (user, password)
        self.timeout_seconds = timeout_seconds
        self.session = requests.Session()

    def show_create_table(self, table_name: str) -> str:
        return self._request("GET", f"SHOW CREATE TABLE {table_name}")

    def insert_json_rows(self, table_name: str, rows: Iterable[dict[str, Any]]) -> str:
        payload = "\n".join(
            json.dumps(row, ensure_ascii=False, separators=(",", ":")) for row in rows
        )
        if payload:
            payload += "\n"
        return self._request("POST", f"INSERT INTO {table_name} FORMAT JSONEachRow", payload)

    def insert_list_rows(self, table_name: str, rows: Iterable[list[Any]]) -> str:
        buffer = io.StringIO()
        writer = csv.writer(buffer, lineterminator="\n")
        for row in rows:
            writer.writerow(row)
        return self._request("POST", f"INSERT INTO {table_name} FORMAT CSV", buffer.getvalue())

    def _request(self, method: str, query: str, payload: str | None = None) -> str:
        response = self.session.request(
            method=method,
            url=self.base_url,
            params={"query": query},
            data=payload.encode("utf-8") if payload is not None else None,
            auth=self.auth,
            headers={"Content-Type": "text/plain; charset=utf-8"},
            timeout=(self.timeout_seconds, self.timeout_seconds),
        )
        if not response.ok:
            raise ClickHouseError(f"ClickHouse returned {response.status_code}: {response.text.strip()}")
        return response.text
