#!/usr/bin/env bash
set -euo pipefail

PROFILE="/sys/firmware/acpi/platform_profile"
CHOICES="/sys/firmware/acpi/platform_profile_choices"

if [[ ! -w "$PROFILE" ]]; then
    echo "Error: Lenovo platform profile interface is unavailable or not writable." >&2
    exit 1
fi

if [[ -r "$CHOICES" ]] && ! grep -qw -- "balanced" "$CHOICES"; then
    echo "Error: this system does not expose the 'balanced' platform profile." >&2
    exit 1
fi

echo balanced | sudo tee "$PROFILE" >/dev/null

current=$(cat "$PROFILE")
echo "Lenovo platform profile: $current"
