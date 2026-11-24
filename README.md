# tsese2lzauc

A replacements file that uplifts an [LZA Universal Configuration (UC)](https://github.com/aws/lza-universal-configuration) deployment toward the [Trusted Secure Enclaves - Sensitive Edition (TSE-SE)](https://github.com/aws-samples/landing-zone-accelerator-on-aws-for-tse-se) sensitive-tier posture.

As of Nov 2026, TSE-SE standalone is in maintenance mode. The recommended path is **deploy LZA UC, then apply TSE-SE-aligned patches**. See TSE-SE's own [deliver-on-uc.md](https://github.com/aws-samples/landing-zone-accelerator-on-aws-for-tse-se/blob/main/deliver-on-uc.md) and [uplift guide](https://github.com/aws-samples/landing-zone-accelerator-on-aws-for-tse-se/tree/main/uplift-to-tse-se).

This repo encodes that uplift as a UC `replacements` file in the same shape as the upstream [`replacements/`](https://github.com/aws/lza-universal-configuration/tree/main/replacements) reference files (standard / GovCloud / EU-sovereign).

## Status

**Phase A — in-place functional toggles (this release).** Round-trip verified against `lza-universal-configuration@v1.4.1` on the `hub-and-spoke` network module (0 unexpected byte mismatches). Re-apply also verified clean against the `shared-vpc` merged tree.

**Phase B — block inserts and new-file assets (pending).** Several uplift sections require inserting large blocks (CIS metric and alarm sets, S3/Lambda/SQS/CloudWatch CMK blocks) or shipping new files (data-residency SCP, custom SSM remediation documents, custom-config-rule roles). These are captured in [TODO.md](TODO.md).

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

See [TODO.md](TODO.md) for Phase B coverage.

## Apply

```bash
# 1. Clone UC at the pinned ref and merge the network module
git clone --branch v1.4.1 https://github.com/aws/lza-universal-configuration.git
cd lza-universal-configuration
mkdir -p /tmp/lza-tse-se
cp -r modules/base/default/. /tmp/lza-tse-se/
cp -r modules/network/hub-and-spoke/. /tmp/lza-tse-se/

# 2. Apply this replacements file
node scripts/config-replacer.js -w /tmp/lza-tse-se \
  /path/to/tsese2lzauc/replacements-for-tse-se.yaml

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
