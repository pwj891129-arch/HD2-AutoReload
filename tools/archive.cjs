const fs = require('node:fs');
const assert = require('node:assert/strict');
const align = (value,boundary=16) => Math.ceil(value/boundary)*boundary;

// The existing multi-resource packer's layout, preserving each asset's alignment and sidecars.
function load(file) {
  const bytes = fs.readFileSync(file);
  assert.equal(bytes.readUInt32LE(0),0xf0000011);
  assert.equal(bytes.readUInt32LE(8),1,'input must be a single-resource archive');
  const at = 72+32*bytes.readUInt32LE(4);
  const offset = Number(bytes.readBigUInt64LE(at+16)),size = bytes.readUInt32LE(at+56);
  assert(offset>=at+80 && offset+size<=bytes.length);
  const readSidecar = (suffix,offsetAt,sizeAt) => {
    const sidecar = fs.readFileSync(file+suffix),start = Number(bytes.readBigUInt64LE(at+offsetAt));
    const length = bytes.readUInt32LE(at+sizeAt);
    assert(start+length<=sidecar.length);
    return sidecar.subarray(start,start+length);
  };
  return {id:bytes.readBigUInt64LE(at),type:bytes.readBigUInt64LE(at+8),data:bytes.subarray(offset,offset+size),
    stream:readSidecar('.stream',24,60),gpu:readSidecar('.gpu_resources',32,64),
    metadata:bytes.subarray(at+40,at+56),alignment:bytes.readUInt32LE(at+68),
    gpuAlignment:bytes.readUInt32LE(at+72),typeHeader:bytes.subarray(72,104)};
}
function merge(files) {
  const entries = files.map(load).sort((a,b)=>a.type<b.type?-1:a.type>b.type?1:a.id<b.id?-1:1);
  assert.equal(new Set(entries.map(entry=>`${entry.type}/${entry.id}`)).size,entries.length,'duplicate resource');
  const types = [...new Set(entries.map(entry=>entry.type))],header = 72+32*types.length;
  let end = align(header+80*entries.length),gpuEnd = 0,streamEnd = 0;
  for (const entry of entries) {
    entry.offset=end;end=align(end+entry.data.length);
    entry.gpuOffset=align(gpuEnd,64);gpuEnd=entry.gpuOffset+entry.gpu.length;
    entry.streamOffset=align(streamEnd,64);streamEnd=entry.streamOffset+entry.stream.length;
  }
  const bytes=Buffer.alloc(Math.max(end,256*entries.length)),gpu=Buffer.alloc(gpuEnd),stream=Buffer.alloc(streamEnd);
  bytes.writeUInt32LE(0xf0000011,0);bytes.writeUInt32LE(types.length,4);bytes.writeUInt32LE(entries.length,8);
  bytes.writeBigUInt64LE(BigInt(bytes.length),32);
  types.forEach((type,index)=>{
    const typed=entries.filter(entry=>entry.type===type),at=72+32*index;
    typed[0].typeHeader.copy(bytes,at);
    bytes.writeBigUInt64LE(BigInt(typed.length),at+16);
  });
  entries.forEach((entry,index)=>{
    const at=header+80*index;
    bytes.writeBigUInt64LE(entry.id,at);bytes.writeBigUInt64LE(entry.type,at+8);
    bytes.writeBigUInt64LE(BigInt(entry.offset),at+16);
    bytes.writeBigUInt64LE(BigInt(entry.streamOffset),at+24);bytes.writeBigUInt64LE(BigInt(entry.gpuOffset),at+32);
    entry.metadata.copy(bytes,at+40);
    bytes.writeUInt32LE(entry.data.length,at+56);bytes.writeUInt32LE(entry.stream.length,at+60);
    bytes.writeUInt32LE(entry.gpu.length,at+64);bytes.writeUInt32LE(entry.alignment,at+68);
    bytes.writeUInt32LE(entry.gpuAlignment,at+72);bytes.writeUInt32LE(index,at+76);
    entry.data.copy(bytes,entry.offset);entry.gpu.copy(gpu,entry.gpuOffset);entry.stream.copy(stream,entry.streamOffset);
  });
  return {bytes,gpu,stream};
}
module.exports = {load,merge};
