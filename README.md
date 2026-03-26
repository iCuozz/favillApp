# 🔥 FavillApp

![Status](https://img.shields.io/badge/status-in%20sviluppo-f59e0b)
![Flutter](https://img.shields.io/badge/Flutter-Android-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-app-blue?logo=dart&logoColor=white)

**FavillApp** è un progetto Flutter per Android dedicato all’universo di **Favilla Blaze**: episodi illustrati, tavole comic book, personaggi coerenti e contenuti strutturati in modo dinamico.

L’obiettivo del progetto è trasformare scene quotidiane, caos domestico e missioni supereroistiche in una vera esperienza da **fumetto digitale episodico** su mobile.

---

## ✨ Descrizione

FavillApp è un’app mobile che organizza ogni storia come una mini-avventura a episodi:

- **copertina episodio**
- **pagine illustrate**
- **pannelli narrativi**
- **dialoghi, pensieri e didascalie**
- **personaggi ricorrenti con identità visiva coerente**

> Un mondo narrativo dove ogni alba può diventare una missione.

---

## 🦸 Universo narrativo

### Favilla / Favilla Blaze
L’eroina principale del progetto. Una figura luminosa, forte, ironica e affettuosa, sospesa tra quotidianità e immaginario supereroistico.

### Sparkle Ale
Il piccolo coprotagonista: energia pura, presenza iconica, caos e meraviglia.

### Mallow Bellow
Elemento ricorrente dell’universo FavillApp, presenza narrativa di supporto nelle missioni e nelle scene quotidiane.

---

## 🚀 Funzionalità principali

- Struttura narrativa a **episodi**
- Supporto a **copertine e pagine illustrate**
- Rendering di **pannelli narrativi**
- Gestione di **testi strutturati**: narrazione, dialoghi, pensieri
- Architettura pensata per essere **scalabile**
- Separazione tra **contenuti**, **asset** e **logica applicativa**
- Base pronta per future evoluzioni come:
  - animazioni
  - effetti audio
  - navigazione avanzata tra episodi
  - schermata archivio missioni

---

## 🧱 Struttura contenuti

Un episodio può seguire una struttura dati simile a questa:

```json
{
  "id": "missione_1",
  "title": "Missione #1 – Caos all'Alba",
  "subtitle": "Favilla Blaze vs risveglio impossibile",
  "thumbnail": "assets/episodes/missione_1/thumb.png",
  "pages": [
    {
      "index": 0,
      "background": "assets/episodes/missione_1/page_0.png",
      "panels": [
        {
          "id": "m1_0",
          "characters": ["Favilla", "Sparkle Ale", "Mallow Bellow"],
          "text_blocks": [
            {
              "type": "narration",
              "text": "5:17 AM. Nova Tutinia dorme. Terzo piano."
            },
            {
              "type": "dialogue",
              "speaker": "Sparkle Ale",
              "text": "MAMMMAAAA! LATTEEE! ORA!"
            }
          ]
        }
      ]
    }
  ]
}


📱 Stack tecnologico

Il progetto è sviluppato con:
	•	Flutter
	•	Dart
	•	gestione asset locale per immagini e copertine
	•	struttura dati configurabile per episodi e pagine
