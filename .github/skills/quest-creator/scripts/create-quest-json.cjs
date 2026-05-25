const fs = require('fs');
const path = require('path');

const questId = process.argv[2];

if (!questId) {
  console.error('Usage: node create-quest-json.cjs <quest-id>');
  process.exit(1);
}

const questSchema = {
  "id": questId,
  "pages": [
    {
      "index": 0,
      "background": `assets/episodes/${questId}/page_0.webp`,
      "panels": [
        {
          "id": "p0_0",
          "characters": ["favilla"],
          "text_blocks": [
            {
              "id": "p0_0_tb_0",
              "type": "narration",
              "text": "Testo narrativo in terza persona."
            }
          ],
          "interactions": []
        }
      ]
    }
  ],
  "branches": {},
  "epilogue": {
    "pages": [
      {
        "index": 0,
        "background": `assets/episodes/${questId}/epilogue.webp`,
        "panels": [
          {
            "id": "ep_0",
            "characters": ["favilla"],
            "text_blocks": [
              {
                "id": "ep_0_tb_0",
                "type": "narration",
                "text": "Conclusione della quest."
              },
              {
                "id": "ep_0_tb_1",
                "type": "system",
                "text": "MISSIONE COMPLETATA"
              }
            ],
            "interactions": []
          }
        ]
      }
    ]
  }
};

const filePath = path.join('assets', 'data', 'quests', `${questId}.json`);

fs.writeFileSync(filePath, JSON.stringify(questSchema, null, 2));

console.log(`✅ Quest file created: ${filePath}`);
