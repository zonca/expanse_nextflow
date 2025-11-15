#!/usr/bin/env bash
set -euo pipefail

# Emit a random binary decision (0 or 1)
printf '%s\n' "$((RANDOM % 2))"
