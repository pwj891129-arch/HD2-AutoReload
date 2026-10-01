import importlib
import io
import struct
import sys
import types
from pathlib import Path

from PIL import Image

root = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
sdk = root.parent / "HD2SDK-CommunityEdition"
for name, directory in [("offline_sdk", sdk), ("offline_sdk.utils", sdk / "utils"), ("offline_sdk.stingray", sdk / "stingray")]:
    module = types.ModuleType(name)
    module.__path__ = [str(directory)]
    sys.modules[name] = module
Texture = importlib.import_module("offline_sdk.stingray.texture").StingrayTexture
Stream = importlib.import_module("offline_sdk.utils.memoryStream").MemoryStream
for language in ["en", "ko"]:
    file = root / f"dist/HD2-AutoReload-0.3.44-test-{language}/Core/9ba626afa44a3aa3.patch_56"
    packed = file.read_bytes()
    offset, size = struct.unpack_from("<Q", packed, 120)[0], struct.unpack_from("<I", packed, 160)[0]
    main, gpu = packed[offset:offset + size], Path(str(file) + ".gpu_resources").read_bytes()
    texture = Texture()
    texture.Serialize(Stream(main), Stream(gpu), Stream())
    assert (texture.Width, texture.Height, texture.NumMipMaps, texture.ArraySize, texture.Format) == (2048, 1024, 12, 1, "R8G8B8A8_UNORM")
    image = Image.open(io.BytesIO(texture.ToDDS()))
    assert image.tobytes() == Image.open(root / "assets/wheel-glyphs.png").tobytes()
    output, output_gpu, output_stream = Stream(IOMode="write"), Stream(IOMode="write"), Stream(IOMode="write")
    texture.Serialize(output, output_gpu, output_stream)
    assert bytes(output.Data) == main and bytes(output_gpu.Data) == gpu and not output_stream.Data
print("PASS actual HD2SDK texture deserialization, DDS pixels and byte-identical serialization for both language packages")
