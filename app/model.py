import random

from pydantic import BaseModel, Field


class ClientFeatures(BaseModel):
    age: int = Field(..., description="Возраст клиента")
    income: float = Field(..., description="Доход клиента")
    months_on_book: int = Field(..., description="Срок обслуживания в месяцах")
    credit_limit: float = Field(..., description="Кредитный лимит")


def load_model() -> dict:
    """Симуляция загрузки модели для табличных данных."""
    print("Загрузка скоринговой модели...")
    return {"version": "1.0-tabular"}


def predict(model: dict, features: ClientFeatures) -> dict:
    """Симуляция предсказания на основе данных клиента."""
    if features.income > 50000 and features.credit_limit > 10000:
        score = random.uniform(0.7, 0.99)
        prediction = "low_risk"
    else:
        score = random.uniform(0.3, 0.69)
        prediction = "high_risk"

    return {
        "model_version": model["version"],
        "prediction": prediction,
        "score": round(score, 4),
    }

