const fs = require('fs');
const path = require('path');

const sceneDescription = process.argv[2];

if (!sceneDescription) {
  console.error('Usage: node generate-prompt.cjs <scene-description>');
  process.exit(1);
}

const promptBlocksPath = path.join(__dirname, '..', 'references', 'prompt-blocks.md');
const promptBlocksContent = fs.readFileSync(promptBlocksPath, 'utf-8');

const styleBlock = promptBlocksContent.match(/## 🎨 Stile globale \(STYLE BLOCK — copia in OGNI prompt\)\s*```\s*([\s\S]*?)\s*```/)[1];
const negativeBlock = promptBlocksContent.match(/### Negative prompt \(NEGATIVE BLOCK — usalo sempre\)\s*```\s*([\s\S]*?)\s*```/)[1];

const prompt = `[STYLE BLOCK]
${styleBlock}

Scene: ${sceneDescription}

[NEGATIVE BLOCK]
${negativeBlock}
`;

console.log(prompt);
