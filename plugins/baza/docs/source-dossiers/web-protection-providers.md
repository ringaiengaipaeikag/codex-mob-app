# Web Protection Provider Source Dossier

Use this dossier before interpreting CAPTCHA, challenge, or bot-protection
signals in BAZA web capture artifacts.

This dossier is for terminology and lifecycle understanding. It is not a bypass
guide.

## Official Sources

- Google reCAPTCHA documentation:
  https://developers.google.com/recaptcha/docs/v3
- hCaptcha documentation:
  https://docs.hcaptcha.com/
- Cloudflare Turnstile documentation:
  https://developers.cloudflare.com/turnstile/
- Cloudflare challenge pages:
  https://developers.cloudflare.com/cloudflare-challenges/challenge-types/challenge-pages/
- Arkose Labs developer documentation:
  https://developer.arkoselabs.com/
- DataDome documentation:
  https://docs.datadome.co/
- Akamai Cloud Security bot documentation:
  https://techdocs.akamai.com/cloud-security/docs/about-bots
  This site may return HTTP 403 to simple scripted checks while remaining a
  public official browser-accessible source.
- AWS WAF CAPTCHA and Challenge:
  https://docs.aws.amazon.com/waf/latest/developerguide/waf-captcha-and-challenge.html
- OWASP Automated Threats to Web Applications:
  https://owasp.org/www-project-automated-threats-to-web-applications/
- Chrome DevTools Protocol Target domain:
  https://chromedevtools.github.io/devtools-protocol/tot/Target/

## BAZA Interpretation Rules

- Provider detection is pattern-based until confirmed by multiple signals.
- Iframe and script origins are stronger evidence than variable names alone.
- Token-like key names are evidence of state flow, not permission to extract or
  replay token values.
- CAPTCHA payloads, cookies, browser fingerprints, screenshots, HAR bodies, and
  response bodies are raw sensitive artifacts.
- Reports should separate direct observations from inference.

## BAZA Skills

Use these guarded skills only after evidence suggests the provider or flow:

- `cloudflare-analysis` for Cloudflare challenge and Turnstile observations.
- `datadome-analysis` for DataDome script, collector, cookie-key, and
  interstitial observations.
- `trustev-fingerprint` for Trustev/ThreatMetrix-style device fingerprint
  integration observations.
- `akamai-bypass` as an Akamai observation guard, not a bypass workflow.
- `recaptcha-solve` as an owned/test reCAPTCHA integration guard, not a solver.
- `tps-browser-harvester` as a third-party harvesting guard, not a harvesting
  workflow.
- `bot-detection-analysis` to coordinate cross-provider evidence safely.

## Provider Clues

Use these only as categorization hints:

- reCAPTCHA: `recaptcha`, `grecaptcha`, `g-recaptcha`, Google recaptcha origins.
- hCaptcha: `hcaptcha`, `h-captcha`, hCaptcha script or API origins.
- Turnstile: `turnstile`, `cf-turnstile`, Cloudflare Turnstile origins.
- Cloudflare challenges: `cf_clearance`, `cf_chl`, `/cdn-cgi/challenge-platform`.
- Arkose: `arkose`, `funcaptcha`, `fc-token`, Arkose Labs origins.
- DataDome: `datadome`, `dd_cookie`, DataDome origins.
- Akamai: `_abck`, `bm_sz`, `bm_sv`, `sensor_data`, Akamai references.
- PerimeterX/HUMAN: `_px`, `px-captcha`, `pxvid`, PerimeterX references.
- AWS WAF: `awswaf`, `awswaf-token`.
- Kasada: `kasada`, `x-kpsdk`, `kpsdk`.
- GeeTest: `geetest`, `gt-captcha`.
- FingerprintJS: `fingerprintjs`, `fpjs`, `visitorId`.

## Review Questions

1. Was the target and action authorized?
2. Is the provider signal direct or inferred?
3. Did a worker, iframe, generated script, or service worker participate?
4. Which endpoint sequence was observed?
5. Which storage or cookie key names changed?
6. Did a second run confirm the same sequence?
7. Is the report free of raw tokens, cookies, CAPTCHA payloads, screenshots,
   HAR bodies, request bodies, response bodies, and browser fingerprints?
