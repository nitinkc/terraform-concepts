# Committed on purpose: project_id isn't sensitive and a reader who has to
# invent one before anything runs never runs anything. Production convention is
# the opposite — gitignore tfvars — see docs/theory/17-project-structure.md.
#
# This value wins over the default in variables.tf. Changing only the default
# and wondering why nothing happened is the classic precedence mistake.
project_id = "my-devops-journey-502420" # <-- replace with your own GCP project ID
