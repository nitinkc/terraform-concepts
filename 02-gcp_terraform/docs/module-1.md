# Module 1: Foundations & GCP Mental Model

## Learning Objectives
- Understand the Terraform Lifecycle (`init`, `plan`, `apply`, `destroy`).
- Master State Management: GCS Backend, State Locking.
- Map GCP resources to Terraform HCL.

## Theory
Terraform maps your infrastructure to a "State File" (a JSON representation of reality). 
Unlike `gcloud` commands that execute imperative calls, Terraform compares your configuration to the state file (GCS Bucket)
and calculates a diff.

## Hands-On Exercise: The GCS Backend
1. **Goal**: Create a GCS bucket to store your state, and initialize Terraform.
2. **Setup**:
   - Create a directory `module-1`.
   - Create `../provider.tf`:
     ```hcl
     provider "google" {
       project = "YOUR_PROJECT_ID"
       region  = "us-central1"
     }
     ```
   - Create `../backend.tf`:
     ```hcl
     terraform {
       backend "gcs" {
         bucket  = "my-terraform-state-bucket"
         prefix  = "terraform/state/module-1"
       }
     }
     ```
3. **Task**: Write a `../network.tf` to deploy a VPC and a sub-network. Then, run `terraform init` and `terraform apply`.