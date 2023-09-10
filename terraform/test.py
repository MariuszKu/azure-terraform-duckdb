# Databricks notebook source
import requests

files = [
    "title.basics.tsv.gz",
    "title.ratings.tsv.gz",
]

for file in files:
    url = f"https://datasets.imdbws.com/{file}"
    local_filename = f"/dbfs/mnt/landing/landing/{file}"

    r = requests.get(url, stream=True)
    with open(local_filename, "wb") as f:
        for chunk in r.iter_content(1024*8):
            f.write(chunk)




# COMMAND ----------


df = spark.read.option("separator","\t").csv("/mnt/landing/landing/title.basics.tsv.gz",sep ='\t', header = True)

# COMMAND ----------

display(df)

# COMMAND ----------

df.createOrReplaceTempView("df")

# COMMAND ----------

df_title = spark.sql(
        """
        SELECT 
        cast(tconst as string) tconst, 
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
    )

# COMMAND ----------

display(df_title)

df.write.mode("overwrite").parquet("/mnt/landing/out/df_title")
