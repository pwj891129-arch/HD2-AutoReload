const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const asar = 'E:/Program Files/HD2Arsenal/resources/app.asar';
if (!fs.existsSync(asar)) { console.log('SKIP installed Arsenal collector fixture'); process.exit(0); }
const report = JSON.parse(fs.readFileSync(path.join(__dirname,'../dist/build-report.json')));
const stage = path.resolve(report.stage);
const fd = fs.openSync(asar,'r');
let source;
try {
  const header = Buffer.alloc(16);fs.readSync(fd,header,0,16,0);
  const bytes = Buffer.alloc(header.readUInt32LE(12));fs.readSync(fd,bytes,0,bytes.length,16);
  let entry = JSON.parse(bytes);
  for (const part of 'obfuscated_src/main/workers/patchAssetCollectorWorker.js'.split('/')) entry = entry.files[part];
  const text = Buffer.alloc(entry.size);
  fs.readSync(fd,text,0,text.length,8+header.readUInt32LE(4)+Number(entry.offset));source = text.toString();
} finally { fs.closeSync(fd); }
function checked(file) {
  const resolved = path.resolve(file);
  assert(resolved === stage || resolved.startsWith(stage+path.sep),'collector reads only the owned package stage');
  return resolved;
}
const readonly = Object.fromEntries(['existsSync','statSync','readFileSync','readdirSync'].map(name =>
  [name,(file,...args)=>fs[name](checked(file),...args)]));
const asyncFiles = {...readonly,pathExists:async file=>fs.existsSync(checked(file)),
  stat:file=>fs.promises.stat(checked(file))};
let handler;
const messages = [];
const context = {Buffer,console:{log(){},warn(){},error(){}},setInterval(){return 1;},clearInterval(){},
  setTimeout(fn){fn();},process:{on(){},nextTick(){}},
  require(name) {
    if (name==='worker_threads') return {workerData:{},parentPort:{
      on(event,callback){if(event==='message')handler=callback;},postMessage(message){messages.push(message);}}};
    if (name==='fs') return readonly;
    if (name==='fs-extra') return asyncFiles;
    if (name==='path') return path;
    throw Error('Unexpected collector dependency: '+name);
  }};
vm.createContext(context);vm.runInContext(source,context,{timeout:2000});
(async()=>{
  assert.equal(typeof handler,'function');
  const manifest = JSON.parse(fs.readFileSync(path.join(stage,'manifest.json')));
  assert(!manifest.Options && !manifest.Include,'hidden editor must not depend on ignored manifest Include');
  await handler({type:'checkConflicts',jobId:'helper-package-test',data:{modFolderPath:stage,
    mod:{uuid:manifest.Guid,label:manifest.Name,path:stage,options:[]},modsList:[],sendProgress:false}});
  const result = messages.find(message=>message.type==='result');
  assert(result,'Installed Arsenal collector failed: '+JSON.stringify(messages));
  const assets = result.data.headers;
  assert(assets.hasAssets,'Installed Arsenal collector found no helper assets');
  assert.equal(result.summary.structureAnalysis.rootCount,48,'all root resources are picked up');
  assert.equal(result.summary.structureAnalysis.duplicateCount,0,'hidden editor folders are not deployed');
  const root = assets.assets.root;
  assert(root.some(item=>item.fileID===BigInt('0x'+report.resourceHash).toString()),'helper Lua resource absent');
  assert.equal(result.summary.structureAnalysis.totalCount,48,'no option selections required');
  console.log('PASS installed Arsenal 0.36.2 collector: 48 root assets, helper and defaults, no visible options or duplicates; read-only');
})().catch(error=>{console.error(error);process.exitCode=1;});
