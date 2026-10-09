# AGENT.md

Instructions for an agent working in this repository.

## What this repository is

OpenTofu configurations that put known secret values in front of the Spacelift
worker. Each project root is one test case. The repository tests secret
masking, not real infrastructure. `terraform_data` is the only resource.

## Rules that every test case follows

1. **Every value is unique.** A search for a value must find only the places
   where the worker failed to mask it. Do not reuse a value as part of another
   string. The controls use a different string on purpose.
2. **Every case shows its values on every surface.** The plan diff, a resource
   address, a `local-exec` command and its output, and the outputs. Every
   resource has `triggers_replace = timestamp()`, so every run applies again.
3. **No full well-known pattern sits in the repository.** Build each value from
   parts, so a secret scanner does not flag it.
4. **The README tables are the contract.** Change a value, change the tables.
5. **Commit no lock file and no `mask.auto.tfvars`.**

## Adding a test case

1. Create a directory named after the secret source.
2. Add one entry to `locals.stack_entries` in `spacelift/main.tf`. The key is
   the project root and the stack name suffix.
3. Add a row to the tables in `README.md`.
4. Run `tofu fmt -recursive -check`, then `tofu init` and `tofu apply` in the
   case. Delete `.terraform/`, the lock file and the state afterwards.

## The `spacelift/` directory

It creates the space, the stacks, the context and the environment variables
with the `spacelift-io/spacelift` provider. A bootstrap stack applies it.

**Do not apply it without asking.** An apply creates real stacks in a real
Spacelift account. `tofu init` and `tofu validate` are safe.

Keep the `opentofu` block on the stack resource. The worker uploads JSON logs
and spans only for a native OpenTofu stack.

## Writing style

Short sentences, one idea each. Active voice. Plain words. Keep identifiers and
product names exact.
