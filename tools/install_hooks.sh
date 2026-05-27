#!/bin/bash
# Installa i git hooks del progetto Favilla Blaze.
# Da eseguire dopo ogni clone: bash tools/install_hooks.sh

HOOKS_DIR="$(git rev-parse --show-toplevel)/.git/hooks"
TOOLS_DIR="$(git rev-parse --show-toplevel)/tools/hooks"

mkdir -p "$TOOLS_DIR"

echo "Installando hooks in $HOOKS_DIR..."
for hook in "$TOOLS_DIR"/*; do
  [ -f "$hook" ] || continue
  name=$(basename "$hook")
  cp "$hook" "$HOOKS_DIR/$name"
  chmod +x "$HOOKS_DIR/$name"
  echo "  ✅ $name installato"
done
echo "Done."
