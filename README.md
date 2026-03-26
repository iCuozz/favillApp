# favilla_app

# FavillApp

**FavillApp** è un progetto creativo dedicato all’universo di **Favilla Blaze**, una web app pensata per raccontare storie a episodi in stile comic book moderno, con personaggi coerenti, tavole illustrate e contenuti strutturati tramite JSON.

L’app nasce per trasformare scene quotidiane, momenti familiari e missioni supereroistiche in un’esperienza narrativa visiva coinvolgente, organizzata come una vera serie a fumetti digitale.

---

## Panoramica

FavillApp permette di gestire episodi composti da:

- **copertine**
- **pagine illustrate**
- **pannelli narrativi**
- **blocchi di testo** (narrazione, dialoghi, pensieri)
- **personaggi ricorrenti** con identità visiva coerente

L’obiettivo è avere una struttura semplice da estendere, facilmente mantenibile e adatta sia alla produzione di nuove missioni sia alla futura evoluzione del progetto.

---

## Universo narrativo

I protagonisti principali sono:

- **Favilla / Favilla Blaze** – eroina luminosa, cuore del progetto
- **Sparkle Ale** – piccolo coprotagonista energico e iconico
- **Mallow Bellow** – presenza di supporto nel mondo narrativo

L’ambientazione unisce vita quotidiana, caos domestico e immaginario supereroistico, con uno stile visivo ispirato ai comic book premium moderni.

---

## Caratteristiche principali

- Struttura narrativa organizzata in **episodi**
- Gestione delle tavole tramite **configurazioni JSON**
- Supporto a **background illustrati** per ogni pagina
- Rendering di **pannelli con testo strutturato**
- Separazione tra contenuti, asset grafici e logica applicativa
- Impostazione scalabile per nuovi episodi e nuove missioni
- Base ideale per evoluzioni future come animazioni, audio e transizioni cinematiche

---

## Struttura contenuti

Un episodio può seguire una struttura simile a questa:

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
