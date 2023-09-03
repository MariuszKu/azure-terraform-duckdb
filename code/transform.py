import pandas as pd
import duckdb as dd


def clear_files():
    df = pd.read_csv(
        "abfs://commonstorage/landing/title.basics.tsv.gz", sep="\t", low_memory=False
    )
    
    df_genres = dd.sql(
        """
        SELECT 
        nconst, UNNEST(str_split(genres,',')) as genres
        from
        df
    """
    ).to_df()

    df_genres.to_parquet("abfs://commonstorage/silver/genres")

    df_title = dd.sql(
        """
        SELECT 
        nconst, 
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
