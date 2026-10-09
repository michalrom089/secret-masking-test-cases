terraform {
  required_version = ">= 1.6"
}

variable "stack_secret" {
  type        = string
  description = "A write-only environment variable on the stack."
}

# The provisioner fails, and OpenTofu quotes the command in the error message.
# The worker does not sanitize the span status message, so this case checks
# that the secret does not reach it.
resource "terraform_data" "fail" {
  triggers_replace = timestamp()

  provisioner "local-exec" {
    command = "echo 'failing with stack_secret=${var.stack_secret}' && exit 1"
  }
}
