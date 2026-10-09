# One stack per entry. The key is the stack name suffix and the project root.
#
# secrets          are write-only environment variables on the stack.
# plain            are plain environment variables on the stack.
# context          attaches the context that holds TF_VAR_context_secret.
# before_init      are hooks the stack runs before init.
# after_apply      are hooks the stack runs after apply.
# well_known_masks turns on enable_well_known_secret_masking.
#
# stack_defaults holds the value of every field an entry omits.
locals {
  # Prints each secret from a hook, before OpenTofu sees it.
  echo_hook = "echo \"hook: stack_secret=$${TF_VAR_stack_secret:-} context_secret=$${TF_VAR_context_secret:-} plain_value=$${TF_VAR_plain_value:-}\" && printf 'hook: special_secret=%s\\n' \"$${TF_VAR_special_secret:-}\""

  stack_entries = {
    "env-secrets" = {
      description = "Write-only environment variables from the stack and a context, and a plain control."
      secrets = {
        TF_VAR_stack_secret   = var.stack_secret
        TF_VAR_special_secret = var.special_secret
      }
      plain = {
        TF_VAR_plain_value = var.plain_value
      }
      context     = true
      before_init = [local.echo_hook]
      # Prints the outputs JSON-encoded, so the values reach the run logs
      # with < > & escaped as \u003c \u003e \u0026.
      after_apply = ["tofu output -json"]
    }
    "add-mask" = {
      description = "A hook marks a value secret with the ::add-mask runtime command."
      before_init = ["sh hooks/add-mask.sh"]
    }
    "well-known-patterns" = {
      description      = "Fake values that match the well-known secret patterns, with well-known secret masking on."
      well_known_masks = true
    }
    "tofu-sensitive" = {
      description = "Values that only OpenTofu marks sensitive."
    }
    "error-message" = {
      description = "The apply fails with a write-only environment variable in the error message."
      secrets = {
        TF_VAR_stack_secret = var.stack_secret
      }
      before_init = [local.echo_hook]
    }
  }

  stack_defaults = {
    secrets          = {}
    plain            = {}
    context          = false
    before_init      = null
    after_apply      = null
    well_known_masks = false
  }

  stacks = {
    for key, entry in local.stack_entries : key => merge(local.stack_defaults, entry)
  }

  secret_variables = merge([
    for key, stack in local.stacks : {
      for name, value in stack.secrets : "${key}/${name}" => { stack = key, name = name, value = value }
    }
  ]...)

  plain_variables = merge([
    for key, stack in local.stacks : {
      for name, value in stack.plain : "${key}/${name}" => { stack = key, name = name, value = value }
    }
  ]...)
}

# One space that holds every test case stack.
resource "spacelift_space" "test_cases" {
  name             = var.repository
  parent_space_id  = var.parent_space_id
  description      = "Stacks that check the worker masks secrets."
  inherit_entities = true

  labels = ["secret-masking"]
}

resource "spacelift_stack" "test_case" {
  for_each = local.stacks

  name        = "${var.name_prefix}-${each.key}"
  description = each.value.description

  # No VCS block. The stack uses the managed GitHub integration, and the
  # backend takes the namespace from the GitHub app installation.
  repository   = var.repository
  branch       = var.branch
  project_root = each.key

  # A native OpenTofu stack. The worker uploads JSON logs and spans only for it.
  opentofu {
    version = var.tofu_version
  }

  before_init                      = each.value.before_init
  after_apply                      = each.value.after_apply
  enable_well_known_secret_masking = each.value.well_known_masks

  space_id   = spacelift_space.test_cases.id
  autodeploy = true

  labels = ["secret-masking", "test-case", each.key]
}

resource "spacelift_environment_variable" "secret" {
  for_each = local.secret_variables

  stack_id   = spacelift_stack.test_case[each.value.stack].id
  name       = each.value.name
  value      = each.value.value
  write_only = true
}

resource "spacelift_environment_variable" "plain" {
  for_each = local.plain_variables

  stack_id   = spacelift_stack.test_case[each.value.stack].id
  name       = each.value.name
  value      = each.value.value
  write_only = false
}

# A context, so the worker also gets a secret that does not sit on the stack.
resource "spacelift_context" "secrets" {
  name        = "${var.name_prefix}-secrets"
  description = "Holds TF_VAR_context_secret for the secret masking stacks."
  space_id    = spacelift_space.test_cases.id

  labels = ["secret-masking"]
}

resource "spacelift_environment_variable" "context_secret" {
  context_id = spacelift_context.secrets.id
  name       = "TF_VAR_context_secret"
  value      = var.context_secret
  write_only = true
}

resource "spacelift_context_attachment" "secrets" {
  for_each = toset([for key, stack in local.stacks : key if stack.context])

  context_id = spacelift_context.secrets.id
  stack_id   = spacelift_stack.test_case[each.key].id
}

# One run per stack. It fires once, at create, after the stack has its
# environment.
resource "spacelift_run" "first" {
  for_each = var.trigger_runs ? toset(keys(local.stacks)) : toset([])

  stack_id = spacelift_stack.test_case[each.key].id

  depends_on = [
    spacelift_environment_variable.secret,
    spacelift_environment_variable.plain,
    spacelift_environment_variable.context_secret,
    spacelift_context_attachment.secrets,
  ]
}
