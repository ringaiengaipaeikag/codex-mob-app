---
name: trustev-fingerprint
description: Use for authorized analysis of Trustev/TransUnion/ThreatMetrix-style device fingerprinting evidence in sanitized browser captures or owned integrations: script origins, SDK version hints, device-session key names, endpoint sequence, runtime API categories, and official documentation lookup. Do not fabricate, harvest, replay, or bypass device fingerprint sessions.
---

# Trustev Fingerprint Analysis

Use this skill for observations about Trustev, TransUnion Device Verification,
or ThreatMetrix-style device fingerprinting flows.

## Safety Boundary

Allowed:

- identify provider scripts and endpoints,
- document device-session field names without values,
- compare browser-generated versus server-side integration evidence on owned
  systems,
- check official docs and project code for expected integration behavior,
- record risks when a project omits browser-side device signals.

Not allowed:

- generating fake device fingerprints,
- harvesting session IDs,
- replaying device-session values,
- bypassing fraud checks,
- copying project-specific public keys or secrets into global docs.

## Evidence Checklist

Look for sanitized evidence:

- provider names: Trustev, TransUnion, ThreatMetrix, TMX,
- endpoint or script origins related to device verification,
- field/key names such as `fpeSessionId`, `tmxSessionId`, `sessionId` without
  values,
- runtime categories: canvas, WebGL, navigator, fonts, storage, crypto,
  network,
- coverage or script-analysis matches around device fingerprint scripts.

## Output

Write a short integration note:

- provider evidence,
- project-owned integration points,
- key names observed with values redacted,
- missing or uncertain browser-signal evidence,
- safe next step: official docs lookup, owned test capture, or code review.

