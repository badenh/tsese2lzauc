# tsese2lzauc

A replacements file that uplifts an [LZA Universal Configuration (UC)](https://github.com/aws/lza-universal-configuration) deployment toward the [Trusted Secure Enclaves - Sensitive Edition (TSE-SE)](https://github.com/aws-samples/landing-zone-accelerator-on-aws-for-tse-se) sensitive-tier posture.

As of Nov 2026, TSE-SE standalone is in maintenance mode. The recommended path is **deploy LZA UC, then apply TSE-SE-aligned patches**. See TSE-SE's own [deliver-on-uc.md](https://github.com/aws-samples/landing-zone-accelerator-on-aws-for-tse-se/blob/main/deliver-on-uc.md) and [uplift guide](https://github.com/aws-samples/landing-zone-accelerator-on-aws-for-tse-se/tree/main/uplift-to-tse-se).

This repo encodes that uplift as a UC `replacements` file in the same shape as the upstream [`replacements/`](https://github.com/aws/lza-universal-configuration/tree/main/replacements) reference files (standard / GovCloud / EU-sovereign).

## Status

**Phase A — in-place functional toggles.** Round-trip verified against `lza-universal-configuration@v1.4.1` on the `hub-and-spoke` network module (0 unexpected byte mismatches). Re-apply also verified clean against the `shared-vpc` merged tree.

**Phase B part 1 — large YAML inserts (this release).** Three further uplift sections encoded as pattern/replacement entries: per-account CMKs (`s3`/`lambda`/`sqs`/`logging.cloudwatchLogs.encryption`), `ssmInventory`, `logging.cloudwatchLogs.subscription` (`type: ACCOUNT`), and the full CIS monitoring `metricSets` + `alarmSets` block with `logGroupName` repointed to `aws-controltower/CloudTrailLogs`. Round-trip 0 unexpected byte mismatches.

**Phase B part 2 — SCP statement appends, data-residency SCP, auto-remediation (this release).** Five further uplift sections encoded. Workload SCP (`lza-core-workloads-guardrails-1.json`) extended with eight TSE-SE statements (`PMP`, `EBS1`, `EBS2`, `EFS`, `RDS`, `AUR`, `OTHS`, `NET2`). Infra SCP (`lza-infrastructure-guardrails-1.json`) extended with `NFW` statement. New `service-control-policies/data-residency.json` carrying `GBL1` + `GBL2` plus a reference in `organization-config.yaml`. Three auto-remediation Config rules (`S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED`, `S3_BUCKET_SSL_REQUESTS_ONLY`, `EC2_IMDSV2_CHECK`) appended to `security-config.yaml` with their SSM-automation registrations. Round-trip 0 unexpected byte mismatches. Sidecar files (new SCP JSON, SSM remediation documents, remediation-role JSONs) ship under [`overlay/`](overlay/) because `config-replacer.js` only patches existing files; `apply.sh` copies the overlay into the merged tree automatically.

## Pin

- Template: `aws/lza-universal-configuration@v1.4.1`
- Network: works against **either** `hub-and-spoke` or `shared-vpc`. Phase A touches only `global-config.yaml` and `security-config.yaml`; both files are identical across the two network overlays, so the same replacements file applies cleanly to either merged tree. If Phase B introduces `network-config.yaml` edits, the file will split.

## What's in `replacements-for-tse-se.yaml` today

| # | Uplift section | Change | File |
|---|---|---|---|
| 1 | Longer retention | `cloudwatchLogRetentionInDays: 365 → 731` | `global-config.yaml` |
| 2 | Defence-in-depth session logging | `sessionManager.sendToS3: false → true` + 730-day lifecycle | `global-config.yaml` |
| 3 | Finer cost granularity | CUR `timeUnit: MONTHLY → HOURLY` + `RESOURCES` + `ATHENA` | `global-config.yaml` |
| 4 | SCP-tamper alerting | `scpRevertChangesConfig.snsTopicName: SecurityHigh` | `security-config.yaml` |
| 5 | Sensitive-data discovery | `macie.publishSensitiveDataFindings: true` | `security-config.yaml` |
| 6 | Near-real-time threat detection | `guardduty.exportFrequency: SIX_HOURS → FIFTEEN_MINUTES` | `security-config.yaml` |
| 7 | Stricter password lockout | `iamPasswordPolicy.hardExpiry: true` | `security-config.yaml` |
| 8 | Per-account CMKs | `s3`, `lambda`, `sqs`, `logging.cloudwatchLogs.encryption` blocks with `useCMK`/`createCMK: true` and standard-OU `deploymentTargets` | `global-config.yaml` |
| 9 | Org-wide SSM inventory | `ssmInventory.enable: true` with standard-OU `deploymentTargets` | `global-config.yaml` |
| 10 | Account-level log capture | `logging.cloudwatchLogs.subscription.type: ACCOUNT` | `global-config.yaml` |
| 11 | CIS monitoring alarms | Full `cloudWatch.metricSets` + `alarmSets` block (CIS 1.1/3.1/3.2/3.4-3.7/3.9/3.11-3.14 + SSO/IAM unapproved-IP + unencrypted-filesystem + authorization-failure), `logGroupName` repointed to `aws-controltower/CloudTrailLogs` | `security-config.yaml` |
| 12 | Additional SCP hardening | Append `PMP`, `EBS1`, `EBS2`, `EFS`, `RDS`, `AUR`, `OTHS` statements | `service-control-policies/lza-core-workloads-guardrails-1.json` |
| 13 | Network/identity control-plane lockdown | Append `NET2` statement | `service-control-policies/lza-core-workloads-guardrails-1.json` |
| 14 | Network Firewall tamper protection | Append `NFW` statement | `service-control-policies/lza-infrastructure-guardrails-1.json` |
| 15 | In-configuration data-residency | New `data-residency.json` (GBL1 + GBL2) in `overlay/`; SCP reference entry | `organization-config.yaml` |
| 16 | Active auto-remediation | Three Config rules (S3 SSE-KMS, S3 HTTPS, IMDSv2) with `remediation` blocks + SSM-automation registrations; SSM documents and remediation-role JSONs in `overlay/` | `security-config.yaml` |

Items 8-16 ship opinionated defaults — standard LZA UC OU names (`Security`, `Infrastructure`, `Workloads`, `Workloads/{Dev,Test,Prod,Sandbox}`, `Management`). Review and tune `deploymentTargets` and `excludedRegions` before applying. See [TODO.md](TODO.md) for anything that remains.

## Apply

```bash
# 1. Clone UC at the pinned ref and merge the network module
git clone --branch v1.4.1 https://github.com/aws/lza-universal-configuration.git
cd lza-universal-configuration
mkdir -p /tmp/lza-tse-se
cp -r modules/base/default/. /tmp/lza-tse-se/
cp -r modules/network/hub-and-spoke/. /tmp/lza-tse-se/

# 2. Apply replacements + overlay in one step
/path/to/tsese2lzauc/apply.sh /tmp/lza-tse-se /path/to/lza-universal-configuration

# Or do the two steps manually:
#   node scripts/config-replacer.js -w /tmp/lza-tse-se \
#     /path/to/tsese2lzauc/replacements-for-tse-se.yaml
#   cp -R /path/to/tsese2lzauc/overlay/. /tmp/lza-tse-se/

# 3. Supply admin values via replacements-config.yaml globalReplacements
#    or your env-driven build scripts: HomeRegion, EnabledRegions, AcceleratorPrefix,
#    SecurityHigh/Medium/Low, BudgetsEmail.
```

## How this was generated

[`lzaucreplgen`](https://github.com/badenh/lzaucreplgen) diffs a configured LZA UC instance against the upstream template and emits a replacements file, then round-trip-validates by applying the file back and byte-comparing. See the walkthrough in [`work/`](./work/) if reproducing.

## Scope boundaries

- **In scope:** functional and structural edits that encode as `pattern`/`replacement` or `postActions` entries.
- **Out of scope:** admin values (home region, OU membership, emails, account IDs) — those stay in `replacements-config.yaml` globalReplacements or env-driven build scripts.
- **User judgement required:** excluded-region strategy, exact OU targets for added SCPs, whether to attach SCPs at OU or account level given Control Tower quota, which subset of TSE-SE controls your compliance regime demands. See TSE-SE's [Deciding what to apply](https://github.com/aws-samples/landing-zone-accelerator-on-aws-for-tse-se/tree/main/uplift-to-tse-se#deciding-what-to-apply).

## License

Apache-2.0.
