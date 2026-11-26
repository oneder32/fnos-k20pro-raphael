#!/usr/bin/env python3
# Repack the K20 Pro boot.img:
#   - replace the initramfs init with tools/init_script.sh
#   - hostname "trim" / hosts 127.0.0.1 (created if absent)
#   - add Bluetooth modules-load entry
# The init script discovers the root partition in this priority:
#   1. partition labeled / named "fnos" (LABEL/PARTLABEL/PARTNAME=fnos)
#   2. fixed slot /dev/sda35
import os, struct, hashlib, lzma

base = os.environ.get('FNOS_BASE', os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
build = os.path.join(base, 'build')
dist = os.environ.get('FNOS_DIST', os.path.join(base, 'dist'))
os.makedirs(dist, exist_ok=True)

BOOT_SRC = os.environ.get('BOOT_SRC', os.path.join(build, 'boot_base.img'))
CPIO_SRC = os.environ.get('CPIO_SRC', os.path.join(build, 'initramfs.cpio'))
OUT = os.environ.get('BOOT_OUT', os.path.join(dist, 'boot_fnos_k20pro.img'))

CPIO_MAGIC = b'070701'

def parse_newc(cpio: bytes):
    entries = []
    i = 0
    while i + 110 <= len(cpio):
        assert cpio[i:i+6] == CPIO_MAGIC, ('bad magic at', i, cpio[i:i+6])
        hdr = cpio[i:i+110]
        def field(off):
            return int(hdr[off:off+8], 16)
        namesize = field(94)
        filesize = field(54)
        name_raw = cpio[i+110:i+110+namesize]
        name_clean = name_raw.rstrip(b'\x00')
        dataoff = i + 110 + namesize
        dataoff = (dataoff + 3) & ~3
        data = cpio[dataoff:dataoff+filesize]
        entries.append(dict(
            ino=field(6), mode=field(14), uid=field(22), gid=field(30),
            nlink=field(38), mtime=field(46), filesize=filesize,
            devmajor=field(62), devminor=field(70), rdevmajor=field(78),
            rdevminor=field(86), namesize=namesize, check=field(102),
            name=name_clean, data=data))
        if name_clean == b'TRAILER!!!':
            break
        i = dataoff + filesize
        i = (i + 3) & ~3
    return entries

def serialize_newc(entries):
    out = bytearray()
    for e in entries:
        filesize = len(e['data'])
        namesize = len(e['name']) + 1
        fields = [e['ino'], e['mode'], e['uid'], e['gid'], e['nlink'],
                  e['mtime'], filesize, e['devmajor'], e['devminor'],
                  e['rdevmajor'], e['rdevminor'], namesize, 0]
        hdr = CPIO_MAGIC + b''.join(('%08X' % f).encode('ascii') for f in fields)
        assert len(hdr) == 110
        out += hdr
        out += e['name'] + b'\x00'
        while len(out) % 4:
            out += b'\x00'
        out += e['data']
        while len(out) % 4:
            out += b'\x00'
    return bytes(out)

def align(x, n):
    return (x + n - 1) // n * n

# ---- 1. Patch initramfs ----
cpio = open(CPIO_SRC, 'rb').read()
entries = parse_newc(cpio)
print('parsed cpio entries:', len(entries))

by_name = {e['name']: e for e in entries}
trailer_idx = next(i for i, e in enumerate(entries) if e['name'] == b'TRAILER!!!')

def ensure_file(name: bytes, mode: int, data: bytes):
    if name in by_name:
        by_name[name]['data'] = data
        by_name[name]['mode'] = mode
        print('updated', name.decode())
    else:
        entry = dict(ino=0, mode=mode, uid=0, gid=0, nlink=1, mtime=0,
                     devmajor=0, devminor=0, rdevmajor=0, rdevminor=0,
                     name=name, data=data)
        entries.insert(trailer_idx, entry)
        by_name[name] = entry
        print('added', name.decode())

# init script
new_init = open(os.path.join(base, 'tools', 'init_script.sh'), 'rb').read()
new_init = new_init.replace(b'\r\n', b'\n')
if not new_init.endswith(b'\n'):
    new_init += b'\n'
assert b'init' in by_name, 'init entry missing in ramdisk'
old_init = by_name[b'init']['data']
by_name[b'init']['data'] = new_init
print('init: replaced whole script, size %d -> %d' % (len(old_init), len(new_init)))

# hostname / hosts (created if absent)
ensure_file(b'etc/hostname', 0o100644, b'trim\n')
ensure_file(b'etc/hosts', 0o100644, b'127.0.0.1 localhost trim\n')

# Bluetooth auto-load
bt_conf = (b'# K20 Pro (raphael) Bluetooth: WCN3990 via UART (btqca + hci_uart)\n'
           b'bluetooth\nhci_uart\nbtqca\nrfcomm\n')
ensure_file(b'etc/modules-load.d/raphael-bt.conf', 0o100644, bt_conf)

new_cpio = serialize_newc(entries)
# round-trip verify
rt = parse_newc(new_cpio)
assert len(rt) == len(entries), (len(rt), len(entries))
rt_init = next(e for e in rt if e['name'] == b'init')['data']
assert rt_init.count(b'sda31') == 0, 'old sda31 reference still present'
for tok in (b'/dev/sda35', b'/dev/block/sda35', b'/dev/mmcblk0p35'):
    assert tok in rt_init, tok
# new dual-candidate logic present
for tok in (b'is_fnos_dev', b'PARTNAME=fnos', b'FNOS_DEV', b'ROOT_SRC'):
    assert tok in rt_init, tok
rt_host = next(e for e in rt if e['name'] == b'etc/hostname')['data']
assert rt_host == b'trim\n'
print('round-trip OK; initramfs size %d -> %d' % (len(cpio), len(new_cpio)))

open(os.path.join(build, 'initramfs_new.cpio'), 'wb').write(new_cpio)

ramdisk = lzma.compress(new_cpio, format=lzma.FORMAT_XZ,
                        check=lzma.CHECK_CRC32, preset=6)
open(os.path.join(build, 'ramdisk_new.xz'), 'wb').write(ramdisk)
assert lzma.decompress(ramdisk) == new_cpio
print('new ramdisk (xz) size:', len(ramdisk))

# ---- 2. Reassemble boot.img ----
boot = open(BOOT_SRC, 'rb').read()
kernel_size = struct.unpack('<I', boot[8:12])[0]
page_size = struct.unpack('<I', boot[36:40])[0]
hdr_version = struct.unpack('<I', boot[40:44])[0]
print('orig: kernel_size=%d page_size=%d hdr_version=%d' % (kernel_size, page_size, hdr_version))

kernel = boot[page_size:page_size + kernel_size]
assert kernel[:2] == b'\x1f\x8b' and kernel.find(bytes.fromhex('d00dfeed')) > 0

header_page = bytearray(boot[:page_size])
struct.pack_into('<I', header_page, 16, len(ramdisk))  # ramdisk_size @16
cmd = (b'clk_ignore_unused pd_ignore_unused arm64.nopauth root=/dev/sda35 rw '
       b'rootwait quiet splash loglevel=3 systemd.show_status=false '
       b'rd.udev.log_level=3 vt.global_cursor_default=0 panic=100 console=tty0')
assert len(cmd) <= 512
header_page[64:64+512] = b'\x00' * 512
header_page[64:64+len(cmd)] = cmd
sha = hashlib.sha1(kernel + ramdisk).digest()
header_page[576:576+32] = b'\x00' * 32
header_page[576:576+20] = sha

new_boot = (bytes(header_page)
            + kernel + b'\x00' * (align(kernel_size, page_size) - kernel_size)
            + ramdisk + b'\x00' * (align(len(ramdisk), page_size) - len(ramdisk)))
open(OUT, 'wb').write(new_boot)
print('wrote', OUT, 'size', len(new_boot))

# ---- 3. Verify ----
nb = open(OUT, 'rb').read()
ks2 = struct.unpack('<I', nb[8:12])[0]
rs2 = struct.unpack('<I', nb[16:20])[0]
assert ks2 == kernel_size and rs2 == len(ramdisk), (ks2, rs2)
k2 = nb[page_size:page_size+ks2]
assert k2 == kernel, 'kernel changed!'
r2 = nb[page_size + align(ks2, page_size): page_size + align(ks2, page_size) + rs2]
assert r2 == ramdisk, 'ramdisk changed!'
cmd2 = nb[64:64+512].split(b'\x00')[0]
assert b'sda35' in cmd2 and b'sda31' not in cmd2, cmd2
print('verification OK: cmdline=%s' % cmd2.decode())
print('DONE')
