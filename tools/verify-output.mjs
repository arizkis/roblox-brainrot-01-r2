// Our output audit, separate from makefun check's intake/transcript rows.
// The pinned Luau compiler is a verification tool loaded entirely in memory.
// No third-party source/dependency files are copied into this repository or output.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { lstatSync, readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import vm from 'node:vm';
import { gunzipSync, inflateSync } from 'node:zlib';
import { buildDossier, chunkData, matchSources, placeFraming, readPlace } from '../vendor/makefun-roblox.ts';

const output = path.resolve(process.argv[2] ?? 'out');
const caps = { text_max_bytes: 65536, screenshots: { max: 4, max_bytes: 262144 }, max_instances: 500000, scripts_max_source_bytes: 8388608, scripts_max_path_chars: 1048576 };
const checks = [];
let place;
let sources;
let match;

async function check(name, run) {
  try { checks.push({check: name, status: 'pass', reason: await run()}); }
  catch (error) { checks.push({check: name, status: 'fail', reason: error.message}); }
}

function filesUnder(directory, relative = '') {
  return readdirSync(path.join(directory, relative)).sort().flatMap(name => {
    const child = path.join(relative, name);
    const stat = lstatSync(path.join(directory, child));
    assert(!stat.isSymbolicLink(), `Symbolic link: ${child}`);
    assert(/^[A-Za-z0-9_][A-Za-z0-9_.-]*$/.test(name), `Invalid output name: ${child}`);
    if (stat.isDirectory()) return filesUnder(directory, child);
    assert(stat.isFile(), `Not a regular file: ${child}`);
    return [child];
  });
}

function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function imageDimensions(bytes) {
  if (bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]))) {
    let offset = 8;
    let width = 0;
    let height = 0;
    let ended = false;
    const compressed = [];
    while (offset < bytes.length) {
      assert(offset + 12 <= bytes.length, 'Truncated PNG chunk');
      const size = bytes.readUInt32BE(offset);
      const end = offset + 12 + size;
      assert(end <= bytes.length, 'Truncated PNG data');
      const type = bytes.toString('ascii', offset + 4, offset + 8);
      assert.equal(crc32(bytes.subarray(offset + 4, end - 4)), bytes.readUInt32BE(end - 4), `PNG CRC: ${type}`);
      if (offset === 8) {
        assert.equal(type, 'IHDR');
        assert.equal(size, 13);
        width = bytes.readUInt32BE(offset + 8);
        height = bytes.readUInt32BE(offset + 12);
      }
      if (type === 'IDAT') compressed.push(bytes.subarray(offset + 8, end - 4));
      offset = end;
      if (type === 'IEND') { ended = true; break; }
    }
    assert(ended && offset === bytes.length && compressed.length, 'PNG must end at IEND');
    assert(inflateSync(Buffer.concat(compressed)).length > 0, 'PNG has no pixel data');
    return [width, height];
  }
  assert(bytes[0] === 255 && bytes[1] === 216 && bytes.at(-2) === 255 && bytes.at(-1) === 217, 'Not a complete PNG/JPEG');
  let offset = 2;
  while (offset + 4 < bytes.length) {
    assert.equal(bytes[offset++], 255, 'JPEG marker missing');
    while (bytes[offset] === 255) offset++;
    const marker = bytes[offset++];
    if (marker === 0xda || marker === 0xd9) break;
    if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) continue;
    const length = bytes.readUInt16BE(offset);
    assert(length >= 2 && offset + length <= bytes.length, 'Truncated JPEG segment');
    if ([0xc0,0xc1,0xc2,0xc3,0xc5,0xc6,0xc7,0xc9,0xca,0xcb,0xcd,0xce,0xcf].includes(marker)) {
      return [bytes.readUInt16BE(offset + 5), bytes.readUInt16BE(offset + 3)];
    }
    offset += length;
  }
  throw new Error('JPEG dimensions missing');
}

async function compilerInMemory() {
  const response = await fetch('https://registry.npmjs.org/luau-web/-/luau-web-1.5.1.tgz');
  assert(response.ok, `Compiler download HTTP ${response.status}`);
  const archive = Buffer.from(await response.arrayBuffer());
  const integrity = createHash('sha512').update(archive).digest('base64');
  assert.equal(integrity, '/PINL46SDMR7ezqnVxxjR66+k8+JH8U7VH/ct+tY53jXfQvTMwcgGzF0jW3MFYWaY5MnGtj0wlYKSAf3L/2Slw==', 'Compiler integrity mismatch');
  const tar = gunzipSync(archive);
  const code = new Map();
  for (let offset = 0; offset + 512 <= tar.length;) {
    const header = tar.subarray(offset, offset + 512);
    if (header.every(byte => byte === 0)) break;
    const name = header.toString('utf8', 0, 100).split('\0')[0];
    const length = Number.parseInt(header.toString('ascii', 124, 136).replace(/\0/g, '').trim(), 8) || 0;
    const start = offset + 512;
    assert(start + length <= tar.length, 'Truncated compiler archive');
    if (name.startsWith('package/src/') && name.endsWith('.js')) code.set(name.slice('package/'.length), tar.toString('utf8', start, start + length));
    offset = start + Math.ceil(length / 512) * 512;
  }
  // A virtual file URL lets Emscripten create its Node builtin require adapter.
  // This path does not exist: the JS and embedded WebAssembly stay in memory.
  const virtualRoot = pathToFileURL(path.resolve('.git/luau-in-memory') + path.sep);
  const cache = new Map();
  async function load(name) {
    if (cache.has(name)) return cache.get(name);
    assert(code.has(name), `Missing compiler module: ${name}`);
    const identifier = new URL(name, virtualRoot).href;
    const module = new vm.SourceTextModule(code.get(name), {
      identifier,
      initializeImportMeta(meta) { meta.url = identifier; },
      importModuleDynamically: async (specifier, parent) => {
        if (specifier.startsWith('node:')) return import(specifier);
        const resolved = new URL(specifier, parent.identifier).href;
        assert(resolved.startsWith(virtualRoot.href), 'Compiler import escaped its memory bundle');
        return load(resolved.slice(virtualRoot.href.length));
      },
    });
    cache.set(name, module);
    await module.link(() => { throw new Error('Unexpected static compiler import'); });
    await module.evaluate();
    return module;
  }
  return (await load('src/index.js')).namespace.LuauState;
}

