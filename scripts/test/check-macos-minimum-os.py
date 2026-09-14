#!/usr/bin/env python3
"""Check every Mach-O slice in an app for its declared macOS minimum."""
import argparse
from pathlib import Path
import plistlib
import struct

ARM64 = 0x0100000C
MACH = {b"\xcf\xfa\xed\xfe": ("<", 32), b"\xfe\xed\xfa\xcf": (">", 32),
        b"\xce\xfa\xed\xfe": ("<", 28), b"\xfe\xed\xfa\xce": (">", 28)}
FAT = {b"\xca\xfe\xba\xbe": (">", False), b"\xbe\xba\xfe\xca": ("<", False),
       b"\xca\xfe\xba\xbf": (">", True), b"\xbf\xba\xfe\xca": ("<", True)}


def version(value):
    parts = value.split('.')
    if not 1 <= len(parts) <= 3 or any(not p.isdigit() for p in parts):
        raise ValueError('Invalid macOS version')
    result = tuple(map(int, parts)) + (0,) * (3-len(parts))
    if result[0] > 65535 or any(v > 255 for v in result[1:]):
        raise ValueError('macOS version out of range')
    return result


def slices(data, nested=False):
    magic = bytes(data[:4])
    if magic in FAT:
        if nested or len(data) < 8:
            raise ValueError('Malformed universal Mach-O')
        endian, wide = FAT[magic]
        count = struct.unpack_from(endian+'I', data, 4)[0]
        width = 32 if wide else 20
        if not count or count > 64 or 8+count*width > len(data):
            raise ValueError('Malformed Mach-O architecture table')
        result = []
        intervals = []
        for n in range(count):
            pos = 8+n*width
            cpu = struct.unpack_from(endian+'I', data, pos)[0]
            offset, size = struct.unpack_from(endian+('QQ' if wide else 'II'), data, pos+8)
            if offset < 8+count*width or size < 28 or offset+size > len(data):
                raise ValueError('Mach-O slice outside file')
            if any(offset < end and offset+size > start for start,end in intervals):
                raise ValueError('Overlapping Mach-O slices')
            intervals.append((offset,offset+size))
            child = slices(data[offset:offset+size], True)
            if len(child) != 1 or child[0][0] != cpu:
                raise ValueError('Mach-O architecture table disagrees with slice')
            result.extend(child)
        return result
    if magic not in MACH:
        return []
    endian, header = MACH[magic]
    if len(data) < header:
        raise ValueError('Truncated Mach-O header')
    cpu, subtype, filetype, count, size = struct.unpack_from(endian+'IIIII', data, 4)
    if not count or count > size//8 or header+size > len(data):
        raise ValueError('Malformed Mach-O load commands')
    pos = header
    minimums = []
    for _ in range(count):
        if pos+8 > header+size:
            raise ValueError('Truncated Mach-O load command')
        command, length = struct.unpack_from(endian+'II', data, pos)
        if length < 8 or length % 4 or pos+length > header+size:
            raise ValueError('Invalid Mach-O load command length')
        if command == 0x32:  # LC_BUILD_VERSION
            if length < 24:
                raise ValueError('Truncated LC_BUILD_VERSION')
            platform, minimum, sdk, tools = struct.unpack_from(endian+'IIII',data,pos+8)
            if platform != 1 or length < 24+tools*8:
                raise ValueError('Not a valid macOS build version')
            minimums.append(minimum)
        elif command == 0x24:  # LC_VERSION_MIN_MACOSX
            if length < 16:
                raise ValueError('Truncated LC_VERSION_MIN_MACOSX')
            minimums.append(struct.unpack_from(endian+'I',data,pos+8)[0])
        pos += length
    if pos != header+size or len(minimums) != 1:
        raise ValueError('Missing or ambiguous macOS minimum')
    value = minimums[0]
    return [(cpu, (value >> 16, (value >> 8) & 255, value & 255))]


def check(app, target):
    app = app.resolve(strict=True)
    expected = version(target)
    plist = plistlib.loads((app/'Contents/Info.plist').read_bytes())
    if version(plist.get('LSMinimumSystemVersion','')) != expected:
        raise ValueError('App plist does not match selected deployment target')
    executable = app/'Contents/MacOS'/plist['CFBundleExecutable']
    if not executable.is_file() or not slices(executable.read_bytes()):
        raise ValueError('Missing Mach-O app executable')
    count = 0
    for path in app.rglob('*'):
        if path.is_symlink() and not path.resolve().is_relative_to(app):
            raise ValueError('Bundle symlink escapes app')
        if not path.is_file() or path.is_symlink():
            continue
        found = slices(path.read_bytes())
        if not found:
            continue
        if not any(cpu == ARM64 for cpu,_ in found):
            raise ValueError('Bundled Mach-O has no arm64 slice: '+str(path.relative_to(app)))
        if any(minimum > expected for _,minimum in found):
            raise ValueError('Bundled Mach-O requires a newer OS: '+str(path.relative_to(app)))
        count += 1
    if not count:
        raise ValueError('No bundled Mach-O files inspected')
    return count


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app',type=Path)
    parser.add_argument('target')
    args=parser.parse_args()
    try:
        count=check(args.app,args.target)
    except (OSError,KeyError,ValueError,struct.error,plistlib.InvalidFileException) as exc:
        parser.exit(1, 'macos_minimum_os_gate=FAIL '+str(exc)+'\n')
    print(f'macos_minimum_os_gate=PASS binaries={count} target={args.target}')
