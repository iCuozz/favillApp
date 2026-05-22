#!/usr/bin/env bash
# check_assets.sh — verifica che tutti gli asset referenziati nei JSON esistano

PROJECT_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
JSON_DIR="$PROJECT_ROOT/assets/data"

if [ ! -d "$JSON_DIR" ]; then
  echo "❌ Cartella non trovata: $JSON_DIR"
  exit 1
fi

echo "🔍 Scansione asset in: $JSON_DIR"
echo "📁 Project root: $PROJECT_ROOT"
echo ""

MISSING=0
FOUND=0

# Cerca tutti i path "assets/..." in tutti i JSON
while IFS= read -r line; do
  # Estrai il path dell'asset dalla riga (formato: "background": "assets/...")
  asset_path=$(echo "$line" | grep -oE '"assets/[^"]+\.(webp|png|jpg|jpeg)"' | tr -d '"')
  json_file=$(echo "$line" | cut -d: -f1)
  
  if [ -n "$asset_path" ]; then
    full_path="$PROJECT_ROOT/$asset_path"
    if [ -f "$full_path" ]; then
      echo "  ✅ $asset_path"
      ((FOUND++))
    else
      echo "  ❌ MANCANTE: $asset_path"
      echo "     └─ referenziato in: ${json_file#$PROJECT_ROOT/}"
      ((MISSING++))
    fi
  fi
done < <(grep -rn '"background"\|"thumbnail"' "$JSON_DIR" --include="*.json")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Trovati:  $FOUND"
echo "❌ Mancanti: $MISSING"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$MISSING" -gt 0 ]; then
  echo ""
  echo "⚠️  Ci sono $MISSING asset mancanti."
  echo "   Opzioni:"
  echo "   1. Crea le immagini WebP nei path indicati"
  echo "   2. Aggiorna i path nel JSON per usare un placeholder esistente"
  echo "      (es. assets/episodes/prologo/page_4.webp)"
  exit 1
else
  echo ""
  echo "🎉 Tutti gli asset sono presenti. Pronto per flutter run."
  exit 0
fi
