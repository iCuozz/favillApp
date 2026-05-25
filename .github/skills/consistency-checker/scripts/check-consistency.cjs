const fs = require('fs');
const path = require('path');

const projectRoot = process.argv[2] || process.cwd();

function parseMarkdownTable(markdown, sectionTitle) {
  const lines = markdown.split('\n');
  let inSection = false;
  const tableLines = [];

  for (const line of lines) {
    if (/^## /.test(line) && line.includes(sectionTitle)) {
      inSection = true;
      continue;
    }
    if (inSection && /^## /.test(line)) break;
    if (inSection) tableLines.push(line);
  }

  if (!tableLines.length) return null;

  const data = {};
  for (const row of tableLines) {
    const columns = row.split('|').map(c => c.trim());
    if (columns.length > 2) {
      const key = columns[1].replace(/[\*\s]/g, '').toLowerCase();
      if (key && key !== '---') {
        data[key] = columns[2] || '';
      }
    }
  }
  return Object.keys(data).length > 0 ? data : null;
}

function getCharacterBlock(markdown, characterName) {
  const escapedName = characterName.toUpperCase().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const blockRegex = new RegExp(
    `### ${escapedName}(?:\\s*\\([^)]*\\))?\\s*\`\`\`([\\s\\S]*?)\`\`\``
  );
  const match = markdown.match(blockRegex);
  if (!match) return null;
  return match[1].trim();
}

const biblePath = path.join(projectRoot, 'docs', 'NARRATIVE_BIBLE.md');
const promptsPath = path.join(projectRoot, 'assets', 'data', 'illustration_prompts.md');

if (!fs.existsSync(biblePath)) {
  process.stderr.write(`Failure: File not found: ${biblePath}\n`);
  process.exit(1);
}
if (!fs.existsSync(promptsPath)) {
  process.stderr.write(`Failure: File not found: ${promptsPath}\n`);
  process.exit(1);
}

const narrativeBible = fs.readFileSync(biblePath, 'utf-8');
const illustrationPrompts = fs.readFileSync(promptsPath, 'utf-8');

const characters = [
  { name: 'Favilla', bibleName: 'Protagonista — Favilla' },
  { name: 'Mallow', bibleName: 'Mallow' },
  { name: 'Lex', bibleName: 'Lex' },
];

const inconsistencies = [];

for (const char of characters) {
  const bibleData = parseMarkdownTable(narrativeBible, char.bibleName);
  const promptBlock = getCharacterBlock(illustrationPrompts, char.name);

  if (!bibleData || !promptBlock) {
    console.warn(`⚠️  Dati non trovati per ${char.name} — verifica NARRATIVE_BIBLE.md e illustration_prompts.md`);
    continue;
  }

  const details = {};
  const aspetto = bibleData['aspetto'] || '';

  if (char.name === 'Favilla') {
    if (aspetto.includes('Bionda') && !promptBlock.includes('biondi hair')) {
      details.hair = { bible: 'Bionda', prompt: 'manca "biondi hair"' };
    }
  }

  if (char.name === 'Mallow') {
    if (aspetto.includes('Polo azzurra') && !promptBlock.includes('polo azzurra')) {
      details.clothing = { bible: 'Polo azzurra', prompt: 'manca "polo azzurra"' };
    }
    if (aspetto.includes('mini-mohawk') && !promptBlock.includes('mini-mohawk')) {
      details.hair = { bible: 'mini-mohawk', prompt: 'manca "mini-mohawk"' };
    }
  }

  if (char.name === 'Lex') {
    if (aspetto.includes('castani chiari') && !promptBlock.includes('capelli castani chiari')) {
      details.hair = { bible: 'castani chiari', prompt: 'manca "capelli castani chiari"' };
    }
  }

  if (Object.keys(details).length > 0) {
    inconsistencies.push({ character: char.name, details });
  }
}

if (inconsistencies.length > 0) {
  console.log('❌ Inconsistenze trovate nei character block:');
  console.log(JSON.stringify(inconsistencies, null, 2));
  process.exit(1);
} else {
  console.log('✅ Tutti i character block sono coerenti con il Narrative Bible.');
}
