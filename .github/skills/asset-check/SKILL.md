---
name: asset-check
description: >
  Verifica che tutti gli asset (immagini .webp) referenziati nei file JSON
  di quest ed episodi esistano realmente nella cartella assets/.
  Usa questa skill prima di flutter run o flutter build, o dopo aver creato
  nuove quest, per evitare crash da asset mancanti.
allowed-tools: shell
---

# Asset Check — FavillApp

Quando questa skill viene invocata, esegui lo script `check_assets.sh`
dalla directory della skill, passando come argomento la root del progetto Flutter.

Lo script scansiona tutti i file JSON in `assets/data/` alla ricerca di path
con `"background":` o `"thumbnail":`, poi verifica che ogni file esista.
Stampa un report con:
- ✅ asset presenti
- ❌ asset mancanti (con il file JSON e la riga dove sono referenziati)

Alla fine mostra un conteggio totale. Se ci sono asset mancanti, segnalali
chiaramente e suggerisci di creare i file placeholder o aggiornare i path nel JSON.
