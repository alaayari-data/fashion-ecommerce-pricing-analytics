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
for col in df.select_dtypes(include="object").columns:
    print(
        col,
        "max length:",
        df[col].astype("string").str.len().max()
    )
