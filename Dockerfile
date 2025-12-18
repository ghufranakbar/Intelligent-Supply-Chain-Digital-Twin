FROM apache/airflow:2.7.1
USER root
RUN apt-get update && apt-get install -y git
USER airflow

RUN mkdir -p /opt/airflow/project_code

COPY . /opt/airflow/project_code

RUN pip install pandas sqlalchemy psycopg2-binary dbt-postgres