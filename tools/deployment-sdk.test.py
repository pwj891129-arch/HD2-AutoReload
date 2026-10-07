"""Verify the unified deployment through HD2SDK's real archive and texture serializers."""
import ast
import importlib
import io
import json
import math
import struct
import sys
import types
from pathlib import Path

from PIL import Image

sys.dont_write_bytecode = True
root = Path(__file__).resolve().parent.parent
sdk = root.parent / 'HD2SDK-CommunityEdition'
for name, directory in [('offline_sdk', sdk), ('offline_sdk.utils', sdk / 'utils'),
                        ('offline_sdk.stingray', sdk / 'stingray')]:
    module = types.ModuleType(name)
    module.__path__ = [str(directory)]
    sys.modules[name] = module
Stream = importlib.import_module('offline_sdk.utils.memoryStream').MemoryStream
Texture = importlib.import_module('offline_sdk.stingray.texture').StingrayTexture

# Load the SDK's format classes without its Blender UI or import-time side effects.
tree = ast.parse((sdk / '__init__.py').read_text(encoding='utf-8'))
classes = []
for node in tree.body:
    if isinstance(node, ast.ClassDef) and node.name in ('TocEntry', 'TocFileType'):
        node.body = [method for method in node.body if isinstance(method, ast.FunctionDef)
                     and method.name in ('__init__', 'Serialize', 'SerializeData')]
        classes.append(node)
namespace = {'MemoryStream': Stream, 'ceil': math.ceil}
exec(compile(ast.Module(body=classes, type_ignores=[]), str(sdk / '__init__.py'), 'exec'), namespace)

report = json.loads((root / 'dist/build-report.json').read_text(encoding='utf-8'))
stage = Path(report['stage'])
file = stage / '9ba626afa44a3aa3.patch_0'
raw = file.read_bytes()
gpu_bytes = Path(str(file) + '.gpu_resources').read_bytes()
assert struct.unpack_from('<III', raw) == (0xf0000011, 2, 48)
main, gpu, stream = Stream(raw), Stream(gpu_bytes), Stream(b'')
main.seek(72)
types_read = [namespace['TocFileType']().Serialize(main) for _ in range(2)]
assert sorted(row.NumFiles for row in types_read) == [1, 47]
entries = [namespace['TocEntry']().Serialize(main) for _ in range(48)]
assert len({(entry.FileID, entry.TypeID) for entry in entries}) == 48
for index, entry in enumerate(entries):
    assert entry.EntryIndex == index
    entry.SerializeData(main, gpu, stream)
    assert len(entry.TocData) == entry.TocDataSize
    assert entry.TocDataOffset % 16 == 0
    assert entry.GpuResourceOffset % 64 == 0

defaults = json.loads((stage / 'manifest.json').read_text(encoding='utf-8'))
assert 'Options' not in defaults and 'Include' not in defaults
settings = json.loads((root / 'dist/menu-schema.json').read_text(encoding='utf-8'))
lua_type = 0xa14e8dfa2cd117e2
lua = [bytes(entry.TocData)[8:].decode('utf-8') for entry in entries if entry.TypeID == lua_type]
assert len(lua) == 47
assert sum(text.startswith('-- HD2-Addon: mods/hd2_helper/auto_reload\n') for text in lua) == 1
assert sum(text.startswith('return ') for text in lua) == len(settings) == 46
font_entry = next(entry for entry in entries if entry.TypeID != lua_type)
font = Texture()
font.Serialize(Stream(font_entry.TocData), Stream(font_entry.GpuData), Stream(font_entry.StreamData))
assert (font.Width, font.Height, font.NumMipMaps, font.ArraySize, font.Format) == (2048, 1024, 12, 1, 'R8G8B8A8_UNORM')
assert Image.open(io.BytesIO(font.ToDDS())).tobytes() == Image.open(root / 'assets/wheel-glyphs.png').tobytes()

# Every preserved default must have exactly the same bytes in the deployment.
merged = {(entry.FileID, entry.TypeID): entry for entry in entries}
hidden = json.loads((stage / 'arsenal-options.hidden.json').read_text(encoding='utf-8'))['en']['Options']
folders = ['Core']
for option in hidden:
    folders.extend(option.get('Include', option.get('SubOptions', [{}])[0].get('Include', []))[1:])
for folder in folders:
    for original in (stage / folder).glob('*.patch_*'):
        if original.suffix in ('.stream', '.gpu_resources'):
            continue
        packed = original.read_bytes()
        at = 72 + 32 * struct.unpack_from('<I', packed, 4)[0]
        toc = Stream(packed); toc.seek(at)
        entry = namespace['TocEntry']().Serialize(toc)
        entry.SerializeData(toc, Stream(Path(str(original) + '.gpu_resources').read_bytes()),
                            Stream(Path(str(original) + '.stream').read_bytes()))
        target = merged[(entry.FileID, entry.TypeID)]
        assert (entry.TocData, entry.GpuData, entry.StreamData) == (target.TocData, target.GpuData, target.StreamData)
print('PASS actual HD2SDK: 48 merged assets, default settings, typed headers, alignments and Korean glyph DDS pixels')
