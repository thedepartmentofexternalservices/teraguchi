#include "../../apps/client/app/streaming/video/teraguchivideo.h"
#include <cstdio>
#include <cstring>
#include <initializer_list>

static int assertions = 0;
#define CHECK(value) do { ++assertions; if (!(value)) { \
    std::fprintf(stderr, "admission assertion failed at line %d\n", __LINE__); return 1; } } while (0)

struct Parameters {
    DecoderSelectionMode selectionMode = DecoderSelectionMode::PreferExactHardwareThenSoftware;
};

struct Decoder {
    bool hardwareAvailable = true;
    bool softwareAvailable = true;
    bool ignorePolicy = false;
    bool rewritePolicy = false;
    bool activeHardware = false;
    int softwareAttempts = 0;
    bool initialize(Parameters* parameters) {
        if (rewritePolicy) parameters->selectionMode = DecoderSelectionMode::PreferExactHardwareThenSoftware;
        if (hardwareAvailable) { activeHardware = true; return true; }
        if (ignorePolicy || parameters->selectionMode != DecoderSelectionMode::ExactHardwareOnly) {
            ++softwareAttempts;
            activeHardware = false;
            return softwareAvailable;
        }
        return false;
    }
    bool isHardwareAccelerated() { return activeHardware; }
};

int main(int argc, char** argv)
{
    if (argc != 2) return 2;
    const bool strict = std::strcmp(argv[1], "strict") == 0;
    // Exit 12 is the negative control: a build without the policy cannot pass
    // the strict product tests just because hardware happened to be available.
    if (strict != TeraguchiVideo::Required) return 12;
    CHECK(TeraguchiVideo::acceptsCapture(DecoderCaptureSource::NativeX11_10Bit));
    CHECK(TeraguchiVideo::acceptsCapture(DecoderCaptureSource::Nvfbc8Bit) == !strict);
    CHECK(TeraguchiVideo::acceptsCapture(DecoderCaptureSource::ScreenCaptureKit) == !strict);
    CHECK(TeraguchiVideo::acceptsCapture(static_cast<DecoderCaptureSource>(99)) == !strict);
    CHECK(TeraguchiVideo::acceptsFormat(DecoderEncoderBackend::NvencDirect, VIDEO_FORMAT_H265_REXT10_444, true));
    CHECK(TeraguchiVideo::acceptsFormat(DecoderEncoderBackend::SoftwareCuda, VIDEO_FORMAT_H265_REXT10_444, true) == !strict);
    CHECK(TeraguchiVideo::acceptsFormat(DecoderEncoderBackend::VideoToolbox, VIDEO_FORMAT_H265_REXT10_444, true) == !strict);
    for (const int format : {VIDEO_FORMAT_H264_HIGH10_444, VIDEO_FORMAT_H265_REXT8_444,
                            VIDEO_FORMAT_H265_MAIN10, VIDEO_FORMAT_H264, 0}) {
        CHECK(TeraguchiVideo::acceptsFormat(DecoderEncoderBackend::NvencDirect, format, true) == !strict);
    }
    CHECK(TeraguchiVideo::acceptsFormat(DecoderEncoderBackend::NvencDirect, VIDEO_FORMAT_H265_REXT10_444, false) == !strict);
    CHECK(TeraguchiVideo::acceptsStream(VIDEO_FORMAT_H265_REXT10_444, 3840, 2160, 60, 3840, 2160, 60));
    CHECK(TeraguchiVideo::acceptsStream(VIDEO_FORMAT_H265_MAIN10, 3840, 2160, 60, 3840, 2160, 60) == !strict);
    CHECK(TeraguchiVideo::acceptsStream(VIDEO_FORMAT_H265_REXT10_444, 1920, 2160, 60, 3840, 2160, 60) == !strict);
    CHECK(TeraguchiVideo::acceptsStream(VIDEO_FORMAT_H265_REXT10_444, 3840, 1080, 60, 3840, 2160, 60) == !strict);
    CHECK(TeraguchiVideo::acceptsStream(VIDEO_FORMAT_H265_REXT10_444, 3840, 2160, 30, 3840, 2160, 60) == !strict);
    CHECK(TeraguchiVideo::acceptsStream(VIDEO_FORMAT_H265_REXT10_444, 0, 2160, 60, 0, 2160, 60) == !strict);

    Parameters parameters;
    Decoder startup;
    CHECK(TeraguchiVideo::initializeDecoder(startup, parameters));
    CHECK(startup.softwareAttempts == 0);
    CHECK((parameters.selectionMode == DecoderSelectionMode::ExactHardwareOnly) == strict);

    // Hardware disappears between the successful probe and decoder creation,
    // then returns. Every attempt uses the same production boundary.
    Decoder reset;
    reset.hardwareAvailable = false;
    CHECK(TeraguchiVideo::initializeDecoder(reset, parameters) == !strict);
    CHECK(reset.softwareAttempts == (strict ? 0 : 1));
    reset.hardwareAvailable = true;
    CHECK(TeraguchiVideo::initializeDecoder(reset, parameters));
    CHECK(reset.activeHardware);

    Decoder brokenBackend;
    brokenBackend.hardwareAvailable = false;
    brokenBackend.ignorePolicy = true;
    CHECK(TeraguchiVideo::initializeDecoder(brokenBackend, parameters) == !strict);

    // Explicit hardware-only callers are also protected in ordinary PLANK.
    parameters.selectionMode = DecoderSelectionMode::ExactHardwareOnly;
    CHECK(!TeraguchiVideo::initializeDecoder(brokenBackend, parameters));
    brokenBackend.rewritePolicy = true;
    CHECK(!TeraguchiVideo::initializeDecoder(brokenBackend, parameters));
    Decoder unavailable;
    unavailable.hardwareAvailable = unavailable.softwareAvailable = false;
    CHECK(!TeraguchiVideo::initializeDecoder(unavailable, parameters));
    std::printf("video_admission=%s assertions=%d result=PASS\n", argv[1], assertions);
}
