terraform {
  required_version = ">= 1.6"
}

# Fake values that match the well-known secret regexps of the worker. The stack
# sets enable_well_known_secret_masking, and no other source marks them secret.
# The code builds each value from parts, so no full value sits in the repository
# for a secret scanner to flag.
locals {
  values = {
    aws_access_key_id = join("", ["AKIA", "SMTESTFAKEKEY001"])
    github_token      = format("%s_%s%015d", "ghp", "SMtestFakeGithubToken", 1)
    jwt               = join(".", ["eyJhbGciOiJIUzI1NiJ9", "eyJzdWIiOiJzbS10ZXN0In0", "c21mYWtlc2lnbmF0dXJl"])
    slack_token       = format("xox%s-%s-%s", "b", "12345678901", "SMtestFakeSlackToken01")
    azure_account_key = join("", ["Account", "Key=smFakeAccountKey0123456789=="])
    # The worker masks logs line by line. A key that spans lines may not match.
    private_key_multiline = join("\n", ["-----BEGIN ${"PRIVATE"} KEY-----", "SMFAKEPRIVATEKEYBODY", "-----END ${"PRIVATE"} KEY-----"])
    private_key_one_line  = join(" ", ["-----BEGIN ${"PRIVATE"} KEY-----", "SMFAKEPRIVATEKEYBODY", "-----END ${"PRIVATE"} KEY-----"])
  }
}

# The plan diff shows the input, so every value lands in the plan log.
resource "terraform_data" "input" {
  input            = local.values
  triggers_replace = timestamp()
}

# The value is part of the resource address, so it lands in the span name.
# The multiline key is left out, because a resource key cannot hold a newline
# that the span name keeps.
resource "terraform_data" "keyed" {
  for_each = toset([for name, value in local.values : value if name != "private_key_multiline"])

  input            = each.key
  triggers_replace = timestamp()
}

# OpenTofu prints the command it executes and the output of the command.
resource "terraform_data" "echo" {
  for_each = local.values

  triggers_replace = timestamp()

  provisioner "local-exec" {
    command = "printf '%s=%s\\n' \"$NAME\" \"$VALUE\""
    environment = {
      NAME  = each.key
      VALUE = each.value
    }
  }
}

# Not sensitive in OpenTofu, so OpenTofu prints the values after the apply.
output "values" {
  value       = local.values
  description = "Every value, printed in the outputs."
}
