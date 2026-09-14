#pragma once
#include <cstring>

// Shared by the live decode probe and portable negative tests. Integer metadata
// follows FFmpeg's public codec/profile/color enums; hardware is the VT query.
struct DecodeFormat {
    const char* codec;
    int profile, width, height, depth, chromaW, chromaH, matrix, range;
};

inline const char* decodeMismatch(const DecodeFormat& expected,
                                 const DecodeFormat& observed,
                                 bool requireHardware, int hardwareStatus)
{
    if (requireHardware && hardwareStatus != 1) return "hardware_attestation";
    if (!observed.codec || std::strcmp(expected.codec, observed.codec)) return "codec";
    if (expected.profile != observed.profile) return "profile";
    if (expected.width != observed.width || expected.height != observed.height) return "dimensions";
    if (expected.depth != observed.depth) return "bit_depth";
    if (expected.chromaW != observed.chromaW || expected.chromaH != observed.chromaH) return "chroma";
    if (expected.matrix != observed.matrix) return "matrix";
    if (expected.range != observed.range) return "range";
    return nullptr;
}
