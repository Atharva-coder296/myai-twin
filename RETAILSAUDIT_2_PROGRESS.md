# RetailSAudit 2.0 source upgrade (development snapshot)

## Implemented in source
- Keep existing RetailSAudit brand, logo asset, original screens and Codemagic workflow.
- Long-press location label to confirm deletion (cannot remove last location).
- Long-press barcode row for quantity +/- and removal with confirmation.
- Length mismatch: No rejects and attempts three system alert sounds; Yes accepts only that scan; Modify changes future expected length and does not accept current scan. Hardware sound behavior requires testing.
- Nonempty alphanumeric barcode input permitted; expected length still checked.
- Admin generates a 16-character password, shows credentials once after account creation, and can locally suspend employee accounts by long press.
- Version changed to 0.2.0+2.

## NOT implemented / not verified
- No cloud authentication, shared account directory, live login/session list, or cross-device suspension. Current accounts remain local on each device. Multi-device use with the same credentials will NOT work yet.
- No native Zebra/Honeywell/CipherLab integration or camera barcode scanning. Keyboard-wedge scanning is still dependent on device settings and must be tested.
- Flutter SDK is not installed in this environment: this source package has NOT been compiled or tested. Existing automated tests may need updating for new alphanumeric acceptance rules.
- This is one shared Flutter codebase with admin/employee roles, not two separately packaged APKs.

## Build
Use existing root codemagic.yaml workflow, which generates Android files. Before deploying commercially, implement backend-enforced authentication and session revocation and test scanner hardware.
