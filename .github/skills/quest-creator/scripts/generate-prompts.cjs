const fs = require('fs');
const path = require('path');

const questId = process.argv[2];

if (!questId) {
  console.error('Usage: node generate-prompts.cjs <quest-id>');
  process.exit(1);
}

const promptsFilePath = path.join('assets', 'data', 'illustration_prompts.md');
let promptsContent = fs.readFileSync(promptsFilePath, 'utf-8');

const newPrompts = `
---

## 📖 QUEST: ${questId}

> Salva in `assets/episodes/${questId}/` e aggiorna i path nel JSON.

---

### page_0
`assets/episodes/${questId}/page_0.webp`

```
[STYLE BLOCK]
[ENV]

Scene: [DESCRIZIONE DELLA SCENA]

[NEGATIVE BLOCK]
```

---

### epilogue
`assets/episodes/${questId}/epilogue.webp`

```
[STYLE BLOCK]
[ENV]

Scene: [DESCRIZIONE DELLA SCENA]

[NEGATIVE BLOCK]
```
`;

promptsContent += newPrompts;

fs.writeFileSync(promptsFilePath, promptsContent);

console.log(`✅ Placeholder prompts for quest "${questId}" added to ${promptsFilePath}`);
