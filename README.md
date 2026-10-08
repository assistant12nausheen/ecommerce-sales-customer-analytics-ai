# E-Commerce Sales & Customer Analytics with AI

> An end-to-end data analytics project, from raw CSV files to an interactive full-stack web dashboard, built on the Brazilian E-Commerce dataset published by Olist.

**Author:** NAUSHEEN SUHANA
**Program:** AICTE – IBM SkillsBuild Data Analytics with AI Internship 2026 (BharatCares)
**Dataset:** [Brazilian E-Commerce Public Dataset by Olist (Kaggle)](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

---

## Table of Contents

1. [Project Description](#project-description)
2. [Problem Statement](#problem-statement)
3. [Dataset](#dataset)
4. [Project Phases](#project-phases)
5. [Key Insights & KPIs](#key-insights--kpis)
6. [Technologies Used](#technologies-used)
7. [Project Structure](#project-structure)
8. [Setup & Installation](#setup--installation)
9. [Running the Application](#running-the-application)
10. [API Reference](#api-reference)
11. [Dashboard Pages](#dashboard-pages)
12. [Screenshots](#screenshots)
13. [Acknowledgements](#acknowledgements)

---

## Project Description

This project turns nine raw Olist CSV files into a complete analytics system. It covers data cleaning, exploratory analysis, a MySQL database, machine-learning models (customer segmentation, sales forecasting, anomaly detection), a rule-based AI insights report, a FastAPI backend and a React dashboard with interactive Plotly charts.

## Problem Statement

Olist is a Brazilian marketplace that connects small retailers to major commerce channels. Its transaction data sits across nine separate CSV files with no unified view, no derived metrics, and no way for a non-technical stakeholder to explore it.

Managers and analysts cannot easily answer questions such as:

- Which product categories generate the most revenue?
- What percentage of orders are delivered late?
- Which customers are the most valuable?
- Is monthly revenue growing or plateauing?
- Which orders look statistically unusual and need review?

This project makes each of those questions answerable in seconds.

## Dataset

**Source:** [Kaggle – Olist Brazilian E-Commerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

It covers about 100,000 orders placed between September 2016 and August 2018 across Brazil.

| File | Description |
|------|-------------|
| `olist_orders_dataset.csv` | Order status, timestamps, customer reference |
| `olist_order_items_dataset.csv` | Items, sellers, price and freight per order |
| `olist_order_payments_dataset.csv` | Payment type, instalments, value |
| `olist_order_reviews_dataset.csv` | Review score (1–5) and comments |
| `olist_customers_dataset.csv` | Customer location |
| `olist_sellers_dataset.csv` | Seller location |
| `olist_products_dataset.csv` | Category, dimensions, weight |
| `olist_geolocation_dataset.csv` | ZIP code to latitude/longitude |
| `product_category_name_translation.csv` | Portuguese to English category names |

> The CSV files are **not stored in this repository** because of their size. Download them from Kaggle and place them in `data/raw/`.

## Project Phases

| # | Phase | Key Output |
|---|-------|-----------|
| 1 | Dataset Understanding | Data dictionary |
| 2 | Data Cleaning | Cleaned CSV files |
| 3 | Data Preprocessing | RFM features, monthly sales, order totals |
| 4 | Exploratory Data Analysis | 23 charts |
| 5 | SQL Database Creation | 7-table MySQL schema with foreign keys |
| 6 | SQL Business Analysis | 3 query files, 15+ business questions |
| 7 | Power BI Module | Guide and DAX measures (offline) |
| 8 | Customer Segmentation | K-Means (K=4) on RFM features |
| 9 | Sales Forecasting | Polynomial regression and exponential smoothing |
| 10 | Anomaly Detection | IQR and Isolation Forest |
| 11 | AI Business Insights | Rule-based natural-language report |
| 12 | FastAPI Backend | 12 REST endpoints |
| 13 | React Frontend | 9-page interactive dashboard |

## Key Insights & KPIs

Delivered orders, September 2016 to August 2018.

| KPI | Value |
|-----|-------|
| Total delivered orders | 96,478 |
| Unique customers | 93,358 |
| Total revenue | R$ 15.42 M |
| Average order value | R$ 159.86 |
| Median order value | R$ 105.28 |
| Average review score | 4.09 / 5.0 |
| 5-star review rate | 57.8% |
| Late delivery rate | 8.0% |
| Average delivery time | 12.6 days |
| Credit card payment share | 73.9% |

**Sales trends**
- Revenue peaked in November 2017 at R$ 1.15 M.
- Strong growth through 2017, then a plateau in early 2018.
- The 3-month polynomial forecast is R$ 1.36 M, R$ 1.40 M and R$ 1.43 M. Treat it as directional (test MAPE 18.2%).

**Top categories by revenue:** health_beauty (R$ 1.26 M), watches_gifts (R$ 1.21 M), bed_bath_table (R$ 1.04 M), sports_leisure (R$ 988 K), computers_accessories (R$ 912 K).

**Customer segments (K-Means RFM, K=4)**

| Segment | Customers | Share | Avg Spend |
|---------|----------:|------:|----------:|
| Recent Light Buyers | 35,751 | 38.3% | R$ 69.52 |
| High-Value Champions | 27,589 | 29.6% | R$ 320.52 |
| Inactive Low-Spend | 27,217 | 29.2% | R$ 118.67 |
| Loyal Regulars | 2,801 | 3.0% | R$ 308.59 |

**Notable findings**
- 97% of customers placed only one order, so most revenue comes from first-time buyers.
- Shipping averages 16.6% of item price.
- Orders typically arrive about 11 days before the estimated date.
- 26,408 orders were flagged as statistically unusual. They are not labelled fraudulent and need domain review.

## Technologies Used

| Layer | Technology |
|-------|-----------|
| Language | Python 3 |
| Data processing | Pandas, NumPy |
| Visualisation | Matplotlib, Seaborn, Plotly.js |
| Machine learning | Scikit-learn, Statsmodels |
| Database | MySQL 8 |
| ORM | SQLAlchemy 2 |
| Backend | FastAPI, Pydantic, Uvicorn |
| Frontend | React 18, Vite, Axios |
| Configuration | python-dotenv |
| BI (offline) | Power BI Desktop |

## Project Structure

```
├── backend/        FastAPI app (main.py, database.py, routers, services, schemas)
├── frontend/       React + Vite dashboard (src/pages, src/components, src/api)
├── python/         Pipeline scripts (cleaning, EDA, segmentation, forecasting, anomalies, db_seed)
├── sql/            schema.sql and analysis queries
├── powerbi/        Power BI guide and DAX measures
├── reports/        Data dictionary, AI insights report, figures
├── docs/           Screenshots used in this README
├── AGENTS.md
└── README.md
```

## Setup & Installation

**Prerequisites:** Python 3.9+, Node.js 18+, MySQL 8.0+

**1. Clone the repository**
```bash
git clone https://github.com/assistant12nausheen/ecommerce-sales-customer-analytics-ai.git
cd ecommerce-sales-customer-analytics-ai
```

**2. Create a virtual environment**
```bash
python -m venv venv
venv\Scripts\activate          # Windows
# source venv/bin/activate     # macOS / Linux
```

**3. Install Python dependencies**
```bash
pip install -r backend/requirements.txt
pip install pandas numpy matplotlib seaborn scikit-learn statsmodels python-dotenv
```

**4. Configure the database**
```bash
copy backend\.env.example backend\.env      # Windows
# cp backend/.env.example backend/.env      # macOS / Linux
```
Edit `backend/.env`:
```
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_mysql_password
DB_NAME=olist_ecommerce
CLEANED_DATA_DIR=../data/cleaned
REPORTS_DIR=../reports
```

**5. Download the dataset** from Kaggle and place the CSV files in `data/raw/`.

**6. Run the data pipeline** (from the project root)
```bash
python python/data_cleaning.py
python python/preprocessing.py
python python/eda.py
python python/customer_segmentation.py
python python/forecasting.py
python python/anomaly_detection.py
python python/ai_insights.py
```

**7. Create the database schema**
```bash
mysql -u root -p < sql/schema.sql
```

**8. Load the data into MySQL**
```bash
python python/db_seed.py
```

**9. Install frontend dependencies**
```bash
cd frontend
npm install
```

## Running the Application

**Start the backend** (from the project root):
```bash
uvicorn backend.main:app --reload --port 8000
```

| URL | Description |
|-----|-------------|
| http://localhost:8000/docs | Interactive Swagger UI |
| http://localhost:8000/api/health | Health check |

**Start the frontend** (in a second terminal):
```bash
cd frontend
npm run dev
```
Open **http://localhost:5173** in your browser.

> Six of the twelve endpoints read from the cleaned CSV files, so they work even without MySQL.

## API Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/health` | Service and database status |
| GET | `/api/dashboard/kpis` | Headline KPI metrics |
| GET | `/api/sales/monthly` | Monthly revenue and order counts |
| GET | `/api/products/categories` | Top categories by revenue |
| GET | `/api/customers/stats` | Repeat rate, spend, state breakdown |
| GET | `/api/payments/analysis` | Payment type share, instalments |
| GET | `/api/reviews/analysis` | Review score distribution |
| GET | `/api/delivery/analysis` | Delivery time and late rate |
| GET | `/api/segmentation` | RFM K-Means segments |
| GET | `/api/forecast` | Actuals, model fit and 3-month forecast |
| GET | `/api/anomalies` | Statistically unusual orders |
| GET | `/api/insights` | AI business insights report |

## Dashboard Pages

| Page | Route | Shows |
|------|-------|-------|
| Dashboard | `/` | KPI cards, revenue and order charts |
| Sales Analytics | `/sales` | Revenue trend, order volume, average order value |
| Customers | `/customers` | Repeat rate, spend, top states |
| Products | `/products` | Category revenue, orders, review scores |
| Delivery & Reviews | `/delivery` | Delivery trend, late rate, review distribution |
| Segmentation | `/segmentation` | Customer segment charts and table |
| Forecast | `/forecast` | Actual vs predicted, 3-month projection |
| Anomalies | `/anomalies` | Flagged orders and score histogram |
| AI Insights | `/insights` | Executive summary and insight cards |

## Screenshots

**Sales Analytics dashboard**

![Sales Analytics Dashboard](docs/screenshots/00_dashboard_sales.png)

**Swagger API documentation**

![Swagger UI](docs/screenshots/00_swagger_ui.png)

**Key Performance Indicators**

![KPI snapshot](docs/screenshots/01_kpi_snapshot.png)

**Monthly revenue**

![Monthly revenue](docs/screenshots/02_monthly_revenue.png)

**Top categories by revenue**

![Top categories](docs/screenshots/04_top_categories_revenue.png)

**Sales forecast**

![Forecast](docs/screenshots/19_forecast_actual_vs_predicted.png)

**Anomaly detection**

![Anomalies](docs/screenshots/21_order_anomalies_scatter.png)

## Acknowledgements

- Dataset: [Olist](https://olist.com), published on Kaggle under CC BY-NC-SA 4.0.
- Built as part of the AICTE – IBM SkillsBuild Data Analytics with AI Internship 2026 (BharatCares).
- Developed with assistance from IBM Bob.
