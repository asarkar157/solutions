package policy

# OIDC/SLSA provenance checks previously used `input.context.provenance`, which is
# not part of the standard policy evaluation input. Extend this policy when
# provenance is available on a supported path.

default approval_required := false
