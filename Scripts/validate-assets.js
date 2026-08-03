const fs = require('fs');
const path = require('path');

const repo = path.resolve(__dirname, '..');
const errors = [];

function exists(relative) {
  return fs.existsSync(path.join(repo, relative));
}

function checkJson(relative) {
  const file = path.join(repo, relative);
  if (!fs.existsSync(file)) {
    errors.push(`Missing ${relative}`);
    return;
  }
  try {
    JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (error) {
    errors.push(`Invalid JSON in ${relative}: ${error.message}`);
  }
}

['project.yml',
 'Config/Info.plist',
 'Config/Resonance.entitlements',
 'Resonance/Resources/Player/player_configs.json',
 'Resonance/Resources/Player/player_dates.json',
 'Resonance/Resources/Assets.xcassets/Contents.json',
 'Resonance/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json',
 'Resonance/Resources/Assets.xcassets/AccentColor.colorset/Contents.json'
].forEach((file) => {
  if (!exists(file)) errors.push(`Missing ${file}`);
});

checkJson('Resonance/Resources/Player/player_configs.json');
checkJson('Resonance/Resources/Player/player_dates.json');

const requiredSources = [
  'Resonance/App/ResonanceApp.swift',
  'Resonance/App/AppContainer.swift',
  'Resonance/Core/Models/CatalogModels.swift',
  'Resonance/Core/Models/LyricsModels.swift',
  'Resonance/Core/Networking/JSONValue.swift',
  'Resonance/Core/Networking/HTTPClient.swift',
  'Resonance/Core/Networking/InnerTubeClient.swift',
  'Resonance/Core/Networking/InnerTubeEndpoints.swift',
  'Resonance/Core/Networking/InnerTubeParser.swift',
  'Resonance/Core/Repositories/CatalogRepository.swift',
  'Resonance/Core/Persistence/LibraryModels.swift',
  'Resonance/Core/Persistence/SwiftDataLibraryRepository.swift',
  'Resonance/Core/Lyrics/LyricsService.swift',
  'Resonance/Core/Streaming/StreamResolver.swift',
  'Resonance/Core/Streaming/JavaScriptSignatureSolver.swift',
  'Resonance/Core/Playback/PlaybackController.swift',
  'Resonance/UI/Theme/ResonanceTheme.swift',
  'Resonance/UI/Components/ArtworkView.swift',
  'Resonance/UI/Components/TrackRow.swift',
  'Resonance/UI/Components/SectionGrid.swift',
  'Resonance/UI/Components/AsyncStateView.swift',
  'Resonance/Features/RootView.swift',
  'Resonance/Features/Home/HomeView.swift',
  'Resonance/Features/Home/HomeViewModel.swift',
  'Resonance/Features/Home/HeroShelf.swift',
  'Resonance/Features/Shared/CatalogItemDetailSheet.swift',
  'Resonance/Features/Search/SearchView.swift',
  'Resonance/Features/Library/LibraryView.swift',
  'Resonance/Features/NowPlaying/NowPlayingView.swift',
  'Resonance/Features/NowPlaying/MiniPlayerView.swift'
];
requiredSources.forEach((file) => {
  if (!exists(file)) errors.push(`Missing Swift source ${file}`);
});

const requiredTests = [
  'ResonanceTests/JSONValueTests.swift',
  'ResonanceTests/InnerTubeParserTests.swift',
  'ResonanceTests/InnerTubeEndpointTests.swift',
  'ResonanceTests/LyricsParserTests.swift',
  'ResonanceTests/HTTPClientTests.swift',
  'ResonanceTests/Fixtures/home-response.json',
  'ResonanceTests/Fixtures/search-response.json',
  'ResonanceTests/Fixtures/lyrics.lrc'
];
requiredTests.forEach((file) => {
  if (!exists(file)) errors.push(`Missing test asset ${file}`);
});

if (errors.length) {
  console.error(errors.map((message) => `  - ${message}`).join('\n'));
  process.exit(1);
}

console.log('All required files are present and JSON resources parse cleanly.');
