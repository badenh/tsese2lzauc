# Phase B — remaining TSE-SE uplift coverage

Phase A covers the simple in-place functional toggles. The following uplift sections involve either inserting large structured blocks into UC config files or shipping new sidecar files (SCP JSON, SSM documents, custom-config-rule IAM roles). These need deliberate decisions about OU targets and compliance scope before encoding.

Each entry links to the corresponding section in TSE-SE's [uplift guide](https://github.com/aws-samples/landing-zone-accelerator-on-aws-for-tse-se/blob/main/uplift-to-tse-se/README.md).

## 1. Per-account customer-managed KMS keys (CMKs)
- **Uplift section:** [Per-account customer-managed KMS keys (CMKs)](https://github.com/aws-samples/landing-zone-accelerator-on-aws-for-tse-se/blob/main/uplift-to-tse-se/README.md#per-account-customer-managed-kms-keys-cmks)
- **Target files:** `global-config.yaml`
- **Shape:** add 4 top-level blocks (`s3.encryption.createCMK`, `lambda.encryption.useCMK`, `sqs.encryption.useCMK`, `logging.cloudwatchLogs.encryption.useCMK`) with identical `deploymentTargets`.
- **Blockers:** UC baseline has no `s3:` / `lambda:` / `sqs:` top-level blocks in `global-config.yaml`, so these are pure inserts. User must supply `excludedRegions` matching their enabled-region strategy.
- **Approach:** insert as a single `pattern`/`replacement` hunk anchored on a stable preceding line (e.g. the `# SNS Configurations` header).

## 2. In-configuration data-residency enforcement
- **Uplift section:** [In-configuration data-residency enforcement](https://github.com/aws-samples/landing-zone-accelerator-on-aws-for-tse-se/blob/main/uplift-to-tse-se/README.md#in-configuration-data-residency-enforcement)
- **Target files:** `organization-config.yaml`, `service-control-policies/data-residency.json` (new).
- **Shape:** append `serviceControlPolicies[]` entry in `organization-config.yaml`; ship new SCP JSON containing `GBL1` and `GBL2` statements copied from TSE-SE `LZA-Guardrails-Sensitive.json`.
- **Delivery:** replacements-file pattern/replacement for the YAML append + overlay file for the JSON. The upstream `config-replacer.js` does not `addFile`; the overlay ships under `overlay/` with a documented `cp` step or via `release-package.js` compatible `postActions` (which the upstream replacer doesn't honour).

## 3. Near-real-time sensitive-data and threat findings
- Phase A applied the two 15-minute frequencies and the `publishSensitiveDataFindings: true` flag.
- Nothing left for this section unless the user also wants `s3Protection.excludeRegions` tightened.

## 4. CIS monitoring alarms
- **Uplift section:** [CIS monitoring alarms](https://github.com/aws-samples/landing-zone-accelerator-on-aws-for-tse-se/blob/main/uplift-to-tse-se/README.md#cis-monitoring-alarms)
- **Target files:** `security-config.yaml` (`cloudWatch.metricSets` and `cloudWatch.alarmSets`).
- **Shape:** replace the two empty arrays with the full block copied from TSE-SE `security-config.yaml`, repointing every `logGroupName` to `aws-controltower/CloudTrailLogs`.
- **Blockers:** TSE-SE source file has a long list (root usage, unauthorized API, console sign-in without MFA, IAM/CloudTrail/Config changes, NACL/gateway/route-table/VPC changes, CMK disable/delete, unapproved-source-IP, unencrypted-filesystem). Needs extraction from TSE-SE repo.
- **Approach:** large `pattern: metricSets: []` / `alarmSets: []` → full block replacement, two items.

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

## 9. Longer retention / finer granularity — remainder
- Phase A covered `cloudwatchLogRetentionInDays`, CUR hourly+resources+Athena, session-manager S3, SCP-tamper SNS, `iamPasswordPolicy.hardExpiry`.
- **Remaining:** `ssmInventory.enable: true` and `logging.cloudwatchLogs.subscription` with `type: ACCOUNT`. Both are top-level inserts.

## 10. shared-vpc network variant
- Phase A: **same file works for both** (`global-config.yaml` + `security-config.yaml` are identical across network overlays). Re-apply verified clean on both merged trees.
- Phase B: if any item touches `network-config.yaml`, split into a sibling `replacements-for-tse-se-shared-vpc.yaml`.

## Delivery mechanics

`config-replacer.js` only applies pattern/replacement edits. It does not copy new files and ignores `postActions`. Three options for shipping the overlay files:

1. **Bundled overlay directory** (chosen). Ship `overlay/` alongside the YAML; document a `cp -r overlay/* <merged-config>/` step in `apply.sh`.
2. `release-package.js` compatible `postActions` that mirror the overlay structure (not applied by the plain replacer, but consistent with upstream tooling).
3. Fold everything into a bash script that drives both steps.

Current plan: option 1, with `apply.sh` as a thin wrapper.
