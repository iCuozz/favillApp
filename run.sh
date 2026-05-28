#!/usr/bin/env bash
# Avvia l'app con i dart-defines giusti (AI_BASE_URL ecc).
# Uso: ./run.sh                     -> debug (simulatore/device rilevato)
#      ./run.sh --iphone            -> iPhone fisico collegato (cavo o Wi-Fi)
#      ./run.sh --release           -> release mode
#      ./run.sh -d <device-id>      -> device specifico

IPHONE_FLAG=false
ARGS=()

for arg in "$@"; do
  if [[ "$arg" == "--iphone" ]]; then
    IPHONE_FLAG=true
  else
    ARGS+=("$arg")
  fi
done

if $IPHONE_FLAG; then
  DEVICE_ID=$(flutter devices 2>/dev/null | grep -i "ios" | grep -v "simulator" | awk -F'•' '{print $2}' | tr -d ' ' | head -1)
  if [[ -z "$DEVICE_ID" ]]; then
    echo "❌ Nessun iPhone fisico trovato. Controlla la connessione (cavo o Wi-Fi)." >&2
    exit 1
  fi
  echo "📱 Avvio su iPhone: $DEVICE_ID"
  exec flutter run -d "$DEVICE_ID" --dart-define-from-file=dart_defines.json "${ARGS[@]}"
else
  exec flutter run --dart-define-from-file=dart_defines.json "${ARGS[@]}"
fi
