# Setup Firebase Cloud Messaging (FCM) — guida rapida

Tutto il codice è già pronto. Devi solo collegare un progetto Firebase
(gratuito) per attivare le push reali quando l'app è chiusa.

L'app funziona già **senza** questo setup: appena la riapri, l'inbox si
sincronizza in automatico e le risposte arrivano comunque (badge sull'icona
mail in AskFavilla). Le push servono solo per essere avvisato in tempo reale.

---

## 1. Crea il progetto Firebase (5 min)

1. Vai su <https://console.firebase.google.com>
2. **Add project** → nome `Favilla App` → disabilita Analytics (non serve) → crea.
3. Nella dashboard del progetto: icona Android → registra app:
   - **Android package name**: `it.cuozzo.favilla`
   - App nickname: Favilla
   - SHA-1: lascia vuoto (non serve per FCM base).
4. **Scarica `google-services.json`** → mettilo in
   `android/app/google-services.json` nella tua repo.
5. Salta gli step "Add Firebase SDK" e "Verify": il codice Flutter è già
   configurato. Clicca "Continue to console".

## 2. Service account per il worker (3 min)

Il worker deve poter mandare le push, quindi gli serve una chiave admin:

1. Console Firebase → ⚙ Project Settings → tab **Service accounts**
2. **Generate new private key** → scarica un file JSON.
3. Carica come secret nel worker:

```bash
cd worker
npx wrangler secret put FCM_SERVICE_ACCOUNT_JSON < /path/del/file.json
```

## 3. Plugin Gradle Android (2 min)

Aggiungi il plugin Google Services:

**`android/build.gradle.kts`** (root) — dentro il blocco `plugins {}`:

```kotlin
id("com.google.gms.google-services") version "4.4.2" apply false
```

**`android/app/build.gradle.kts`** — dentro il blocco `plugins {}`:

```kotlin
id("com.google.gms.google-services")
```

Se i tuoi file sono `.gradle` Groovy, la sintassi cambia leggermente ma il
plugin è lo stesso.

## 4. Build e test

```bash
flutter clean
flutter pub get
flutter run
```

Al primo avvio l'app:

- chiede il permesso notifiche;
- registra il token FCM presso il worker;
- la prossima volta che rispondi a una domanda dall'admin UI
  (https://favilla-ai-worker.cuozzo.workers.dev/admin), arriva la push 🎉

## Troubleshooting

- **Niente push ma inbox funziona** → `wrangler tail` mentre rispondi:
  dovresti vedere `event: fcm_send`. Se appare `fcm_not_configured`, il
  secret non è impostato.
- **Permesso notifiche negato** → impostazioni di sistema → app Favilla →
  Notifiche → abilita.
- **Build Android fallisce sul plugin Google Services** → controlla che il
  package in `android/app/build.gradle*` sia esattamente
  `it.cuozzo.favilla`.
