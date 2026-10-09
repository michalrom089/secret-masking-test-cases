#!/bin/sh
# Registers a value that Spacelift does not know with the ::add-mask runtime
# command, then hands the value to OpenTofu. The worker must mask every later
# occurrence of the value.
set -eu

value="sm-add-mask-value-b72c4e19"

echo "::add-mask $value"
echo "after add-mask: $value"
printf 'mask_value = "%s"\n' "$value" > mask.auto.tfvars
