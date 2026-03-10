from fastapi import FastAPI, Request
from fastapi.openapi.docs import get_swagger_ui_html, get_swagger_ui_oauth2_redirect_html
from fastapi.openapi.utils import get_openapi
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from swagger_ui_bundle import swagger_ui_path

from app.model import ClientFeatures, load_model, predict

app = FastAPI(
    title="Credit Scoring Dummy API",
    description="FastAPI-сервис с dummy-моделью кредитного скоринга для MLOps-задач.",
    version="1.0.0",
    docs_url=None,
)

app.mount("/static", StaticFiles(directory=swagger_ui_path), name="static")


@app.on_event("startup")
def startup_event() -> None:
    app.state.model = load_model()


def custom_openapi() -> dict:
    if app.openapi_schema:
        return app.openapi_schema

    app.openapi_schema = get_openapi(
        title=app.title,
        version=app.version,
        description=app.description,
        routes=app.routes,
        openapi_version="3.0.3",
    )
    return app.openapi_schema


app.openapi = custom_openapi


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.get("/docs", include_in_schema=False)
def custom_swagger_ui() -> HTMLResponse:
    return get_swagger_ui_html(
        openapi_url=app.openapi_url,
        title=f"{app.title} - Swagger UI",
        oauth2_redirect_url=app.swagger_ui_oauth2_redirect_url,
        swagger_js_url="/static/swagger-ui-bundle.js",
        swagger_css_url="/static/swagger-ui.css",
    )


@app.get(app.swagger_ui_oauth2_redirect_url, include_in_schema=False)
def swagger_ui_redirect() -> HTMLResponse:
    return get_swagger_ui_oauth2_redirect_html()


@app.post("/predict")
def predict_score(features: ClientFeatures, request: Request) -> dict:
    return predict(request.app.state.model, features)
