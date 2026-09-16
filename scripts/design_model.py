from __future__ import annotations

from dataclasses import dataclass


BYTES_PER_BEAT = 8
PAGE_BYTES = 4096
SUPPORTED_BURSTS = {1, 2, 4, 8, 16}


@dataclass(frozen=True)
class Burst:
    source_address: int
    destination_address: int
    beats: int

    @property
    def byte_count(self) -> int:
        return self.beats * BYTES_PER_BEAT


def ranges_overlap(source_address: int, destination_address: int, length: int) -> bool:
    return source_address < destination_address + length and destination_address < source_address + length


def validate_descriptor(source_address: int, destination_address: int, length: int, burst_beats: int) -> None:
    if length == 0:
        raise ValueError("zero length")
    if any(value % BYTES_PER_BEAT for value in (source_address, destination_address, length)):
        raise ValueError("unaligned descriptor")
    if length > 0xFFFFFF:
        raise ValueError("length exceeds v1 field")
    if ranges_overlap(source_address, destination_address, length):
        raise ValueError("overlapping regions")
    if burst_beats not in SUPPORTED_BURSTS:
        raise ValueError("unsupported burst length")


def plan_bursts(source_address: int, destination_address: int, length: int, burst_beats: int) -> list[Burst]:
    validate_descriptor(source_address, destination_address, length, burst_beats)
    bursts: list[Burst] = []
    remaining = length
    source = source_address
    destination = destination_address
    while remaining:
        source_page_beats = (PAGE_BYTES - source % PAGE_BYTES) // BYTES_PER_BEAT
        destination_page_beats = (PAGE_BYTES - destination % PAGE_BYTES) // BYTES_PER_BEAT
        beats = min(remaining // BYTES_PER_BEAT, burst_beats, source_page_beats, destination_page_beats)
        bursts.append(Burst(source, destination, beats))
        bytes_planned = beats * BYTES_PER_BEAT
        source += bytes_planned
        destination += bytes_planned
        remaining -= bytes_planned
    return bursts


def crc32(data: bytes) -> int:
    crc = 0xFFFFFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = ((crc >> 1) ^ 0xEDB88320) if crc & 1 else crc >> 1
    return (~crc) & 0xFFFFFFFF
