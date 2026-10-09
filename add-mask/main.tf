terraform {
  required_version = ">= 1.6"
}

# hooks/add-mask.sh writes the value to mask.auto.tfvars before init.
variable "mask_value" {
  type        = string
  description = "A value that only a ::add-mask runtime command marks as a secret."
}

# The plan diff shows the input, so the value lands in the plan log.
resource "terraform_data" "input" {
  input            = var.mask_value
  triggers_replace = timestamp()
}

# The value is part of the resource address, so it lands in the span name.
resource "terraform_data" "keyed" {
  for_each = toset([var.mask_value])

  input            = each.key
  triggers_replace = timestamp()
}

# OpenTofu prints the command it executes and the output of the command.
resource "terraform_data" "echo" {
  triggers_replace = timestamp()

  provisioner "local-exec" {
    command = "echo 'mask_value=${var.mask_value}'"
  }
}

# Not sensitive in OpenTofu, so OpenTofu prints the value after the apply.
output "mask_value" {
  value       = var.mask_value
  description = "The value, printed in the outputs."
}
