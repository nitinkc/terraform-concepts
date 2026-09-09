# Committed on purpose: every value here is a lab placeholder or a
# non-sensitive ID, so the sandbox runs without reconstructing tfvars first.
# `terraform.tfvars.example` is the annotated reference copy — edit this file
# in place. Real secrets never belong here; pass them via TF_VAR_* instead.
#
# All three variables have defaults in variables.tf; these override them for
# lab use.

database_name = "sampleapp"
db_schema     = "sa-cloud-sql"

# db-f1-micro is the cheapest real Cloud SQL tier. This root creates a real,
# billable instance the moment you apply it — see the cost section of the
# RUNBOOK before you do.
tier = "db-f1-micro"
