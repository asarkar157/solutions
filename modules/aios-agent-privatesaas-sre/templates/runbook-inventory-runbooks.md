Read-only inventory of available runbooks across module SOPs, FireHydrant, internal tooling, and external catalog.

## Catalog sources

${module_runbook_catalog}

${external_runbook_catalog_markdown}

## Steps

1. List module `sg_runbook_sop` resources and summaries.
2. Sample FireHydrant runbook index (read-only).
3. Query internal tooling runbook/search endpoints.
4. Include `external_runbook_catalog` entries.
5. Emit `runbook_inventory` JSON.
