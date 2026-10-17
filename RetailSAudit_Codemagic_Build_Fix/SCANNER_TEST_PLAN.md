# Physical scanner QA — run on Android AND iPhone

Set **EAN length = 13** during New Audit. Tap Scanner Ready once; the scanner
should be in Bluetooth/USB HID keyboard mode and ideally send Enter suffix.

| Test | What you scan / choose | Expected |
|---|---|---|
| Normal | `8901808000068` | Count 1 appears in current rack |
| Duplicate | `8901808000068` again | Same rack quantity becomes 2 |
| Numeric QR | QR containing `8901808000068` | Same product quantity becomes 3 |
| Short | `123456789012` | Warning opens immediately; 3 system alerts if enabled |
| Yes | Yes — This Product Only | Adds one 12-digit product, EAN remains 13 |
| Repeat short | Scan `123456789012` again | Warning opens again |
| No | No — Reject | No count added |
| Modify | Modify length to 12 | Current product rejected; next 12-digit scan accepted |
| QR URL | QR containing `https://example.com` | Rejected; no count added |
| Focus | Scan multiple times | Input clears; scans don't pile up in text box |
| Rack switch | Scan same code in Rack 2 | Separate rack quantity; report preserves rack |
| Draft persistence | Close/restart app mid-audit | Resume draft and last active rack |
| Audit report | End & save | Saved audit appears in View Report |
| Variance | Upload SOH, generate | Physical totals aggregated for variance only |

Also test device Bluetooth disconnect/reconnect, 50 quick scans, a QR code with
leading zeros, no Enter suffix, and the device's silent mode. Results are not
claimed tested until actually executed on your scanner and both phone platforms.
