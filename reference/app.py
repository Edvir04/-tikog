import streamlit as st
import pandas as pd
import numpy as np

# ======================================================
# APP TITLE & DESCRIPTION
# ======================================================
st.title("Tikog Requirement Prediction Application")
st.write("Enter the following details to predict the required Tikog for your product:")

# ======================================================
# NUMBER OF SIDES PER PRODUCT
# ======================================================
product_sides = {
    "Basket": 1,
    "Mat": 1,
    "Bag": 2,
    "Slippers": 2,
    "Wallet": 2,
    "Others": 1
}

# ======================================================
# DIMENSION OPTIONS
# ======================================================
dimension_options = {
    "27 inches x 16 inches": (27, 16),
    "11 inches x 14 ½ inches": (11, 14.5),
    "12 inches x 7 ½ inches x 3 ½ inches": (12, 7.5),
    "Body = 17 ½ x 2, packet (11 ½ x 11 ½), side (5 x 6)": (17.5, 2),
    "29 inches x 22 inches": (29, 22)
}

# ======================================================
# DIMENSION INPUT
# ======================================================
dimension = st.selectbox(
    "Dimension",
    options=list(dimension_options.keys()) + ["Custom"]
)

if dimension != "Custom":
    length, width = dimension_options[dimension]
    st.write(f"Length: {length} inches")
    st.write(f"Width: {width} inches")
else:
    length = st.number_input("Length (in inches)", min_value=0.0, step=0.1)
    width = st.number_input("Width (in inches)", min_value=0.0, step=0.1)

# ======================================================
# OTHER INPUTS
# ======================================================
quantity = st.text_input(
    "Quantity (Enter multiple quantities separated by commas)",
    "10"
)

product_type = st.selectbox(
    "Product Type",
    ["Basket", "Mat", "Bag", "Slippers", "Wallet", "Others"]
)

sales_trend = st.selectbox(
    "Sales Trend",
    ["Increasing", "Stable", "Decreasing"]
)

# ======================================================
# PREDICTION LOGIC
# ======================================================
if st.button("Predict"):
    try:
        # Parse quantity
        quantities = [int(q.strip()) for q in quantity.split(",")]
        total_quantity = sum(quantities)

        # --------------------------------------------------
        # PLACEHOLDER MODEL PREDICTION (PER SIDE)
        # Replace this later with your trained model
        # --------------------------------------------------
        base_tikog_per_side = np.random.randint(100, 500)

        # --------------------------------------------------
        # APPLY PRODUCT SIDES
        # --------------------------------------------------
        sides = product_sides.get(product_type, 1)
        tikog_with_sides = base_tikog_per_side * sides

        # --------------------------------------------------
        # APPLY QUANTITY
        # --------------------------------------------------
        final_tikog_needed = tikog_with_sides * total_quantity

        # ==================================================
        # OUTPUT
        # ==================================================
        st.success(
            f"Prediction: {final_tikog_needed} units of Tikog required"
        )

        st.write("### Breakdown")
        st.write(f"Base Tikog per side: {base_tikog_per_side}")
        st.write(f"Number of sides: {sides}")
        st.write(f"Tikog per product: {tikog_with_sides}")
        st.write(f"Total quantity: {total_quantity}")

        st.write("### Details")
        st.write(f"Dimension: {dimension}")
        st.write(f"Length: {length} inches")
        st.write(f"Width: {width} inches")
        st.write(f"Product Type: {product_type}")
        st.write(f"Sales Trend: {sales_trend}")

    except ValueError:
        st.error(
            "Please enter valid integers separated by commas in the Quantity field."
        )
