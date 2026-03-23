from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Tikog Prediction API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class PredictionRequest(BaseModel):
    dimension_str: str
    length: float
    width: float
    quantities: List[int]
    product_type: str
    sales_trend: str

product_sides = {
    "Basket": 1,
    "Mat": 1,
    "Bag": 2,
    "Slippers": 2,
    "Wallet": 2
}

@app.post("/predict")
def predict(request: PredictionRequest):
    try:
        # Prevent division by zero or errors during calculation
        if request.length <= 0 or request.width <= 0:
            raise ValueError("Length and Width must be greater than 0")

        # Deterministic Base Tikog per side proxy
        base_tikog_per_side = int((request.length * request.width) / 2)
        
        # Apply product sides
        sides = product_sides.get(request.product_type, 1)
        tikog_with_sides = base_tikog_per_side * sides
        
        # Apply quantity
        total_quantity = sum(request.quantities)
        if total_quantity <= 0:
             raise ValueError("Total quantity must be greater than 0")

        final_tikog_needed = tikog_with_sides * total_quantity
        
        return {
            "prediction": final_tikog_needed,
            "breakdown": {
                "base_tikog_per_side": base_tikog_per_side,
                "number_of_sides": sides,
                "tikog_per_product": tikog_with_sides,
                "total_quantity": total_quantity
            },
            "details": {
                "dimension": request.dimension_str,
                "length": request.length,
                "width": request.width,
                "product_type": request.product_type,
                "sales_trend": request.sales_trend
            }
        }
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as e:
        raise HTTPException(status_code=500, detail="Internal server error")
