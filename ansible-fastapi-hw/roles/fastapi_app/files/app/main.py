from fastapi import FastAPI

app = FastAPI(title="FastAPI App", version="1.0.0")


@app.get("/")
def root() -> dict:
    return {"message": "Hello from FastAPI!"}


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}
