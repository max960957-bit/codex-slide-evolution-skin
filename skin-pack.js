// Skin packs contain data only. No user JavaScript, HTML or CSS is evaluated.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
function loadSkin(directory) {
  const root = fs.realpathSync(directory);
  let total = 0;
  function read(name, limit) {
    if (typeof name !== 'string' || !/^[\p{L}\p{N}_. -]+$/u.test(name) || name === '.' || name === '..') throw Error('Invalid skin filename');
    const file = fs.realpathSync(path.join(root, name));
    if (path.dirname(file) !== root) throw Error('Skin file escapes its directory');
    const stat = fs.statSync(file);
    if (!stat.isFile() || stat.size > limit) throw Error('Skin file is missing, invalid or too large: ' + name);
    total += stat.size;
    if (total > 150 * 1024 * 1024) throw Error('Skin pack exceeds 150 MB');
    return fs.readFileSync(file);
  }
  const config = JSON.parse(read('skin.json', 65536).toString('utf8').replace(/^\uFEFF/, ''));
  if (config?.formatVersion !== 1 || typeof config.name !== 'string' || !config.name.trim() || config.name.length > 80
      || (config.author !== undefined && (typeof config.author !== 'string' || config.author.length > 80))
      || !Array.isArray(config.levels) || config.levels.length !== 6 || !config.ex) throw Error('Invalid skin.json: expected version 1, name, six levels and EX');
  const names = [...config.levels, config.ex.poster, config.ex.video];
  const files = names.map((name, index) => {
    const video = index === 7;
    if (typeof name !== 'string' || path.extname(name).toLowerCase() !== (video ? '.mp4' : '.png')) throw Error('Use PNG images and an MP4 video');
    const bytes = read(name, (video ? 80 : 20) * 1024 * 1024);
    if (video) {
      if (bytes.length < 16 || bytes.toString('ascii',4,8) !== 'ftyp' || bytes.readUInt32BE(0) < 16 || bytes.readUInt32BE(0) > bytes.length) throw Error('Invalid MP4 header: ' + name);
    } else {
      if (bytes.length < 33 || bytes.subarray(0,8).toString('hex') !== '89504e470d0a1a0a' || bytes.toString('ascii',12,16) !== 'IHDR') throw Error('Invalid PNG header: ' + name);
      const width = bytes.readUInt32BE(16), height = bytes.readUInt32BE(20);
      if (!width || !height || width > 8192 || height > 8192 || width * height > 33554432) throw Error('PNG dimensions exceed limit: ' + name);
    }
    return { name, bytes, sha256: crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase() };
  });
  return { name: config.name.trim(), author: config.author || '', files };
}
function createSkin(directory) {
  // Fail on existing destinations so users never lose a skin they have edited.
  fs.mkdirSync(directory);
  const core = path.join(__dirname, 'visual-core');
  const originals = ['assets/anchors/frame_01.png','assets/levels/frame_02.png','assets/levels/level_03.png',
    'assets/anchors/frame_16.png','assets/levels/level_05.png','assets/anchors/frame_31.png',
    'assets/anchors/frame_ex.png','assets/ex/ex_ambient_loop.mp4'];
  const names = ['l1.png','l2.png','l3.png','l4.png','l5.png','l6.png','ex.png','ex.mp4'];
  originals.forEach((name,i) => fs.copyFileSync(path.join(core,name),path.join(directory,names[i]),fs.constants.COPYFILE_EXCL));
  fs.writeFileSync(path.join(directory,'skin.json'), JSON.stringify({formatVersion:1,name:'My Skin',author:'',levels:names.slice(0,6),ex:{poster:'ex.png',video:'ex.mp4'}},null,2));
  return loadSkin(directory);
}
if (require.main === module) {
  try {
    const [command, directory] = process.argv.slice(2);
    if (!directory || !['create','validate'].includes(command)) throw Error('Usage: node skin-pack.js create|validate <directory>');
    const skin = command === 'create' ? createSkin(path.resolve(directory)) : loadSkin(directory);
    console.log(JSON.stringify({name:skin.name,author:skin.author,files:skin.files.map(({name,sha256})=>({name,sha256}))},null,2));
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
module.exports = { loadSkin, createSkin };
