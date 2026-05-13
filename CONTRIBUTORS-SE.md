# Solutions team — scenario owners

This file is the canonical list of **scenario owners** from the solutions team.
Each owner reviews PRs that touch their scenario, runs that scenario in front
of prospects, and is the SE's first point of contact when something feels off.

If you are an SE, do not wait for office hours when you need an opinion about
one specific scenario — ping the owner directly.

If you are an engineer changing a scenario, **tag the owner** on your PR.

## How to update this file

Open a PR adding / removing a row. The engineering lead (see bottom of file)
will tag the relevant owner for confirmation before merging.

## Scenario owners

| Scenario / area | Path | Primary owner | Backup |
|------------------|------|---------------|--------|
| `aws-sre-demo` | [`examples/scenarios/aws-sre-demo/`](examples/scenarios/aws-sre-demo/) | _unassigned_ | _unassigned_ |
| `finops-weekly` | [`examples/scenarios/finops-weekly/`](examples/scenarios/finops-weekly/) | _unassigned_ | _unassigned_ |
| `pipeline-insights` | [`examples/scenarios/pipeline-insights/`](examples/scenarios/pipeline-insights/) | _unassigned_ | _unassigned_ |
| `incident-triage` | [`examples/scenarios/incident-triage/`](examples/scenarios/incident-triage/) | _unassigned_ | _unassigned_ |
| `repo-to-iac` | [`examples/scenarios/repo-to-iac/`](examples/scenarios/repo-to-iac/) | _unassigned_ | _unassigned_ |
| `clean-tenant-reset` | [`examples/scenarios/clean-tenant-reset/`](examples/scenarios/clean-tenant-reset/) | _unassigned_ | _unassigned_ |
| UI-export tool | [`tools/aios-export/`](tools/aios-export/) | _unassigned_ | _unassigned_ |
| SE playbook | [`docs/se-playbook.md`](docs/se-playbook.md) | _unassigned_ | _unassigned_ |

> Why so many `_unassigned_` slots? This file ships from the engineering side;
> the first round of names lands after the kickoff interview (see
> [`docs/se-interview-prep.md`](docs/se-interview-prep.md) and
> [`docs/se-feedback.md`](docs/se-feedback.md)).

## Owner responsibilities

An owner agrees to:

1. Review PRs that touch their scenario within **2 business days** during the
   first month, then weekly thereafter.
2. Run the scenario in front of at least one prospect per quarter and report
   back in office hours (what landed, what fell flat, what needs to change).
3. Update the README "Talk track" section when the pitch evolves.
4. File a `scenario-request` issue (or PR) when a prospect asks a variation
   that does not fit cleanly.

This is intentionally lightweight. If an owner cannot keep the SLA, ping the
engineering lead to reassign — empty cells are better than stale ones.

## Engineering lead

- Repo & rework: _to be filled when the first interview happens_

## Office hours

See [`docs/se-feedback.md`](docs/se-feedback.md) for the recurring slot, Slack
channel, and async triage rules.
