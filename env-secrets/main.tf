terraform {
  required_version = ">= 1.6"
}

# The stack sets each variable through a TF_VAR_ environment variable.
# OpenTofu does not know that any of them is a secret. Only Spacelift does.
variable "stack_secret" {
  type        = string
  description = "A write-only environment variable on the stack."
}

variable "context_secret" {
  type        = string
  description = "A write-only environment variable on a context attached to the stack."
}

variable "special_secret" {
  type        = string
  description = "A write-only environment variable with characters that JSON and HCL escape."
}

variable "plain_value" {
  type        = string
  description = "A plain environment variable. The control: it must stay visible."
}

locals {
  values = {
    stack_secret   = var.stack_secret
    context_secret = var.context_secret
    special_secret = var.special_secret
    plain_value    = var.plain_value
  }
}

# The plan diff shows the input, so every value lands in the plan log.
resource "terraform_data" "input" {
  input            = local.values
  triggers_replace = timestamp()
}

# The value is part of the resource address, so it lands in the span name.
resource "terraform_data" "keyed" {
  for_each = toset(values(local.values))

  input            = each.key
  triggers_replace = timestamp()
}

# OpenTofu prints the command it executes and the output of the command.
resource "terraform_data" "echo" {
  triggers_replace = timestamp()

  provisioner "local-exec" {
    command = "echo 'stack_secret=${var.stack_secret} context_secret=${var.context_secret} plain_value=${var.plain_value}'"
  }

  provisioner "local-exec" {
    command = "printf 'special_secret=%s\\n' \"$SPECIAL_SECRET\""
    environment = {
      SPECIAL_SECRET = var.special_secret
    }
  }
}

# Not sensitive in OpenTofu, so OpenTofu prints the values after the apply.
output "values" {
  value       = local.values
  description = "Every value, printed in the outputs."
}
