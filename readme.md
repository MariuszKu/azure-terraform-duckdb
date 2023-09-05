# To deply this code in your enviroment 
- create a resorce group
- create a Service Principal and generate its secrete
- add the Service Principal as a contributor in the resorce group
  ![image](https://github.com/MariuszKu/azure-terraform-duckdb/assets/55062728/28424e49-132e-4660-8c1b-97e2a5ad1e84)

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
terraform init

terraform plan -var-file="testing.tfvars"

terraform apply -var-file="testing.tfvars"
```
# Know issues

If you can't see the docker image in container registry you can build the docker and upload it using the instruction bellow "container registry - deploy docker to Azure container registy" and restart terraform script.


# Build docker

docker build -t tree .

docker run --name tree -d tree

docker run -d --env-file .env --name tree tree

# Container registry - deploy docker to Azure container registy

az acr login --name [registyname]

docker tag tree [registyname].azurecr.io/tree

docker push [registyname].azurecr.io/tree

az acr update -n [registyname] --admin-enabled true
