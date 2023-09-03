import requests
import adlfs
import logging
import os
import transform as tra

def main():
    fs = adlfs.AzureBlobFileSystem(account_name=os.environ["AZURE_STORAGE_ACCOUNT_NAME"])

    files = [
        "title.basics.tsv.gz",
        "title.ratings.tsv.gz",
    ]

    logging.info('start')

    for file in files:
        url = f"https://datasets.imdbws.com/{file}"
        local_filename = f"commonstorage/landing/{file}"

        r = requests.get(url, stream=True)
        with fs.open(local_filename, "wb") as f:
            for chunk in r.raw.stream(1024, decode_content=False):
                if chunk:
                    f.write(chunk)
        logging.info(f"file: {file}")

    logging.info('files imported')

if __name__ == "__main__":
    main()
    tra.clear_files()