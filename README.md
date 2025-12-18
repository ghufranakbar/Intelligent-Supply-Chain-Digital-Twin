# Intelligent Supply Chain Digital Twin

A comprehensive data engineering solution for building a digital twin of supply chain operations using Apache Airflow, PostgreSQL, dbt, and Python. This project automates data ingestion, transformation, and analytics pipelines for the E-commerce Supply Chain dataset.

## 🎯 Project Overview

This project implements a modern data stack for supply chain analytics with:

- **Data Ingestion**: Automated CSV loading into PostgreSQL
- **Orchestration**: Apache Airflow manages daily pipeline execution
- **Transformation**: dbt handles SQL-based data transformations
- **Analytics**: PgAdmin for database exploration and visualization
- **Containerization**: Docker Compose for easy deployment

### Key Features

 **Fully Dockerized** - All services run in containers  
 **Automated Scheduling** - Daily data pipeline execution  
 **Data Quality** - Error handling and logging  
 **Scalable Architecture** - Modular design for easy expansion  
 **Data Warehouse** - Staged and mart models for analytics  

---

## Table of Contents

- [Architecture](#-architecture)
- [Quick Start](#-quick-start)
- [Project Structure](#-project-structure)
- [Configuration](#-configuration)
- [Usage](#-usage)
- [Services](#-services)
- [Data Pipeline](#-data-pipeline)
- [Database Schema](#-database-schema)
- [Development](#-development)
- [Troubleshooting](#-troubleshooting)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Airflow Orchestration                   │
│  ┌──────────────┐            ┌──────────────┐               │
│  │   Webserver  │ ◄────────► │  Scheduler   │               │
│  │  :8081       │            │  (daily)     │               │
│  └──────────────┘            └──────────────┘               │
└─────────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
┌──────────────────────────┐  ┌──────────────────────────┐
│   Data Ingestion         │  │   dbt Transformations    │
│   (Python + SQLAlchemy)  │  │   (SQL Models)           │
│   CSV → PostgreSQL       │  │   Staging → Marts        │
└──────────────────────────┘  └──────────────────────────┘
         │                              │
         └──────────────┬───────────────┘
                        ▼
         ┌──────────────────────────────┐
         │    PostgreSQL Databases      │
         │  ┌────────────────────────┐  │
         │  │  supply_chain_db       │  │
         │  │  (Raw + Transformed)   │  │
         │  └────────────────────────┘  │
         │  ┌────────────────────────┐  │
         │  │  airflow (Metadata)    │  │
         │  └────────────────────────┘  │
         └──────────────────────────────┘
                        │
                        ▼
         ┌──────────────────────────────┐
         │       PgAdmin Portal         │
         │       :8080                  │
         │   (Browse & Visualize)       │
         └──────────────────────────────┘
```

---

## Quick Start

### Prerequisites

- Docker & Docker Compose (v2.39.4+)
- Python 3.8+ (for local development)
- 4GB+ RAM available
- Port availability: 8080, 8081, 5435

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/ghufranakbar/Intelligent-Supply-Chain-Digital-Twin.git
   cd Intelligent-Supply-Chain-Digital-Twin
   ```

2. **Start all services**
   ```bash
   docker-compose up -d --build
   ```
   
   This will:
   - Build the Airflow Docker image
   - Initialize the Airflow database
   - Start PostgreSQL instances
   - Launch the Airflow webserver and scheduler
   - Start PgAdmin

3. **Access the applications**

   | Service | URL | Username | Password |
   |---------|-----|----------|----------|
   | Airflow Webserver | http://localhost:8081 | admin | admin |
   | PgAdmin | http://localhost:8080 | admin@admin.com | admin |
   | PostgreSQL (Supply Chain) | localhost:5435 | user | password |

4. **Verify everything is running**
   ```bash
   docker-compose ps
   ```
   
   All containers should show `Up` status.

5. **Trigger the first pipeline run**
   - Open Airflow at http://localhost:8081
   - Find the `supply_chain_pipeline` DAG
   - Click the play button to trigger manually
   - Monitor execution in the Airflow UI

---

## Project Structure

```
Intelligent-Supply-Chain-Digital-Twin/
│
├──  docker-compose.yaml          # Service orchestration
├──  Dockerfile                   # Airflow image definition
├──  ingest_data.py              # Data ingestion script
├──  README.md                   # This file
│
├──  dags/
│   └── supply_chain_dag.py        # Airflow DAG definition
│
├──  Dataset/                    # Raw CSV data files
│   ├── olist_customers_dataset.csv
│   ├── olist_orders_dataset.csv
│   ├── olist_order_items_dataset.csv
│   ├── olist_order_payments_dataset.csv
│   ├── olist_order_reviews_dataset.csv
│   ├── olist_products_dataset.csv
│   ├── olist_sellers_dataset.csv
│   ├── olist_geolocation_dataset.csv
│   └── product_category_name_translation.csv
│
├──  analytics/                  # dbt project
│   ├── dbt_project.yml            # dbt configuration
│   ├── profiles.yml               # Database connection config
│   ├──  models/
│   │   ├── sources.yaml           # Raw data source definitions
│   │   ├── staging/            # Intermediate transformations
│   │   │   ├── stg_orders.sql
│   │   │   ├── stg_order_items.sql
│   │   │   └── stg_products.sql
│   │   └── marts/              # Final analytical tables
│   │       └── supply_chain_master.sql
│   ├──  tests/                  # Data quality tests
│   ├──  seeds/                  # Reference data
│   └──  macros/                 # Reusable SQL functions
│
├── logs/                       # Airflow task logs
│   └── dag_id=supply_chain_pipeline/
│
└── plugins/                    # Custom Airflow plugins
```

---

## Configuration

### Docker Compose Services

#### Airflow Webserver & Scheduler
```yaml
Environment Variables:
  - AIRFLOW__CORE__EXECUTOR=LocalExecutor
  - AIRFLOW__CORE__SQL_ALCHEMY_CONN=postgresql+psycopg2://airflow:airflow@postgres_airflow/airflow
  - AIRFLOW__CORE__FERNET_KEY=46BKJoQYlPPOexq0OhDZnIlNepKFf87WFwLbfzqDDho=
  - AIRFLOW__CORE__LOAD_EXAMPLES=False
```

#### PostgreSQL Instances
- **postgres** (Data warehouse): user:password on port 5435
- **postgres_airflow** (Metadata): airflow:airflow (internal network only)

### Airflow Configuration

The Airflow configuration is defined in `docker-compose.yaml`:
- **Executor**: LocalExecutor (suitable for single-machine deployment)
- **Schedule**: Daily at UTC midnight (`@daily`)
- **Catch-up**: Disabled (only runs current and future dates)

### dbt Configuration

Edit `analytics/profiles.yml` to customize database connections:

```yaml
analytics:
  target: dev
  outputs:
    dev:
      type: postgres
      host: postgres
      user: user
      password: password
      port: 5432
      dbname: supply_chain_db
      schema: public
      threads: 4
```

---

##  Usage

### Running the Pipeline

#### Manual Trigger
1. Go to http://localhost:8081
2. Find the `supply_chain_pipeline` DAG
3. Click the play button in the top-right corner
4. Monitor execution on the DAG graph

#### Automatic Scheduling
The pipeline runs automatically every day at midnight UTC. No manual action required.

### Monitoring Tasks

**Airflow Webserver**:
- Graph View: Visual representation of DAG dependencies
- Tree View: Historical execution timeline
- Logs: Real-time task execution logs
- Admin Panel: User management and configuration

**PgAdmin**:
1. Navigate to http://localhost:8080
2. Register the PostgreSQL server:
   - Host: `postgres`
   - Port: `5432`
   - Username: `user`
   - Password: `password`
3. Browse tables and run queries

### Querying the Data

Connect to PostgreSQL using any client:

```bash
psql -h localhost -p 5435 -U user -d supply_chain_db
```

View staged and transformed data:
```sql
-- Raw ingested tables
SELECT * FROM public.orders LIMIT 10;
SELECT * FROM public.products LIMIT 10;

-- Staging models
SELECT * FROM public.stg_orders LIMIT 10;

-- Analytical marts
SELECT * FROM public.supply_chain_master LIMIT 10;
```

---

## Data Pipeline

### Pipeline Execution Flow

```
Task 1: ingest_data (Daily at 00:00 UTC)
├─ Install dependencies
├─ Run ingest_data.py
├─ Load CSV files into PostgreSQL
└─ Tables: orders, products, order_items, etc.

       ▼ (Success)

Task 2: transform_data (Depends on Task 1)
├─ Create dbt virtual environment
├─ Install dbt-postgres
├─ Run dbt models
├─ Staging layer (stg_orders, stg_order_items, stg_products)
└─ Marts layer (supply_chain_master)
```

### Data Files Ingested

| File | Table | Records | Columns |
|------|-------|---------|---------|
| olist_orders_dataset.csv | orders | ~100K | 5 |
| olist_order_items_dataset.csv | order_items | ~600K | 7 |
| olist_products_dataset.csv | products | ~32K | 5 |
| olist_customers_dataset.csv | customers | ~100K | 5 |
| olist_sellers_dataset.csv | sellers | ~3.6K | 4 |
| olist_order_payments_dataset.csv | order_payments | ~100K | 4 |
| olist_order_reviews_dataset.csv | order_reviews | ~100K | 5 |
| olist_geolocation_dataset.csv | geolocation | ~1M | 5 |
| product_category_name_translation.csv | product_category_translation | ~71 | 2 |

---

## Database Schema

### Raw Tables (Ingested)
```sql
-- Core entities
orders(order_id, customer_id, order_status, order_purchase_timestamp, ...)
order_items(order_id, order_item_id, product_id, seller_id, ...)
products(product_id, product_category_name, product_weight_g, ...)
customers(customer_id, customer_zip_code_prefix, customer_city, ...)
sellers(seller_id, seller_zip_code_prefix, seller_city, ...)
```

### Staging Models (dbt)
```sql
-- Cleaned and deduplicated
stg_orders
stg_order_items
stg_products
```

### Marts (Analytics Layer)
```sql
-- business-ready tables
supply_chain_master
  ├─ order_id
  ├─ order_date
  ├─ customer_id
  ├─ product_id
  ├─ quantity
  ├─ payment_amount
  └─ order_status
```

---

##  Development

### Local Development Setup

Install Python dependencies:
```bash
pip install pandas sqlalchemy psycopg2-binary dbt-postgres
pip install apache-airflow==2.7.1
pip install shap statsmodels xgboost scikit-learn matplotlib seaborn
```

### Adding New Data Sources

1. **Add CSV to `Dataset/` folder**
2. **Update `ingest_data.py`**:
   ```python
   load_file(
       'Dataset/new_dataset.csv',
       'new_table_name'
   )
   ```
3. **Update dbt `sources.yaml`** to reference the new table
4. **Restart pipeline**: `docker-compose restart airflow-scheduler`

### Adding New Transformations

1. **Create SQL file in `analytics/models/staging/` or `marts/`**:
   ```sql
   -- analytics/models/marts/new_mart.sql
   SELECT
       order_id,
       COUNT(*) as item_count,
       SUM(amount) as total_amount
   FROM {{ ref('stg_order_items') }}
   GROUP BY 1
   ```

2. **Run dbt locally**:
   ```bash
   cd analytics
   dbt run
   dbt test
   ```

3. **Commit and deploy**

### Testing

Run dbt data quality tests:
```bash
cd analytics
dbt test
```

---

##  Troubleshooting

### Airflow Not Starting

**Symptom**: Connection refused on http://localhost:8081

**Solution**:
```bash
# Restart the stack
docker-compose down
docker-compose up -d --build

# Check logs
docker-compose logs -f airflow-webserver
```

### Pipeline Task Failing

**Solution**:
1. Check task logs in Airflow UI → DAG → Task Instance Logs
2. Verify PostgreSQL is running: `docker-compose ps postgres`
3. Check data files exist: `ls Dataset/`
4. Restart scheduler: `docker-compose restart airflow-scheduler`

### Database Connection Issues

**Error**: `psycopg2.OperationalError: could not connect to server`

**Solution**:
- Use container name: `postgres` (not `localhost`)
- Verify ports: PostgreSQL on 5435 (host), 5432 (container)
- Check network: `docker network ls`

### dbt Errors

**Error**: `Compilation Error in models/...`

**Solution**:
```bash
# Run dbt locally for detailed errors
cd analytics
dbt parse
dbt compile
```

### Out of Disk Space

```bash
# Clean Docker resources
docker system prune -a
docker volume prune
```

---

##  Dependencies

### Core Stack
- **Apache Airflow 2.7.1** - Workflow orchestration
- **PostgreSQL 13** - Data storage
- **dbt 1.x** - Data transformation
- **Python 3.8+** - Data processing

### Python Packages
```
pandas>=1.3.0
sqlalchemy>=1.4.0
psycopg2-binary>=2.9.0
dbt-postgres>=1.0.0
apache-airflow==2.7.1
```

### Analytics Libraries (Optional)
```
scikit-learn
xgboost
shap
matplotlib
seaborn
statsmodels
```

---

##  Security

**Development Only Setup** - For production, implement:

1. **Secrets Management**
   - Use environment variables or secret managers
   - Never commit credentials
   - Rotate database passwords

2. **Network Security**
   - Use internal networks only (no external exposure)
   - Implement VPN for remote access
   - Enable SSL/TLS for connections

3. **Access Control**
   - Implement Airflow RBAC
   - Use database user roles
   - Audit logging

---

##  Additional Resources

- [Apache Airflow Documentation](https://airflow.apache.org/docs/)
- [dbt Documentation](https://docs.getdbt.com/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)

---

##  License

This project is part of the Intelligent Supply Chain Digital Twin initiative.

##  Author

**Ghufran Akbar**  
Repository: https://github.com/ghufranakbar/Intelligent-Supply-Chain-Digital-Twin

---

##  Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

---

**Last Updated**: December 2025  
**Status**: Active Development  
**Airflow Version**: 2.7.1  
**dbt Version**: 1.x