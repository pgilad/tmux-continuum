#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION="${1:?Usage: setup.sh enable|disable}"

case "$(uname -s)" in
    Darwin) "$CURRENT_DIR/launchd.sh" "$ACTION" ;;
    Linux)  "$CURRENT_DIR/systemd.sh" "$ACTION" ;;
    *)      echo "Unsupported platform: $(uname -s)" >&2; exit 1 ;;
esac
