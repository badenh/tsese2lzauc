# tsese2lzauc

A replacements file that uplifts an [LZA Universal Configuration (UC)](https://github.com/aws/lza-universal-configuration) deployment toward the [Trusted Secure Enclaves - Sensitive Edition (TSE-SE)](https://github.com/aws-samples/landing-zone-accelerator-on-aws-for-tse-se) sensitive-tier posture. For background on the TSE-SE architecture and its intended compliance outcomes, see the AWS Solutions page for [Trusted Secure Enclaves on AWS](https://docs.aws.amazon.com/solutions/trusted-secure-enclaves-on-aws/).

As of November 2026, and according to the [TSE-SE GitHub repository](https://github.com/aws-samples/landing-zone-accelerator-on-aws-for-tse-se#important-how-tse-se-is-delivered-is-changing), TSE-SE standalone is in maintenance mode. The recommended path is **deploy LZA UC, then apply TSE-SE-aligned patches**. See TSE-SE's own [deliver-on-uc.md](https://github.com/aws-samples/landing-zone-accelerator-on-aws-for-tse-se/blob/main/deliver-on-uc.md) and [uplift guide](https://github.com/aws-samples/landing-zone-accelerator-on-aws-for-tse-se/tree/main/uplift-to-tse-se).

This repo encodes that uplift as a UC `replacements` file in the same shape as the upstream [`replacements/`](https://github.com/aws/lza-universal-configuration/tree/main/replacements) reference files (standard / GovCloud / EU-sovereign).

## Authorship

The TSE-SE to LZA UC port in this repository was created by **[Baden Hughes](https://www.linkedin.com/in/badenhughes/)**, an independent security tooling and compliance engineer. It is not an AWS product and is not endorsed by AWS, the AWS Landing Zone Accelerator team, or the TSE-SE project.

## Disclaimer and warranty

TSE-SE targets security and compliance postures that originate in the national-security and defence world — ITSG-33 / CCCS-Medium, IRAP, NIST SP 800-53, NATO RESTRICTED equivalents, and similar regimes. The stakes for getting a sensitive-tier landing zone wrong are high.

This repository is provided **as-is, without warranty of any kind**, express or implied. See the [License](#license) section below.

**Before deploying anything built from this repo** you must independently verify that:

- TSE-SE's sensitive-tier controls are the right ones for your workload and compliance regime.
- LZA UC's baseline (at the pinned ref — see [Pin](#pin)) still represents the posture you expect.
- The specific edits in this port — which encode a subset of the TSE-SE uplift guide with opinionated defaults — deliver the security outcomes you are actually seeking. Review the [coverage table](#whats-in-replacements-for-tse-seyaml-today), the [reviewer checklist in TODO.md](TODO.md#reviewer-checklist-before-deploying), and the [known rough edges](#known-rough-edges).
- Your accreditation evidence package covers the deployed configuration, not just the intended one.

Work with your AWS account team and your accreditation authority to map applied controls to your framework. Nothing in this repo substitutes for that work.

## Contents

- [Authorship](#authorship)
- [Disclaimer and warranty](#disclaimer-and-warranty)
- [Pin](#pin)
- [What's in `replacements-for-tse-se.yaml` today](#whats-in-replacements-for-tse-seyaml-today)
- [Apply](#apply)
- [How this was generated](#how-this-was-generated)
- [Known rough edges](#known-rough-edges)
- [Scope boundaries](#scope-boundaries)
- [Help and contributing](#help-and-contributing)
- [Credits and attribution](#credits-and-attribution)
- [License](#license)

## Pin

- Template: `aws/lza-universal-configuration@v1.4.1`
- Network: works against **either** `hub-and-spoke` or `shared-vpc`. Every edit lands in `global-config.yaml`, `security-config.yaml`, `organization-config.yaml`, or an SCP JSON — all identical across the two network overlays, so the same replacements file + overlay applies cleanly to either merged tree. If a future uplift section touches `network-config.yaml`, the file will split.

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
# 1. Clone UC at the pinned ref, install its script deps, and merge the network module
git clone --branch v1.4.1 https://github.com/aws/lza-universal-configuration.git
cd lza-universal-configuration
npm install                     # config-replacer.js needs js-yaml
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

[`lzaucreplgen`](https://github.com/badenh/lzaucreplgen) diffs a configured LZA UC instance against the upstream template and emits a replacements file, then round-trip-validates by applying the file back and byte-comparing.

The coverage grew in three phases, each round-trip-validated against `aws/lza-universal-configuration@v1.4.1` on the `hub-and-spoke` network module with 0 unexpected byte mismatches; re-apply was also verified clean against the `shared-vpc` merged tree.

**Phase A — in-place functional toggles.** Seven straightforward one-line or short-block flips (items 1-7 in the [coverage table](#whats-in-replacements-for-tse-seyaml-today)).

**Phase B part 1 — large YAML inserts.** Four further uplift sections encoded as pattern/replacement entries: per-account CMKs (`s3`/`lambda`/`sqs`/`logging.cloudwatchLogs.encryption`), `ssmInventory`, `logging.cloudwatchLogs.subscription` (`type: ACCOUNT`), and the full CIS monitoring `metricSets` + `alarmSets` block with `logGroupName` repointed to `aws-controltower/CloudTrailLogs`.

**Phase B part 2 — SCP statement appends, data-residency SCP, auto-remediation.** Five further uplift sections encoded. Workload SCP (`lza-core-workloads-guardrails-1.json`) extended with eight TSE-SE statements (`PMP`, `EBS1`, `EBS2`, `EFS`, `RDS`, `AUR`, `OTHS`, `NET2`). Infra SCP (`lza-infrastructure-guardrails-1.json`) extended with `NFW` statement. New `service-control-policies/data-residency.json` carrying `GBL1` + `GBL2` plus a reference in `organization-config.yaml`. Three auto-remediation Config rules (`S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED`, `S3_BUCKET_SSL_REQUESTS_ONLY`, `EC2_IMDSV2_CHECK`) appended to `security-config.yaml` with their SSM-automation registrations. Sidecar files (new SCP JSON, SSM remediation documents, remediation-role JSONs) ship under [`overlay/`](overlay/) because `config-replacer.js` only patches existing files; `apply.sh` copies the overlay into the merged tree automatically.

## Known rough edges

- **UC script dependencies.** Upstream `config-replacer.js` requires `js-yaml`. Run `npm install` inside your UC checkout before invoking `apply.sh` or calling the replacer directly.
- **`NET2` statement casing.** The TSE-SE `NET2` statement in `lza-core-workloads-guardrails-1.json` uses `aws:PrincipalArn` (mixed case) in its `Condition.ArnNotLike`, while every other UC statement in that file uses `aws:PrincipalARN` (all caps). Preserved verbatim from TSE-SE source. IAM evaluates condition-key names case-insensitively so behaviour is identical; flagged here so reviewers aren't surprised by the stylistic inconsistency.
- **`GBL1` reaches `Workloads/Sandbox` through inheritance.** The data-residency SCP targets `Infrastructure`, `Security`, and `Workloads`. Everything under `Workloads/*` (including `Workloads/Sandbox`) inherits it. If your Sandbox tier runs cross-region workloads that `GBL1` would block, retarget the SCP to the specific child OUs and skip Sandbox explicitly.
- **No CI round-trip gate yet.** Regenerating the replacements file against a new UC tag is a manual step. A CI job that reruns `lzaucreplgen` and fails on unexpected mismatches is a sensible next addition once more churn starts landing.

## Scope boundaries

- **In scope:** functional and structural edits that encode as `pattern`/`replacement` or `postActions` entries.
- **Out of scope:** admin values (home region, OU membership, emails, account IDs) — those stay in `replacements-config.yaml` globalReplacements or env-driven build scripts.
- **User judgement required:** excluded-region strategy, exact OU targets for added SCPs, whether to attach SCPs at OU or account level given Control Tower quota, which subset of TSE-SE controls your compliance regime demands. See TSE-SE's [Deciding what to apply](https://github.com/aws-samples/landing-zone-accelerator-on-aws-for-tse-se/tree/main/uplift-to-tse-se#deciding-what-to-apply).

## Help and contributing

Seen something wrong? Disagree with a choice? Have a question?

**[Raise an issue in this repo](https://github.com/badenh/tsese2lzauc/issues)** if it's about the TSE-SE to LZA UC port — the pattern/replacement entries, overlay files, opinionated defaults, documentation, or the round-trip validation. We'll take a look, and where the underlying concern actually lives in [TSE-SE](https://github.com/aws-samples/landing-zone-accelerator-on-aws-for-tse-se), the [AWS Landing Zone Accelerator on AWS](https://github.com/awslabs/landing-zone-accelerator-on-aws) solution, or [LZA Universal Configuration](https://github.com/aws/lza-universal-configuration), we'll pass it upstream to the right project.

## Credits and attribution

This port stands on three upstream projects. Each retains its own copyright, license, and authorship.

- **[AWS Landing Zone Accelerator on AWS](https://github.com/awslabs/landing-zone-accelerator-on-aws)** — the solution that LZA UC configures. © Amazon.com, Inc. or its affiliates. Licensed under the Apache License 2.0.
- **[LZA Universal Configuration (LZA UC)](https://github.com/aws/lza-universal-configuration)** — the template this port patches. © Amazon.com, Inc. or its affiliates. Licensed under the Apache License 2.0. The pattern/replacement entries in `replacements-for-tse-se.yaml` are applied by LZA UC's `scripts/config-replacer.js`.
- **[Landing Zone Accelerator on AWS for Trusted Secure Enclaves - Sensitive Edition (TSE-SE)](https://github.com/aws-samples/landing-zone-accelerator-on-aws-for-tse-se)** — the source of the sensitive-tier controls, SCP statements, SSM remediation documents, and CIS monitoring filters and alarms copied into this port. © Amazon.com, Inc. or its affiliates. Licensed under the MIT No Attribution license. SCP statements (`PMP`, `EBS1`, `EBS2`, `EFS`, `RDS`, `AUR`, `OTHS`, `NET2`, `NFW`, `GBL1`, `GBL2`), SSM documents (`s3-encryption.yaml`, `s3-enforce-https.yaml`), and remediation-role JSONs are copied verbatim from the TSE-SE repository. The matching AWS Solutions page is [Trusted Secure Enclaves on AWS](https://docs.aws.amazon.com/solutions/trusted-secure-enclaves-on-aws/).
- **[lzaucreplgen](https://github.com/badenh/lzaucreplgen)** — the tool used to diff the configured TSE-SE-on-UC instance against the upstream template and emit the replacements file with round-trip validation. © 2026 Baden Hughes. Licensed under the Apache License 2.0.

The pattern/replacement edits, overlay structure, opinionated defaults, and documentation in this repository were authored by Baden Hughes and are licensed under the Apache License 2.0.

## License

Apache-2.0. See [`LICENSE`](LICENSE) for the full text.
