# 2 — Variables

**Folder:** [`01-basics/2-variable-use/`](https://github.com/nitinkc/terraform-concepts/tree/main/01-basics/2-variable-use)

`variable` blocks are inputs — like function arguments. Declared in `variables.tf` with a
type and a default, referenced as `var.name`.

## The code

`main.tf` creates two resources, only one of which writes a file:

```hcl
resource "local_file" "fruits" {
  filename = var.fileName
  content  = var.content
}

resource "random_pet" "my_pet" {
  prefix    = var.prefix
  separator = var.separator
  length    = var.name_length
}
```

`variables.tf` declares five inputs, each with a type and a default:

```hcl
variable "fileName" {
  description = "The path where the file will be created"
  type        = string
  default     = "/tmp/helloFruits.txt"
}

variable "content" {
  description = "The content to write into the file"
  type        = string
  default     = "Hello World! Default Text coming from the variable"
}

variable "prefix" {
  description = "The prefix for the random pet name"
  type        = string
  default     = "Mrs"
}

variable "separator" {
  description = "The separator for the random pet name"
  type        = string
  default     = "-"
}

variable "name_length" {
  description = "The length of the random pet name"
  type        = number
  default     = 1
}
```

## Run it

```bash
terraform init && terraform apply
cat /tmp/helloFruits.txt

# override without touching the code — CLI beats default
terraform apply -var='content=overridden from the command line'
```

## A resource that produces no file

`random_pet.my_pet` writes nothing to disk. It exists only in state:

```bash
terraform state show random_pet.my_pet
```

That's the only way to see it. A resource doesn't have to produce an artifact you can
`cat` — it just has to be something the provider can create, track and destroy.

## Precedence — the gotcha that costs real time

Create a `terraform.tfvars` setting `content`, then *also* edit the `default` in
`variables.tf` to something different. Which one wins?

```bash
echo 'content = "from tfvars"' > terraform.tfvars
terraform apply
cat /tmp/helloFruits.txt
```

The tfvars value wins, and the default is never used. Full order, lowest to highest:

```
default  <  terraform.tfvars  <  *.auto.tfvars  <  -var-file  <  -var  <  TF_VAR_*
```

This exact rule cost real debugging time in
[Session 2](../sessions/session-02.md), and it bites again in
[Stage 3](../gcp/01-core-root.md#before-you-run-it) where the project ID is set in two
places at once. The GCP version of this experiment is
[Lab 15](../gcp/02-lab-notes.md#lab-15-terraformtfvars-variable-precedence).

## An unused declared variable is a smell

Worth checking as a habit: every variable declared in `variables.tf` should actually be
referenced somewhere. A declared-but-unused variable is either a leftover from a
refactor or a wiring bug where the code hardcodes what it should read from `var`.
Terraform will not warn you about either.

---

Theory: [§7 Variables & locals](../theory/07-variables-and-locals.md) ·
Quiz: [Variables, expressions & guards](../quiz/03-variables-expressions-and-guards.md) ·
Next: [Locals](03-locals.md)
