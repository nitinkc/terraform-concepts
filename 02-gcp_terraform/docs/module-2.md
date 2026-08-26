# Module 2: Advanced Modular Design

## Learning Objectives
- DRY (Don't Repeat Yourself) via Modules.
- Handling multiple environments (Dev/Prod).
- Input/Output validation.

## Theory
As an FDE, you manage multiple projects. Copy-pasting code is the enemy of stability. 
We will use modules to encapsulate logic and standardize the infrastructure blueprint.

## Hands-On Exercise: Reusable GKE Node Pool
1. **Goal**: Create a module that deploys a standardized Compute Instance.
2. **Structure**:
   - Create a folder `../modules/gcp-vm`.
   - Create `main.tf`, `variables.tf`, and `outputs.tf` inside that module.
3. **Task**: 
   - Refactor your code from Module 1 to call this `gcp-vm` module.
   - Use `variables.tf` to allow different machine types for `dev` vs `prod`.
4. **Challenge**: Add a `precondition` block to ensure the machine type starts with `n1-` or `e2-`.