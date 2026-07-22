#!/usr/bin/env python3
"""Convert a sparse raw image into Android sparse image format."""

import argparse
import os
import struct

MAGIC = 0xED26FF3A
RAW = 0xCAC1
DONT_CARE = 0xCAC3
BLOCK_SIZE = 4096


def data_ranges(fd, size):
    block_count = (size + BLOCK_SIZE - 1) // BLOCK_SIZE
    cursor = 0
    ranges = []
    while cursor < size:
        try:
            start = os.lseek(fd, cursor, os.SEEK_DATA)
        except OSError:
            break
        end = os.lseek(fd, start, os.SEEK_HOLE)
        first = start // BLOCK_SIZE
        last = min(block_count, (end + BLOCK_SIZE - 1) // BLOCK_SIZE)
        if ranges and first <= ranges[-1][1]:
            ranges[-1] = (ranges[-1][0], max(ranges[-1][1], last))
        else:
            ranges.append((first, last))
        cursor = end
    return block_count, ranges


def write_chunk_header(output, chunk_type, blocks, payload_size=0):
    output.write(struct.pack("<HHII", chunk_type, 0, blocks, 12 + payload_size))


def convert(source_path, output_path):
    with open(source_path, "rb") as source:
        size = os.fstat(source.fileno()).st_size
        total_blocks, ranges = data_ranges(source.fileno(), size)
        chunks = len(ranges) * 2 + 1
        if ranges and ranges[0][0] == 0:
            chunks -= 1
        if ranges and ranges[-1][1] == total_blocks:
            chunks -= 1

        with open(output_path, "wb") as output:
            output.write(
                struct.pack(
                    "<IHHHHIIII",
                    MAGIC,
                    1,
                    0,
                    28,
                    12,
                    BLOCK_SIZE,
                    total_blocks,
                    chunks,
                    0,
                )
            )
            cursor = 0
            for first, last in ranges:
                if first > cursor:
                    write_chunk_header(output, DONT_CARE, first - cursor)
                blocks = last - first
                payload_size = blocks * BLOCK_SIZE
                write_chunk_header(output, RAW, blocks, payload_size)
                source.seek(first * BLOCK_SIZE)
                remaining = payload_size
                while remaining:
                    data = source.read(min(8 * 1024 * 1024, remaining))
                    if not data:
                        data = b"\0" * min(8 * 1024 * 1024, remaining)
                    output.write(data)
                    remaining -= len(data)
                cursor = last
            if cursor < total_blocks:
                write_chunk_header(output, DONT_CARE, total_blocks - cursor)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("raw_image")
    parser.add_argument("sparse_image")
    args = parser.parse_args()
    convert(args.raw_image, args.sparse_image)


if __name__ == "__main__":
    main()
