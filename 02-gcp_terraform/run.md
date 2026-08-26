terraform init -backend-config="bucket=my_gcs_bucket"
terraform plan -var="project_id=my-devops-journey-502420"
terraform apply -var="project_id=my-devops-journey-502420"