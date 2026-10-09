variable "repository" {
  type        = string
  description = "Name of the GitHub repository that holds the test cases."
  default     = "secret-masking-test-cases"
}

variable "git_url" {
  type        = string
  description = "HTTPS URL of the repository. The stacks read it through the raw Git vendor, so the account needs no VCS integration."
  default     = "https://github.com/michalrom089/secret-masking-test-cases.git"
}

variable "git_namespace" {
  type        = string
  description = "Namespace the raw Git vendor shows next to the repository name. Cosmetic only."
  default     = "michalrom089"
}

variable "branch" {
  type        = string
  description = "Branch the stacks track."
  default     = "main"
}

variable "parent_space_id" {
  type        = string
  description = "Space that holds the test case space."
  default     = "root"
}

variable "tofu_version" {
  type        = string
  description = "OpenTofu version the stacks run."
  default     = "1.10.6"
}

variable "trigger_runs" {
  type        = bool
  description = "Start one run per stack after the stack is created. The run fires once, at create."
  default     = true
}

variable "name_prefix" {
  type        = string
  description = "Prefix for the stack names. A second copy of the set in the same account also needs a different parent_space_id, because the space name is fixed."
  default     = "sm"
}

# The marker values. They are fake, and they must stay unique, so that a search
# for one finds only the places where the worker failed to mask it.
variable "stack_secret" {
  type        = string
  description = "Value of the write-only TF_VAR_stack_secret on the stacks."
  default     = "sm-stack-secret-value-e41b7c09"
}

variable "context_secret" {
  type        = string
  description = "Value of the write-only TF_VAR_context_secret on the context."
  default     = "sm-context-secret-value-5a93d2f8"
}

variable "special_secret" {
  type        = string
  description = "Value of the write-only TF_VAR_special_secret. It holds characters that JSON and HCL escape."
  default     = "sm-special-\"quoted\"-back\\slash-<tag>&amp-77d1c3"
}

variable "plain_value" {
  type        = string
  description = "Value of the plain TF_VAR_plain_value. The control: it must stay visible."
  default     = "sm-plain-value-not-a-secret-0c6e9b"
}
