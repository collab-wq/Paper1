#!/usr/bin/env python3
"""Fetch six XJTU-SY Bearing1_1 snapshots without storing the 5.45 GB ZIP.

ZIP64 range-reader structure adapted from Serhii Zabolotnii's MIT-licensed
fetch_xjtu_sy.py (2026), https://github.com/SZabolotnii/DSGE_PIF-code-supplement.
The full copyright and permission notice is in XJTU_RANGE_LICENSE.txt.
"""
import argparse
import hashlib
import json
import os
import struct
import time
import urllib.request
import zlib

URL = ("https://huggingface.co/datasets/DavidNguyen/XJTU-SY_Bearing_Datasets/"
       "resolve/main/XJTU-SY_Bearing_Datasets.zip")
AUTHOR = "https://github.com/WangBiaoXJTU/xjtu-sy-bearing-datasets"
CHOSEN = {
    1: "4ea9ab4171bccfc3ec7a1764b44f20f5116cdb3570334c853e076cb1ba6359fb",
    2: "f8f33a3a0189c2f83c7c16c6e3657fdc9bdd65ac2265245a6eb7c93044aa124c",
    69: "088757a8df96a783730cae71f2c2e372412cd314b6375fa2daa22f6d8218ef43",
    82: "50e9650b99d25d00304af7350c9052234a2960506c92f6ba5398b164622b4fa1",
    109: "b6613612cf4597775d5bad7f19652dcf04e79420ae9a81a2f230a2fcb32b40de",
    123: "ba5d019a4bec62541c51b04e5a62c9aae2f6fb10d78eb5b771253f1a24f53907",
}


def request_range(start, end):
    for attempt in range(4):
        try:
            req = urllib.request.Request(URL, headers={
                "Range": f"bytes={start}-{end}", "User-Agent": "Paper1-XJTU-archive"})
            with urllib.request.urlopen(req, timeout=120) as response:
                data = response.read()
                assert response.status == 206 and len(data) == end - start + 1, (
                    "Mirror did not honor HTTP range request")
                return data
        except Exception:
            if attempt == 3:
                raise
            time.sleep(2 * (attempt + 1))


def directory():
    req = urllib.request.Request(URL, method="HEAD")
    with urllib.request.urlopen(req, timeout=60) as response:
        size = int(response.headers.get("x-linked-size") or
                   response.headers["Content-Length"])
    tail = request_range(max(0, size - 66000), size - 1)
    pos = tail.rfind(b"PK\x05\x06")
    assert pos >= 0, "ZIP end record missing"
    count = struct.unpack_from("<H", tail, pos + 10)[0]
    cd_size, cd_offset = struct.unpack_from("<II", tail, pos + 12)
    zip64 = tail.rfind(b"PK\x06\x06")
    if zip64 >= 0:
        count, cd_size, cd_offset = struct.unpack_from("<QQQ", tail, zip64 + 32)
    central = request_range(cd_offset, cd_offset + cd_size - 1)
    entries, p = {}, 0
    while p + 46 <= len(central) and central[p:p + 4] == b"PK\x01\x02":
        values = struct.unpack_from("<IHHHHHHIIIHHHHHII", central, p)
        method, crc, csize, usize = values[4], values[7], values[8], values[9]
        name_len, extra_len, comment_len, offset = values[10], values[11], values[12], values[16]
        name = central[p + 46:p + 46 + name_len].decode("utf-8", "replace")
        extra = central[p + 46 + name_len:p + 46 + name_len + extra_len]
        if 0xFFFFFFFF in (csize, usize, offset):
            e = 0
            while e + 4 <= len(extra):
                tag, length = struct.unpack_from("<HH", extra, e)
                if tag == 1:
                    vals = iter(struct.unpack_from("<" + "Q" * (length // 8), extra, e + 4))
                    if usize == 0xFFFFFFFF: usize = next(vals)
                    if csize == 0xFFFFFFFF: csize = next(vals)
                    if offset == 0xFFFFFFFF: offset = next(vals)
                    break
                e += 4 + length
        entries[name.replace("\\", "/")] = (method, crc, csize, usize, offset)
        p += 46 + name_len + extra_len + comment_len
    assert len(entries) == count, f"ZIP directory: {len(entries)} != {count} entries"
    return size, entries


def member(entry):
    method, crc, csize, usize, offset = entry
    header = request_range(offset, offset + 29)
    assert header[:4] == b"PK\x03\x04", "ZIP member header missing"
    name_len, extra_len = struct.unpack_from("<HH", header, 26)
    first = offset + 30 + name_len + extra_len
    compressed = request_range(first, first + csize - 1)
    if method == 0:
        data = compressed
    elif method == 8:
        data = zlib.decompress(compressed, -zlib.MAX_WBITS)
    else:
        raise ValueError(f"Unsupported ZIP compression method {method}")
    assert len(data) == usize and zlib.crc32(data) & 0xFFFFFFFF == crc, (
        "ZIP member size or CRC mismatch")
    return data


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fetch", action="store_true")
    parser.add_argument("--dest", default="input/xjtu-sy")
    args = parser.parse_args()
    size, entries = directory()
    assert size == 5447931446, f"Unexpected archive size {size}"
    selected = {}
    for index in CHOSEN:
        matches = [(name, entry) for name, entry in entries.items() if
                   name.endswith(f"/35Hz12kN/Bearing1_1/{index}.csv") or
                   name == f"35Hz12kN/Bearing1_1/{index}.csv"]
        assert len(matches) == 1, f"Snapshot {index} missing or ambiguous"
        selected[index] = matches[0]
    print(f"Archive {size} bytes, {len(entries)} members", flush=True)
    for index, (name, entry) in selected.items():
        print(f"SELECT {index} {name} {entry[3]} bytes", flush=True)
    if not args.fetch:
        return
    dest = os.path.join(args.dest, "35Hz12kN", "Bearing1_1")
    os.makedirs(dest, exist_ok=True)
    provenance = {"author_entry": AUTHOR, "mirror": URL, "archive_bytes": size,
                  "sampling_hz": 25600, "snapshots": {}}
    for index, (name, entry) in selected.items():
        data = member(entry)
        digest = hashlib.sha256(data).hexdigest()
        assert digest == CHOSEN[index], f"SHA-256 mismatch: {name}"
        with open(os.path.join(dest, f"{index}.csv"), "wb") as out:
            out.write(data)
        provenance["snapshots"][str(index)] = {
            "zip_member": name, "sha256": digest, "bytes": len(data)}
        print(f"VERIFIED {index} {digest} {len(data)} bytes", flush=True)
    with open(os.path.join(args.dest, "provenance.json"), "w") as out:
        json.dump(provenance, out, indent=2)


if __name__ == "__main__":
    main()
