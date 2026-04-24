#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKETPLACE_JSON="$PLUGIN_DIR/.claude-plugin/marketplace.json"
MARKETPLACE_NAME="$(python3 -c "import json; print(json.load(open('$MARKETPLACE_JSON'))['name'])")"
PLUGIN_NAMES="$(python3 -c "import json; [print(p['name']) for p in json.load(open('$MARKETPLACE_JSON'))['plugins']]")"

usage() {
    echo "Usage: $(basename "$0") [install|uninstall|reload]"
    exit 1
}

case "${1:-}" in
    install)
        echo "Adding marketplace '$MARKETPLACE_NAME' from $PLUGIN_DIR ..."
        claude plugin marketplace add "$PLUGIN_DIR"
        while IFS= read -r name; do
            echo "Installing plugin '$name' ..."
            claude plugin install "$name@$MARKETPLACE_NAME"
        done <<< "$PLUGIN_NAMES"
        echo "Done. Restart Claude Code to apply."
        ;;
    uninstall)
        while IFS= read -r name; do
            echo "Uninstalling plugin '$name' ..."
            claude plugin uninstall "$name"
        done <<< "$PLUGIN_NAMES"
        echo "Removing marketplace '$MARKETPLACE_NAME' ..."
        claude plugin marketplace remove "$MARKETPLACE_NAME"
        echo "Done. Restart Claude Code to apply."
        ;;
    reload)
        echo "Reloading plugins ..."
        while IFS= read -r name; do
            claude plugin uninstall "$name"
        done <<< "$PLUGIN_NAMES"
        claude plugin marketplace remove "$MARKETPLACE_NAME"
        claude plugin marketplace add "$PLUGIN_DIR"
        while IFS= read -r name; do
            echo "Installing plugin '$name' ..."
            claude plugin install "$name@$MARKETPLACE_NAME"
        done <<< "$PLUGIN_NAMES"
        echo "Done. Restart Claude Code to apply."
        ;;
    *)
        usage
        ;;
esac
