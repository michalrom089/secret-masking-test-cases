terraform {
  required_version = ">= 1.6"
}

# OpenTofu marks these values sensitive. Spacelift does not know them, so the
# worker cannot mask them by value. OpenTofu must hide them on its own, and the
# worker must not undo that in the JSON logs or in the spans.
variable "tofu_secret" {
  type        = string
  sensitive   = true
  description = "A sensitive variable with a known value."
  default     = "sm-tofu-sensitive-value-3f80aa52"
}

# The plan diff shows (sensitive value) in place of the input.
resource "terraform_data" "input" {
  input            = var.tofu_secret
  triggers_replace = timestamp()
}

# OpenTofu suppresses the output of a provisioner whose command holds a
# sensitive value.
resource "terraform_data" "echo" {
  triggers_replace = timestamp()

  provisioner "local-exec" {
    command = "echo 'tofu_secret=${var.tofu_secret}'"
  }
}

output "tofu_secret" {
  value       = var.tofu_secret
  sensitive   = true
  description = "The value, in a sensitive output."
}

# nonsensitive() removes the mark. This is the control: it must stay visible.
# upper() keeps the control apart from the value, so a search for the value
# does not find the control.
output "tofu_secret_unmarked" {
  value       = upper(nonsensitive(var.tofu_secret))
  description = "The value in upper case, without the sensitive mark."
}
