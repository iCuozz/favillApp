const fs = require('fs');
const path = require('path');

const [questId, title, subtitle, season, locationId] = process.argv.slice(2);

if (!questId || !title || !subtitle || !season || !locationId) {
  console.error('Usage: node update-world-map.cjs <quest-id> <title> <subtitle> <season> <location-id>');
  process.exit(1);
}

const worldMapPath = path.join('assets', 'data', 'world_map.json');
const worldMap = JSON.parse(fs.readFileSync(worldMapPath, 'utf-8'));

const newQuest = {
  id: questId,
  title: title,
  subtitle: subtitle,
  file: `assets/data/quests/${questId}.json`,
  thumbnail: `assets/episodes/${questId}/thumb.webp`,
  season: parseInt(season),
  requires_completed: [],
  requires_stats: {}
};

const location = worldMap.locations.find(loc => loc.id === locationId);

if (!location) {
  console.error(`Error: Location with id "${locationId}" not found in world_map.json`);
  process.exit(1);
}

if (!location.quests) {
  location.quests = [];
}

location.quests.push(newQuest);

fs.writeFileSync(worldMapPath, JSON.stringify(worldMap, null, 2));

console.log(`✅ Quest "${questId}" added to location "${locationId}" in ${worldMapPath}`);
