#!/usr/bin/env bash
# Vendor pokemon-colorscripts assets (MIT) into this mod folder.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
TMP="${TMPDIR:-/tmp}/pokemon-colorscripts-vendor"

rm -rf "$TMP"
git clone --depth 1 https://gitlab.com/phoneybadger/pokemon-colorscripts.git "$TMP"

mkdir -p "$ROOT/small/regular"
cp "$TMP/pokemon.json" "$ROOT/"
if [ -f "$TMP/LICENSE.txt" ]; then
  cp "$TMP/LICENSE.txt" "$ROOT/LICENSE"
elif [ -f "$TMP/LICENSE" ]; then
  cp "$TMP/LICENSE" "$ROOT/"
fi
cp -r "$TMP/colorscripts/small/regular/"* "$ROOT/small/regular/"

cat > "$ROOT/ATTRIBUTION.md" << 'EOF'
# Pokemon Colorscripts Attribution

Sprite data vendored from [pokemon-colorscripts](https://gitlab.com/phoneybadger/pokemon-colorscripts) (MIT License).

- Author: Phoney badger (https://gitlab.com/phoneybadger)
- Box art sprites from [PokéSprite](https://msikma.github.io/pokesprite/)
- Pokémon designs, names, and branding are trademarks of [The Pokémon Company](https://pokemon.com)

Only `small/regular` sprites are bundled in this user mod.
EOF

COUNT=$(find "$ROOT/small/regular" -type f | wc -l)
echo "Vendored $COUNT colorscript files to $ROOT"
rm -rf "$TMP"
