# Architecture
![1 4K6CLEHHFEui_qcTOKv6WA](https://github.com/MariuszKu/azure-terraform-duckdb/assets/55062728/caab5fc8-5e06-4504-9689-de242c3427cf)



# To deply this code in your enviroment 
- create a resorce group
- create a Service Principal and generate its secrete
  Azure Active Directory -> App registration -> New Registration
  The secrete you can generate by clicking on your new application registry
  Certificates & Secretes -> New Client Secrete -> copy secrete value

![image](https://github.com/MariuszKu/azure-terraform-duckdb/assets/55062728/ae406d3e-6a20-4b9f-a9f9-6f724c28c3f2)


- add the Service Principal as a contributor in the resorce group

![image](https://github.com/MariuszKu/azure-terraform-duckdb/assets/55062728/95a1d68f-af5f-4cae-b8f0-55f5d28bd46a)

- adjust .env file for local testing and create testing.tfvars file for terraform deployment

testing.tfvars:
```
resource_group = "mk-test"
region = "East US"

client_id = ""
secrete = ""
project = "az"
```
.env
```
AZURE_STORAGE_ACCOUNT_KEY=""
AZURE_STORAGE_ACCOUNT_NAME=""
```
- execute terraform script to create resorces

```
az login

terraform init

terraform plan -var-file="testing.tfvars"

terraform apply -var-file="testing.tfvars"
```
![1 u9cWuDaz-mG8M0geKP_-2g](https://github.com/MariuszKu/azure-terraform-duckdb/assets/55062728/a93cfbfd-8f0c-48c9-83f9-5538ffd2a452)

# Know issues

If you can't see the docker image in container registry you can build the docker and upload it using the instruction bellow "container registry - deploy docker to Azure container registy" and restart terraform script.


# Build docker

docker build -t tree .

docker run --name tree -d tree

docker run -d --env-file .env --name tree tree

# Container registry - deploy docker to Azure container registy

- you need to start docker service

az acr login --name [registyname]

docker tag tree [registyname].azurecr.io/tree

docker push [registyname].azurecr.io/tree

az acr update -n [registyname] --admin-enabled true
