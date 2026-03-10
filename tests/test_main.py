from fastapi.testclient import TestClient

from app.main import app


def test_predict_happy_path() -> None:
    with TestClient(app) as client:
        response = client.post(
            "/predict",
            json={
                "age": 35,
                "income": 75000.0,
                "months_on_book": 24,
                "credit_limit": 15000.0,
            },
        )

    assert response.status_code == 200
    data = response.json()
    assert data["prediction"] in {"low_risk", "high_risk"}
    assert 0 <= data["score"] <= 1
    assert data["model_version"] == "1.0-tabular"


def test_predict_bad_input() -> None:
    with TestClient(app) as client:
        response = client.post(
            "/predict",
            json={
                "age": 35,
                "income": 75000.0,
                "credit_limit": 15000.0,
            },
        )

    assert response.status_code == 422


def test_health_check() -> None:
    with TestClient(app) as client:
        response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_docs_available() -> None:
    with TestClient(app) as client:
        response = client.get("/docs")

    assert response.status_code == 200
    assert "Swagger UI" in response.text
