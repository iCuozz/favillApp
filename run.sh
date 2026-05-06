#!/usr/bin/env bash
# Avvia l'app con i dart-defines giusti (AI_BASE_URL ecc).
# Uso: ./run.sh                     -> debug
#      ./run.sh --release           -> release mode
#      ./run.sh -d <device-id>      -> device specifico
exec flutter run --dart-define-from-file=dart_defines.json "$@"
