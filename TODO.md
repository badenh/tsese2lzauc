# Phase B part 2 — remaining TSE-SE uplift coverage

Phase A (seven simple toggles) and Phase B part 1 (per-account CMKs, `ssmInventory`, account-level log subscription, CIS monitoring `metricSets`/`alarmSets`) are encoded in `replacements-for-tse-se.yaml`. The remaining uplift sections below either ship new sidecar files (SCP JSON, SSM documents, custom-config-rule IAM roles) or require merging TSE-SE SCP statements into existing UC SCP JSON files. These need deliberate decisions about OU targets and compliance scope before encoding.

Each entry links to the corresponding section in TSE-SE's [uplift guide](https://github.com/aws-samples/landing-zone-accelerator-on-aws-for-tse-se/blob/main/uplift-to-tse-se/README.md).

## 1. Per-account customer-managed KMS keys (CMKs) — DONE in part 1
- Encoded as three new top-level blocks (`s3`, `lambda`, `sqs`) inserted before `# AWS Cost and Usage Reports`, plus `logging.cloudwatchLogs.encryption` nested in the existing `logging` block. Opinionated OU defaults; `excludedRegions` **not** set — add per your enabled-region strategy.

## 2. In-configuration data-residency enforcement
- **Uplift section:** [In-configuration data-residency enforcement](https://github.com/aws-samples/landing-zone-accelerator-on-aws-for-tse-se/blob/main/uplift-to-tse-se/README.md#in-configuration-data-residency-enforcement)
- **Target files:** `organization-config.yaml`, `service-control-policies/data-residency.json` (new).
- **Shape:** append `serviceControlPolicies[]` entry in `organization-config.yaml`; ship new SCP JSON containing `GBL1` and `GBL2` statements copied from TSE-SE `LZA-Guardrails-Sensitive.json`.
- **Delivery:** replacements-file pattern/replacement for the YAML append + overlay file for the JSON. The upstream `config-replacer.js` does not `addFile`; the overlay ships under `overlay/` with a documented `cp` step or via `release-package.js` compatible `postActions` (which the upstream replacer doesn't honour).

## 3. Near-real-time sensitive-data and threat findings
- Phase A applied the two 15-minute frequencies and the `publishSensitiveDataFindings: true` flag.
- Nothing left for this section unless the user also wants `s3Protection.excludeRegions` tightened.

## 4. CIS monitoring alarms — DONE in part 1
- Full `metricSets` + `alarmSets` block from TSE-SE `security-config.yaml` (lines 525-827) inlined via a single pattern/replacement on `cloudWatch:\n  metricSets: []\n  alarmSets: []`. `logGroupName` and `{{CloudTrailLogGroup}}` references rewritten to `aws-controltower/CloudTrailLogs`. Two unapproved-IP filter patterns still carry the TSE-SE example `10.10.10.*` / `REPLACE_WITH_ON_PREM_IP` placeholders — **replace with your on-prem CIDR before applying**.

## 5. Additional SCP hardening (EBS/EFS/RDS/AUR/PMP/OTHS)
- **Uplift section:** [Additional SCP hardening](https://github.com/aws-samples/landing-zone-accelerator-on-aws-for-tse-se/blob/main/uplift-to-tse-se/README.md#additional-scp-hardening)
- **Target files:** `service-control-policies/lza-core-workloads-guardrails-1.json`.
- **Shape:** append statements copied from TSE-SE `LZA-Guardrails-Sensitive.json`.
- **Blockers:** UC's workload SCP JSON must be inspected to confirm `Statement` array shape and find a stable anchor for append. Statements preserve `{{ AcceleratorPrefix }}` + `${PARTITION}` tokens.

## 6. Network / identity control-plane lockdown (`NET2`)
- **Uplift section:** [Network and identity control-plane lockdown](https://github.com/aws-samples/landing-zone-accelerator-on-aws-for-tse-se/blob/main/uplift-to-tse-se/README.md#network-and-identity-control-plane-lockdown)
- Same shape as #5 — append to an existing UC workload / core SCP.
- **Critical:** `Condition.ArnNotLike` value must stay aligned with the deployment's `AcceleratorPrefix` or automation locks itself out.

## 7. Network Firewall tamper protection (`NFW`)
- **Uplift section:** [Network Firewall tamper protection](https://github.com/aws-samples/landing-zone-accelerator-on-aws-for-tse-se/blob/main/uplift-to-tse-se/README.md#network-firewall-tamper-protection)
- **Source:** TSE-SE `LZA-Guardrails-Part1.json`.
- Append to an Infrastructure/Network OU-targeted SCP in UC.

## 8. Active auto-remediation
- **Uplift section:** [Active auto-remediation](https://github.com/aws-samples/landing-zone-accelerator-on-aws-for-tse-se/blob/main/uplift-to-tse-se/README.md#active-auto-remediation)
- **Target files:** `security-config.yaml` (`awsConfig.ruleSets[].rules`) + new SSM documents + new IAM role JSONs.
- **Shape:** add three Config rules (`S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED`, `S3_BUCKET_SSL_REQUESTS_ONLY`, `EC2_IMDSV2_CHECK`) with `remediation` blocks; ship `ssm-documents/s3-encryption.yaml`, `ssm-documents/s3-enforce-https.yaml` and `custom-config-rules/{bucket-sse-enabled-remediation-role,bucket-enforce-https-remediation-role,imdsv2-remediation-role}.json` from TSE-SE source.
- **Delivery:** YAML rules via replacements file + overlay dir for new files.

## 9. Longer retention / finer granularity — DONE
- Phase A: `cloudwatchLogRetentionInDays`, CUR hourly+resources+Athena, session-manager S3, SCP-tamper SNS, `iamPasswordPolicy.hardExpiry`.
- Phase B part 1: `ssmInventory.enable: true` with standard-OU targets; `logging.cloudwatchLogs.subscription.type: ACCOUNT` with `overrideExisting: true`.

## 10. shared-vpc network variant
- Phase A: **same file works for both** (`global-config.yaml` + `security-config.yaml` are identical across network overlays). Re-apply verified clean on both merged trees.
- Phase B: if any item touches `network-config.yaml`, split into a sibling `replacements-for-tse-se-shared-vpc.yaml`.

## Delivery mechanics

`config-replacer.js` only applies pattern/replacement edits. It does not copy new files and ignores `postActions`. Three options for shipping the overlay files:

1. **Bundled overlay directory** (chosen). Ship `overlay/` alongside the YAML; document a `cp -r overlay/* <merged-config>/` step in `apply.sh`.
2. `release-package.js` compatible `postActions` that mirror the overlay structure (not applied by the plain replacer, but consistent with upstream tooling).
3. Fold everything into a bash script that drives both steps.

Current plan: option 1, with `apply.sh` as a thin wrapper.
