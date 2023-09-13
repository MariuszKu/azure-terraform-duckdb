import duckdb
import adlfs ,os
#from dotenv import load_dotenv
#load_dotenv()

table_path = "abfs://commonstorage/landing"
fs = adlfs.AzureBlobFileSystem(account_name=os.environ["AZURE_STORAGE_ACCOUNT_NAME"])
con = duckdb.connect()
con.register_filesystem(fs)
df = con.execute(f'''
    select *
    from 
    read_parquet('abfs://commonstorage/silver/df_title')
    limit 10
    '''
).df()
con.unregister_filesystem('abfs')
print(df.head())