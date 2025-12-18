import pandas as pd
from sqlalchemy import create_engine
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# --- CONFIGURATION ---
# Connect to the Docker container named 'postgres', not '127.0.0.1'
DB_HOST = os.getenv('DB_HOST', 'postgres')
DB_PORT = os.getenv('DB_PORT', '5432')
DB_NAME = os.getenv('DB_NAME', 'supply_chain_db')
DB_USER = os.getenv('DB_USER', 'user')
DB_PASS = os.getenv('DB_PASS', 'password')

# Database Connection String
connection_string = f"postgresql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
engine = create_engine(connection_string)

def load_file(file_path, table_name):
    """Reads a CSV and uploads it to Postgres"""
    
    # Check if file exists
    if not os.path.exists(file_path):
        # CRITICAL CHANGE: We raise an error so Airflow knows to fail the task
        raise FileNotFoundError(f" CRITICAL ERROR: File not found at {file_path}")

    print(f" Loading '{table_name}'...")
    
    try:
        df = pd.read_csv(file_path)
        df.to_sql(table_name, engine, if_exists='replace', index=False, chunksize=1000)
        print(f" Success! {len(df)} rows loaded into '{table_name}'.")
        
    except Exception as e:
        print(f" Database Error loading {table_name}: {e}")
        # Re-raise the error to stop the pipeline
        raise e

def main():
    # --- DEBUGGING BLOCK ---
    print(" DEBUG: Checking file system...")
    try:
        # Check what is in the project code folder
        project_path = '/opt/airflow/project_code'
        print(f" Contents of {project_path}:")
        print(os.listdir(project_path))
        
        # Check what is in the Dataset folder
        dataset_path = os.path.join(project_path, 'Dataset')
        if os.path.exists(dataset_path):
            print(f" Contents of {dataset_path}:")
            print(os.listdir(dataset_path))
        else:
            print(f" ERROR: Dataset folder NOT found at {dataset_path}")
    except Exception as e:
        print(f" DEBUG ERROR: {e}")

    base_path = '/opt/airflow/project_code/Dataset'
    
    files_to_load = {
        f'{base_path}/olist_customers_dataset.csv': 'customers',
        f'{base_path}/olist_order_items_dataset.csv': 'order_items',
        f'{base_path}/olist_orders_dataset.csv': 'orders',
        f'{base_path}/olist_products_dataset.csv': 'products',
        f'{base_path}/olist_geolocation_dataset.csv': 'geolocation',
        f'{base_path}/olist_order_payments_dataset.csv': 'payments',
        f'{base_path}/olist_sellers_dataset.csv': 'sellers',
        f'{base_path}/product_category_name_translation.csv': 'category_translation'
    }

    print(" Starting Data Ingestion Pipeline...")
    
    for csv_path, table_name in files_to_load.items():
        load_file(csv_path, table_name)
        
    print("\n All data ingested successfully!")

if __name__ == "__main__":
    main()
    
    
    