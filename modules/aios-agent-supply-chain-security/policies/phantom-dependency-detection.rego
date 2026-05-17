package policy

# Phantom-dependency and manifest checks previously used `input.context.manifest_analysis`,
# which is not part of the standard policy evaluation input.

default approval_required := false
