import pandas as pd
from sqlalchemy import create_engine
from datetime import datetime

CSV_PATH = r'C:\Users\ayari\Downloads\python projects\fashion-retail-sql-powerbi-analytics\dataset\FashionDataset.csv'

SERVER = r'Alaa\SQLEXPRESS'
DATABASE = r'FashionPortfolio'

CONN_STR = (
    f"mssql+pyodbc://{SERVER}/{DATABASE}"
    "?driver=ODBC+Driver+17+for+SQL+Server&trusted_connection=yes"
)

df = pd.read_csv(CSV_PATH)

df = df.rename(columns={
    'Unnamed: 0': 'source_row_id',
    'BrandName':  'brand_name',
    'Deatils':    'deatils',
    'Sizes':      'sizes',
    'MRP':        'mrp',
    'SellPrice':  'sell_price',   # underscore, matches the SQL table
    'Discount':   'discount',
    'Category':   'category',
})

df['dwh_source_file'] = CSV_PATH
df['dwh_load_date'] = datetime.now()   # matches SQL column dwh_load_date

print(f'{len(df)} rows from {CSV_PATH}')



engine = create_engine(CONN_STR, fast_executemany=True)

df.to_sql(
    "raw_fashion",          # matches the table created in SQL
    schema='bronze',
    con=engine,
    if_exists="append",
    index=False,
    chunksize=5000,
)

print("Bronze load complete: bronze.raw_fashion")

with engine.connect() as conn:
    count = conn.exec_driver_sql('SELECT COUNT(*) FROM bronze.raw_fashion').scalar()
    print(f"Row count in bronze.raw_fashion: {count:,}")