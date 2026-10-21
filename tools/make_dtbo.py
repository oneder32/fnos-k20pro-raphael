#!/usr/bin/env python3
# Build a structurally-valid DTBO image from the raphael device tree.
# Note: mainline Linux on sm8150 boots the kernel-appended DTB, so this dtbo
# is provided mainly as a valid replacement for the empty dtbo.img.
import os, struct

base = r'E:\DeepSeek Harness\fnos'
work = os.path.join(base, 'work')
dist = os.path.join(base, 'dist')
os.makedirs(dist, exist_ok=True)

DT_TABLE_MAGIC = 0xd7b7ab1e
PAGE = 4096

dtb = open(os.path.join(work, 'dtb'), 'rb').read()
assert dtb[:4] == bytes.fromhex('d00dfeed'), 'not a valid FDT'
total_size = struct.unpack('>I', dtb[4:8])[0]
assert total_size == len(dtb), (total_size, len(dtb))
print('dtb size:', len(dtb))

# also save the plain dtb for reference
open(os.path.join(dist, 'sm8150-xiaomi-raphael.dtb'), 'wb').write(dtb)

HEADER_SIZE = 32
ENTRY_SIZE = 32
ENTRY_COUNT = 1
entries_offset = HEADER_SIZE
dt_offset = PAGE  # 8-byte aligned, safe for FDT

total = (dt_offset + len(dtb) + PAGE - 1) // PAGE * PAGE

def u32(x):
    return struct.pack('<I', x)

hdr = (u32(DT_TABLE_MAGIC) + u32(total) + u32(HEADER_SIZE) + u32(ENTRY_SIZE)
       + u32(ENTRY_COUNT) + u32(entries_offset) + u32(PAGE) + u32(0))
assert len(hdr) == HEADER_SIZE

entry = (u32(len(dtb)) + u32(dt_offset) + u32(0) + u32(0)
         + u32(0) + u32(0) + u32(0) + u32(0))
assert len(entry) == ENTRY_SIZE

out = bytearray()
out += hdr
out += entry
out += b'\x00' * (entries_offset - len(out))  # pad to entries_offset (already 64 == header+entry)
# pad to dt_offset
out += b'\x00' * (dt_offset - len(out))
out += dtb
out += b'\x00' * (total - len(out))
out = bytes(out)

out_path = os.path.join(dist, 'dtbo.img')
open(out_path, 'wb').write(out)
print('wrote', out_path, 'size', len(out), 'total_size field', total)

# verify
v = open(out_path, 'rb').read()
assert struct.unpack('<I', v[0:4])[0] == DT_TABLE_MAGIC
assert struct.unpack('<I', v[4:8])[0] == total
assert v[dt_offset:dt_offset+4] == bytes.fromhex('d00dfeed')
assert v[dt_offset:dt_offset+len(dtb)] == dtb
print('verification OK')
