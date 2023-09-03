import polars as pd
import duckdb as dd
import adlfs
import os

def clear_files():
    fs = adlfs.AzureBlobFileSystem(account_name=os.environ["AZURE_STORAGE_ACCOUNT_NAME"])
    with fs.open("abfs://commonstorage/landing/title.basics.tsv.gz","rb") as file:
        df = pd.read_csv(file.read()
            , 
            separator="\t", 
            infer_schema_length=0,
            missing_utf8_is_empty_string=True,
            ignore_errors=True
        )
    print(df.head())
    df_genres = dd.sql(
        """
        SELECT 
        tconst, UNNEST(str_split(genres,',')) as genres
        from
        df
    """
    ).to_df()

    df_genres.to_parquet("abfs://commonstorage/silver/genres")

    df_title = dd.sql(
        """
        SELECT 
        tconst, 
        titleType, 
        primaryTitle,
        originalTitle,
        cast(case when isAdult = '\\N' then null else isAdult end as int) isAdult,                            
        cast(case when startYear = '\\N' then null else startYear end as int) startYear,
        cast(case when endYear = '\\N' then null else endYear end as int) endYear,
        cast(case when runtimeMinutes = '\\N' then null else runtimeMinutes end as int) runtimeMinutes
        from
        df
        where
        cast(case when startYear = '\\N' then null else startYear end as int) >= 2000              
    """
    ).to_df()

    df_title.to_parquet("abfs://commonstorage/silver/df_title")

    print("files converted")


if __name__ == "__main__":
    clear_files()
