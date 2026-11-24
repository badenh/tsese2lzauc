# Status

Phase A (seven simple toggles), Phase B part 1 (per-account CMKs, `ssmInventory`, account-level log subscription, CIS monitoring `metricSets`/`alarmSets`), and Phase B part 2 (SCP statement appends, data-residency SCP, auto-remediation Config rules + sidecar files) are encoded in `replacements-for-tse-se.yaml` plus `overlay/`. Round-trip 0 unexpected byte mismatches against `aws/lza-universal-configuration@v1.4.1` on `hub-and-spoke`.

Items covered against TSE-SE's [uplift guide](https://github.com/aws-samples/landing-zone-accelerator-on-aws-for-tse-se/blob/main/uplift-to-tse-se/README.md) sections:

| § | Section | Where |
|---|---|---|
| 1 | Per-account customer-managed KMS keys | Phase B1 |
| 2 | In-configuration data-residency enforcement | Phase B2 (overlay + YAML ref) |
| 3 | Near-real-time threat + sensitive-data findings | Phase A |
| 4 | CIS monitoring alarms | Phase B1 |
| 5 | Additional SCP hardening (EBS/EFS/RDS/AUR/PMP/OTHS) | Phase B2 (JSON append) |
| 6 | Network and identity control-plane lockdown (NET2) | Phase B2 (JSON append) |
| 7 | Network Firewall tamper protection (NFW) | Phase B2 (JSON append) |
| 8 | Active auto-remediation | Phase B2 (YAML + overlay) |
| 9 | Longer retention / finer granularity | Phase A + Phase B1 |

## Reviewer checklist before deploying

1. **Replace the on-prem CIDR placeholders.** Two CIS filters and two CIS alarms carry TSE-SE's example `10.10.10.*` / URL-encoded `REPLACE_WITH_ON_PREM_IP`. Inline `# REVIEW:` comments flag them in the generated `security-config.yaml` after apply.
2. **Tune `deploymentTargets`.** The opinionated OU set in the shipped defaults (`Security`, `Infrastructure`, `Workloads`, `Workloads/{Dev,Test,Prod,Sandbox}`, `Management`) matches the UC baseline. If your organization uses different OU names, update them before applying.
3. **Set `excludedRegions`.** Omitted intentionally on the CMK blocks. Add per your enabled-region strategy — the UC baseline enables a smaller region set than TSE-SE did.
4. **Watch the Control Tower SCP quota.** With the appended workload and infra SCP statements plus the new data-residency SCP, the quota might get tight. Attach at account level if OU-level attachment exceeds the quota.
5. **Review the `ArnNotLike` principal exemptions in `NET2` and `OTHS`.** They key off `${ACCELERATOR_PREFIX}` and `${MANAGEMENT_ACCOUNT_ACCESS_ROLE}` — make sure your deployment uses matching role names or automation will be locked out.

## Not covered

- **shared-vpc network-config edits.** Phase A + B apply identically to `hub-and-spoke` and `shared-vpc` because every edit lives in `global-config.yaml`, `security-config.yaml`, or `organization-config.yaml` — all three files are identical across the two network overlays. If a future uplift section touches `network-config.yaml`, split into a `replacements-for-tse-se-shared-vpc.yaml` sibling.
- **CI round-trip gate.** Add a job that reruns `lzaucreplgen` against the pinned UC tag and fails on unexpected mismatches once more churn starts landing.
- **Automation of the overlay step.** `apply.sh` already does this; a `release-package.js` compatible `postActions: addFile` list is a possible next step if upstream grows that capability.
- **Later UC tags.** Pin is `v1.4.1`. Rebase the configured dir and regenerate when a new UC tag lands.
