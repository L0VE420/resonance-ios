const fs = require('fs');
const path = require('path');
const vm = require('vm');

const solverFile = path.resolve(__dirname, '../Resonance/Resources/Player/solver/yt.solver.core.js');
const meriyahFile = path.resolve(__dirname, '../Resonance/Resources/Player/solver/meriyah.js');
const astringFile = path.resolve(__dirname, '../Resonance/Resources/Player/solver/astring.js');

const meriyah = loadModule(meriyahFile, 'meriyah');
const astring = loadModule(astringFile, 'astring');
const solver = loadSolver(solverFile, { meriyah, astring });

runFixtures(solver);

function loadModule(file, exportName) {
  const source = fs.readFileSync(file, 'utf8');
  const context = {
    module: { exports: {} },
    exports: {},
    globalThis: {},
    self: null,
    define: null
  };
  context.self = context;
  vm.createContext(context);
  vm.runInContext(source, context, { filename: file });
  const merged = { ...context.module.exports, ...context.exports };
  if (typeof merged.parse === 'function' && typeof merged.generate !== 'function') return merged;
  if (typeof merged.generate === 'function') return merged;
  throw new Error(`Module ${file} did not export expected helpers`);
}

function loadSolver(file, deps) {
  const source = fs.readFileSync(file, 'utf8');
  const context = { ...deps, globalThis: {} };
  vm.createContext(context);
  vm.runInContext(source, context, { filename: file });
  if (typeof context.jsc !== 'function') throw new Error('Solver did not expose a jsc function');
  return context.jsc;
}

function runFixtures(solver) {
  const fixtureDir = path.resolve(__dirname, '../Resonance/Resources/Player/fixtures');
  if (!fs.existsSync(fixtureDir)) {
    console.log('No solver fixtures present; skipping live solver tests.');
    return;
  }
  for (const file of fs.readdirSync(fixtureDir)) {
    if (!file.endsWith('.json')) continue;
    const fixture = JSON.parse(fs.readFileSync(path.join(fixtureDir, file), 'utf8'));
    const output = solver(fixture);
    if (!output || output.type !== 'result') {
      throw new Error(`Fixture ${file} produced error: ${output && output.responses ? JSON.stringify(output.responses) : 'unknown'}`);
    }
    for (const response of output.responses) {
      if (response.type !== 'result') {
        throw new Error(`Fixture ${file} response failed: ${response.error}`);
      }
    }
    console.log(`Fixture ${file} solved ${output.responses.length} request(s) successfully.`);
  }
}
