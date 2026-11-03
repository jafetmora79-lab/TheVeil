"""Prepare a Godot 4.3 Web export for static hosting with small file limits.

Usage: python opening/build_web.py /absolute/path/to/export/directory
Run Godot --export-release Web <directory>/index.html first.
"""
import gzip
import pathlib
import sys

root = pathlib.Path(sys.argv[1]).resolve()
for suffix in ("wasm", "pck"):
    source = root / f"index.{suffix}"
    target = root / f"index.{suffix}.bin"
    target.write_bytes(gzip.compress(source.read_bytes(), compresslevel=9, mtime=0))
    source.unlink()
html = root / "index.html"
text = html.read_text()
loader = '''<script>
// Godot's original loader still receives the uncompressed byte stream and MIME.
// The transport files are gzip data with .bin names, avoiding host encoding rules.
document.addEventListener('pointerdown', () => document.getElementById('play-help')?.remove(), {once: true, capture: true});
const nativeFetch = window.fetch.bind(window);
window.fetch = async (input, init) => {
    const url = typeof input === 'string' ? input : input.url;
    const match = /index\\.(wasm|pck)$/.exec(new URL(url, location.href).pathname);
    if (!match) return nativeFetch(input, init);
    if (!('DecompressionStream' in window)) {
        throw new Error('Please use a current desktop Chrome, Edge or Firefox browser.');
    }
    const packed = await nativeFetch(url + '.bin', init);
    if (!packed.ok) throw new Error('Game download failed: ' + packed.status);
    const stream = packed.body.pipeThrough(new DecompressionStream('gzip'));
    return new Response(stream, {headers: {
        'Content-Type': match[1] === 'wasm' ? 'application/wasm' : 'application/octet-stream'
    }});
};
</script>
'''
text = text.replace('<script src="index.js"></script>', loader + '<script src="index.js"></script>')
if loader not in text:
    raise RuntimeError("Godot web shell changed: loader injection point absent")
text = text.replace('<body>', '<body>\n<div id="play-help" style="position:fixed;top:8px;left:50%;transform:translateX(-50%);z-index:10;background:#111d;color:#eee;padding:7px 14px;border-radius:5px;font:14px system-ui;pointer-events:none">Click the game to play • WASD move • Mouse look • E interact • Esc release mouse • R restart</div>')
html.write_text(text)
print('Prepared static browser build:', root)
for file in sorted(root.iterdir()):
    if file.is_file():
        print(file.name, file.stat().st_size)
