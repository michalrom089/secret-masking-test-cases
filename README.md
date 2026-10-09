# secret-masking-test-cases

OpenTofu configurations that put known secret values in front of the
Spacelift worker. Each run must show `*****` in place of every secret.

The worker masks secrets in three places:

- the run logs,
- the JSON logs (`<run ULID>/json-logs/` in the run observability bucket),
- the OpenTofu spans (`<run ULID>/otel-traces/` in the same bucket).

Every case puts its values in the plan diff, a resource address, a `local-exec`
command and its output, and the outputs. The resource address ends up in the
span name, which the worker does not sanitize.

| Project root           | Secret source                                | Apply    |
| ---------------------- | -------------------------------------------- | -------- |
| `env-secrets/`         | write-only env vars on the stack and context | succeeds |
| `add-mask/`            | a `::add-mask` runtime command in a hook     | succeeds |
| `well-known-patterns/` | values that match the well-known regexps     | succeeds |
| `tofu-sensitive/`      | `sensitive = true` in OpenTofu only          | succeeds |
| `error-message/`       | a write-only env var in an error message     | fails    |

## The values

Each value is fake and unique. Search for it in every place above. A match
means the worker failed to mask it. The controls must match, or the search
does not work.

| Value                                              | Source                         | Expected |
| -------------------------------------------------- | ------------------------------ | -------- |
| `sm-stack-secret-value-e41b7c09`                   | `TF_VAR_stack_secret`          | masked   |
| `sm-context-secret-value-5a93d2f8`                 | `TF_VAR_context_secret`        | masked   |
| `sm-special-"quoted"-back\slash-<tag>&amp-77d1c3`  | `TF_VAR_special_secret`        | masked   |
| `sm-add-mask-value-b72c4e19`                       | `add-mask/hooks/add-mask.sh`   | masked   |
| `sm-tofu-sensitive-value-3f80aa52`                 | `tofu-sensitive/` default      | hidden   |
| `AKIASMTESTFAKEKEY001` and the other fake patterns | `well-known-patterns/main.tf`  | masked   |
| `sm-plain-value-not-a-secret-0c6e9b`               | `TF_VAR_plain_value`, control  | visible  |
| `SM-TOFU-SENSITIVE-VALUE-3F80AA52`                 | `tofu-sensitive/`, control     | visible  |

`special_secret` holds characters that JSON and HCL escape. The plan diff shows
it as `\"quoted\"` and `back\\slash`, and the JSON logs as `<tag>` or
`<tag>`. Search for each form.

`well-known-patterns/` builds each value from parts, so no full value sits in
the repository. Its stack sets `enable_well_known_secret_masking`. Without it the
worker masks none of them.

## The stacks

`spacelift/` is not a test case. It creates the space
`secret-masking-test-cases`, one stack per case named `secret-masking-<case>`,
the `secret-masking-secrets` context and the environment variables. It starts
one run per stack.

## Getting started

This creates one bootstrap stack. The bootstrap stack creates the rest. The
commands need spacectl v1.20.0 or later and a spacectl profile.

**1. Create the bootstrap stack.** It reads this repository through the
managed GitHub integration. The GitHub app installation must cover this
repository.

```bash
spacectl api --variables '{
  "input": {
    "name": "secret-masking-bootstrap",
    "description": "Creates the secret masking test case space and stacks.",
    "provider": "GITHUB",
    "repository": "secret-masking-test-cases",
    "namespace": "michalrom089",
    "branch": "main",
    "projectRoot": "spacelift",
    "space": "root",
    "autodeploy": true,
    "administrative": false,
    "labels": ["secret-masking", "bootstrap"],
    "vendorConfig": {
      "opentofu": { "version": "1.10.6", "workflowTool": "OPENTOFU" }
    }
  },
  "manageState": true
}' 'mutation CreateBootstrap($input: StackInput!, $manageState: Boolean!) {
  stackCreate(input: $input, manageState: $manageState) { id name }
}'
```

**2. Give the stack permission to create the space and the stacks.** Attach the
`space-admin` system role in `root`.

```bash
ROLE_ID=$(spacectl api '{ roles { id slug } }' --raw \
  | jq -r '.data.roles[] | select(.slug == "space-admin") | .id')

spacectl api --variables "{
  \"input\": {
    \"stackID\": \"secret-masking-bootstrap\",
    \"roleID\": \"$ROLE_ID\",
    \"spaceID\": \"root\"
  }
}" 'mutation AttachRole($input: StackRoleBindingInput!) {
  stackRoleBindingCreate(input: $input) { id }
}'
```

**3. Run it.**

```bash
spacectl stack deploy --id secret-masking-bootstrap
```

To run the cases again later:

```bash
for c in env-secrets add-mask well-known-patterns tofu-sensitive error-message; do
  spacectl stack deploy --id "secret-masking-$c"
done
```

## Checking a run

Search the run logs of every phase, then the run observability bucket. The
bucket files are gzipped JSON lines or JSON. Decompress them before you search.

```bash
aws s3 cp --recursive "s3://$BUCKET/$RUN_ULID/" "./$RUN_ULID/"
find "./$RUN_ULID" -name '*.gz' -exec gunzip {} +
grep -rF 'sm-stack-secret-value-e41b7c09' "./$RUN_ULID"
```

## Requirements

OpenTofu 1.6 or later. The cases use only `terraform_data` and need no provider.
