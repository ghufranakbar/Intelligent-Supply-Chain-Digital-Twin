from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.utils.dates import days_ago

default_args = {
    'owner': 'airflow',
    'start_date': days_ago(1),
}

with DAG(
    'supply_chain_pipeline',
    default_args=default_args,
    schedule_interval='@daily',
    catchup=False,
) as dag:

    # Task 1: Run the Python Ingestion Script
    t1 = BashOperator(
        task_id='ingest_data',
        bash_command='pip install pandas sqlalchemy psycopg2-binary && python /opt/airflow/project_code/ingest_data.py',
    )

    # Task 2: Run dbt Transformations using a virtual environment
    t2 = BashOperator(
        task_id='transform_data',
        bash_command='''
        python -m venv dbt_venv && \
        source dbt_venv/bin/activate && \
        pip install --no-cache-dir dbt-postgres && \
        cd /opt/airflow/project_code/analytics && \
        dbt run --profiles-dir . && \
        deactivate
        ''',
    )

    t1 >> t2