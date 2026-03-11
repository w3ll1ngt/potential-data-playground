from __future__ import annotations

import re
from typing import Any, Literal

from pydantic import BaseModel, Field, model_validator

TABLE_NAME_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)?$")


class WriteLogItem(BaseModel):
    table_name: str = Field(min_length=1)
    rows: list[Any]
    format: Literal["json", "list"]

    @model_validator(mode="after")
    def validate_item(self) -> "WriteLogItem":
        if not TABLE_NAME_RE.fullmatch(self.table_name):
            raise ValueError("table_name must be <table> or <database>.<table> and contain only letters, digits, or underscores")

        if self.format == "json":
            if any(not isinstance(row, dict) for row in self.rows):
                raise ValueError("for format=json, each row must be an object")
        elif self.format == "list":
            if any(not isinstance(row, list) for row in self.rows):
                raise ValueError("for format=list, each row must be an array")

        return self