await check('place_file', () => {
  const file = path.join(output, 'game.rbxl');
  const stat = lstatSync(file);
  assert(stat.isFile() && !stat.isSymbolicLink() && stat.size <= 32 * 1024 * 1024);
  const bytes = readFileSync(file);
  const framing = placeFraming(bytes);
  const declared = framing.chunks.reduce((sum, chunk) => sum + chunk.uncompressedLength, 0);
  assert(declared <= 256 * 1024 * 1024);
  const last = framing.chunks.at(-1);
  assert.equal(last.name, 'END');
  assert.equal(last.offset + last.uncompressedLength, bytes.length);
  for (const chunk of framing.chunks) chunkData(bytes, chunk);
  assert(bytes.equals(readFileSync('game.rbxl')), 'Output place differs from repository');
  return `${stat.size} bytes; complete binary place; ${declared} declared uncompressed bytes`;
});
await check('place_scripts', () => {
  place = readPlace(readFileSync(path.join(output, 'game.rbxl')), caps);
  assert(place.scripts.some(script => script.source && script.source.length > 0));
  return `${place.instances} instances; ${place.scripts.length} scripts; within instance/source/path caps`;
});
await check('source_matches_place', () => {
  assert(place, 'Place could not be read');
  const root = path.join(output, 'src');
  const files = filesUnder(root);
  assert(files.length <= 400);
  assert(files.reduce((sum, file) => sum + lstatSync(path.join(root, file)).size, 0) <= 4 * 1024 * 1024);
  sources = files.filter(file => /\.luau?$/.test(file)).map(file => ({path: file, bytes: readFileSync(path.join(root, file))}));
  match = matchSources(place, sources);
  assert.equal(match.unmatched.length, 0);
  assert(match.coverage >= 0.8);
  for (const source of sources) assert(Buffer.from(source.bytes).equals(readFileSync(path.join('src', source.path))), source.path);
  return `${sources.length} source files; ${(match.coverage * 100).toFixed(1)}% of ${match.scriptBytes} script bytes covered`;
});
await check('screenshots', () => {
  const directory = path.join(output, 'screenshots');
  const names = filesUnder(directory);
  assert(names.length >= 3 && names.length <= 4);
  const sizes = names.map(name => {
    assert(/^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$/.test(name));
    const bytes = readFileSync(path.join(directory, name));
    assert(bytes.length <= 256 * 1024);
    const [width, height] = imageDimensions(bytes);
    assert(Math.max(width, height) <= 1280 && Math.min(width, height) >= 480);
    assert(bytes.equals(readFileSync(path.join('screenshots', name))), 'Capture changed during packaging');
    return `${name}: ${width}x${height}, ${bytes.length} bytes`;
  });
  return `${sizes.join('; ')}. Starter captures retained; real Studio replacements are pending.`;
});
await check('entry_link_file', () => {
  const data = JSON.parse(readFileSync(path.join(output, 'PLAY.json'), 'utf8'));
  assert(Number.isSafeInteger(data.place_id) && data.place_id > 0);
  assert(Number.isSafeInteger(data.universe_id) && data.universe_id > 0);
  const url = new URL(data.url);
  assert.equal(url.protocol, 'https:');
  assert.equal(url.hostname, 'www.roblox.com');
  assert(new RegExp(`^/games/${data.place_id}(?:/[^/]*)?$`).test(url.pathname));
  assert(readFileSync(path.join(output, 'PLAY.json')).equals(readFileSync('PLAY.json')));
  return `Place ${data.place_id}; universe ${data.universe_id}; URL and ids agree`;
});
await check('dossier_matches', () => {
  const actual = readFileSync(path.join(output, 'dossier.json'));
  assert(actual.length <= 1.5 * 1024 * 1024);
  assert(actual.equals(Buffer.from(buildDossier(output, caps))));
  return `${actual.length} bytes; byte-for-byte buildDossier match; within 1.5 MiB`;
});
await check('luau_compiles', async () => {
  assert(sources && match, 'Sources could not be matched');
  const LuauState = await compilerInMemory();
  const state = await LuauState.createAsync({});
  const failures = [];
  try {
    for (const source of sources) {
      try { state.loadstring(Buffer.from(source.bytes).toString('utf8'), source.path, true); }
      catch (error) { failures.push(`${source.path}: ${error.message}`); }
    }
  } finally { state.destroy(); }
  assert.equal(failures.length, 0, failures.join('\n'));
  return `All ${sources.length} source files compiled by luau-web 1.5.1; game scripts were not executed`;
});

for (const name of ['game.rbxl','src','screenshots','PLAY.json','dossier.json']) assert(lstatSync(path.join(output,name)));
console.log(JSON.stringify({source: 'Independent artifact audit; makefun check is reported separately', output, checks}, null, 2));
if (checks.some(row => row.status === 'fail')) process.exitCode = 1;
