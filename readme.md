docker build -t tree .

docker run --name tree -d tree

docker run -d --env-file .env --name tree tree

# container registry

az acr login --name myregistry

docker tag tree crmkfilm001.azurecr.io/tree

docker push crmkfilm001.azurecr.io/tree

az acr update -n crmkfilm001 --admin-enabled true