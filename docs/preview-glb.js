/* Browser-only conversion. Original game GLBs and textures are never modified. */
async function makeBrowserPreview(bytes, sourceURL, fetchBytes) {
  const v=new DataView(bytes), decoder=new TextDecoder();
  if(v.getUint32(0,true)!==0x46546c67||v.getUint32(4,true)!==2)throw Error('Not a glTF 2 GLB');
  let json,bin=new Uint8Array();
  for(let o=12;o<bytes.byteLength;){const n=v.getUint32(o,true),t=v.getUint32(o+4,true);if(t===0x4e4f534a)json=JSON.parse(decoder.decode(new Uint8Array(bytes,o+8,n)));if(t===0x004e4942)bin=new Uint8Array(bytes.slice(o+8,o+8+n));o+=8+n;}
  if(!json)throw Error('GLB JSON chunk is missing');
  if((json.buffers||[]).some(b=>b.uri))throw Error('External geometry buffers are not supported in this preview');
  // Godot turns these into collision shapes; standard glTF viewers draw them.
  let hidden=0;
  for(const node of json.nodes||[])if(/-(?:conv)?colonly$/i.test(node.name||'')){delete node.mesh;hidden++;}
  const parts=[bin];let offset=bin.length;const align=()=>{const n=(4-offset%4)%4;if(n){parts.push(new Uint8Array(n));offset+=n}};
  let embedded=0;
  for(const image of json.images||[]){if(!image.uri)continue;const url=new URL(image.uri,sourceURL);const data=new Uint8Array(await fetchBytes(url.href));align();const start=offset;parts.push(data);offset+=data.length;json.bufferViews ||= [];image.bufferView=json.bufferViews.length;json.bufferViews.push({buffer:0,byteOffset:start,byteLength:data.length});image.mimeType=data[0]===137?'image/png':'image/jpeg';delete image.uri;embedded++;}
  // Preserve repeat modes, UV transforms, colors, alpha, and PBR properties.
  for(const sampler of json.samplers||[]){sampler.magFilter=9728;sampler.minFilter=9728;}
  align();json.buffers=[{byteLength:offset}];
  const raw=new TextEncoder().encode(JSON.stringify(json)),jn=(raw.length+3)&~3;
  const out=new Uint8Array(12+8+jn+8+offset),dv=new DataView(out.buffer);
  dv.setUint32(0,0x46546c67,true);dv.setUint32(4,2,true);dv.setUint32(8,out.length,true);dv.setUint32(12,jn,true);dv.setUint32(16,0x4e4f534a,true);out.fill(32,20,20+jn);out.set(raw,20);dv.setUint32(20+jn,offset,true);dv.setUint32(24+jn,0x004e4942,true);let o=28+jn;for(const part of parts){out.set(part,o);o+=part.length;}
  return {bytes:out,hidden,embedded};
}
if(typeof module!=='undefined')module.exports={makeBrowserPreview};
