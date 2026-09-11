// Bundle the existing visual core and original media; never modify the formal project.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const project = path.join(__dirname, 'visual-core');
function build(skinDirectory) {
  const baseline = JSON.parse(fs.readFileSync(path.join(project, 'baseline.json'), 'utf8'));
  for (const file of baseline.files) {
    const bytes = fs.readFileSync(path.join(project, file.path));
    if (crypto.createHash('sha256').update(bytes).digest('hex') !== file.sha256) throw Error('Bundled core hash mismatch: ' + file.path);
  }
  const read = name => fs.readFileSync(path.join(project, name), 'utf8');
  const files = ['skin-config', 'visual-interpolation', 'skin-engine', 'ex-motion', 'ex-video-background'];
  const context = { window: {} };
  vm.runInNewContext(read('src/js/skin-config.js'), context);
  const config = context.window.SKIN_CONFIG;
  const skin = skinDirectory ? require('./skin-pack').loadSkin(skinDirectory) : null;
  const paths = [...new Set([...config.levels.map(l => l.imageSlot.path), config.ex.videoBackground.poster,
    config.ex.videoBackground.sources.mp4])];
  if (config.levels.length !== 6 || !config.ex.videoBackground.sources.mp4) throw Error('Expected six levels and EX video');
  const assets = {}, manifest = [];
  let bootstrap;
  for (const [index, name] of paths.entries()) {
    const custom = skin?.files[index];
    const bytes = custom ? custom.bytes : fs.readFileSync(path.join(project, name));
    if (index === 0) bootstrap = bytes;
    const sha256 = crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
    const expected = config.levels.find(l => l.imageSlot.path === name)?.imageSlot.sha256;
    if (!custom && expected && expected !== sha256) throw Error('Asset hash mismatch: ' + name);
    assets[name] = { data: bytes.toString('base64'), type: name.endsWith('.mp4') ? 'video/mp4' : 'image/png' };
    manifest.push({ path: name, bytes: bytes.length, sha256, ...(custom ? { skinFile: custom.name } : {}) });
  }
  const preview = read('preview.html');
  const markup = preview.slice(preview.indexOf('<div class="skin-stack"'), preview.indexOf('<div class="pelican-transition-overlay"')).replace(/ poster="[^"]*"/g, '');
  const css = ['skin'].map(n => read(`src/styles/${n}.css`)).join('\n').replaceAll('body[', ':host([').replace(/:host\(\[([^\]]+)\]/g, ':host([$1])');
  const core = files.map(n => (n === 'ex-video-background' ? fs.readFileSync(path.join(__dirname, 'ex-video-loop.js'), 'utf8') : read(`src/js/${n}.js`)).replace(/(["'])(assets\/[^"']+)\1/g,
    (match, quote, name) => paths.includes(name) ? `asset(${JSON.stringify(name)})` : match)).join('\n');
  const template = fs.readFileSync(path.join(__dirname, 'sequence-host.js'), 'utf8');
  const source = template.replace('/* ASSET_DATA */', () => JSON.stringify(assets))
    .replace('/* MARKUP */', () => JSON.stringify(markup)).replace('/* CSS */', () => JSON.stringify(css))
    .replace('/* VISUAL_CORE */', () => core);
  new vm.Script(source);
  return { source, manifest, bootstrap, skin: skin ? {name:skin.name,author:skin.author} : null };
}
if (require.main === module) {
  const { source, manifest, bootstrap, skin } = build(process.argv[3] || undefined);
  const output = path.resolve(process.argv[2] || path.join(__dirname, 'runtime/sequence.bundle.js'));
  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.writeFileSync(output, source);
  fs.writeFileSync(output + '.manifest.json', JSON.stringify(manifest, null, 2));
  fs.writeFileSync(output + '.bootstrap.png', bootstrap);
  fs.writeFileSync(output + '.skin.json', JSON.stringify(skin));
  console.log('Sequence bundle ready: six images, EX poster/video; ' + output);
}
module.exports = { build };
