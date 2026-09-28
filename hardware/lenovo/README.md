# Lenovo hardware helpers

## set-balanced.sh

Sets the Lenovo ACPI platform profile to `balanced`.

This is intentionally a small, manual helper. It does **not** change TLP configuration, disable TLP, modify firmware settings, or persist the profile across reboot.

Usage:

```bash
./set-balanced.sh
```

The script checks that the kernel exposes the platform-profile interface and that `balanced` is available before changing it.

For the Lenovo LOQ 15IRX9, the available profiles observed during setup were:

- `low-power`
- `balanced`
- `performance`
- `max-power`
- `custom`

Use the script when you want to return to balanced mode manually.
