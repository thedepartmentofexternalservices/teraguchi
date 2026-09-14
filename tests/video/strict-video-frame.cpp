#include "../../apps/client/app/streaming/video/teraguchiframe.h"
#include <cstdio>
#include <cstdint>
#include <initializer_list>

static int assertions = 0;
#define CHECK(value) do { ++assertions; if (!(value)) { \
    std::fprintf(stderr, "frame assertion failed at line %d\n", __LINE__); av_frame_free(&frame); return 1; } } while (0)

int main()
{
    AVFrame* frame = av_frame_alloc();
    if (!frame) return 2;
    frame->hw_frames_ctx = av_buffer_allocz(sizeof(AVHWFramesContext));
    if (!frame->hw_frames_ctx) { av_frame_free(&frame); return 2; }
    auto* context = reinterpret_cast<AVHWFramesContext*>(frame->hw_frames_ctx->data);
    // Synthetic metadata tests, not a real hardware allocation or attestation.
    const auto reset = [&] {
        frame->format = AV_PIX_FMT_VIDEOTOOLBOX;
        frame->data[3] = reinterpret_cast<uint8_t*>(uintptr_t(1));
        frame->width = 3840; frame->height = 2160;
        frame->colorspace = AVCOL_SPC_RGB; frame->color_range = AVCOL_RANGE_JPEG;
        context->format = AV_PIX_FMT_VIDEOTOOLBOX;
        context->sw_format = AV_PIX_FMT_P410LE;
    };
    const auto accepts = [&](int status = 1) {
        return teraguchiNativeFrameMatches(frame, AV_CODEC_ID_HEVC, AV_PROFILE_HEVC_REXT, status, 3840, 2160);
    };
    reset(); CHECK(accepts());
    CHECK(!accepts(0)); CHECK(!accepts(-1)); CHECK(!accepts(2));
    CHECK(!teraguchiNativeFrameMatches(nullptr, AV_CODEC_ID_HEVC, AV_PROFILE_HEVC_REXT, 1, 3840, 2160));
    CHECK(!teraguchiNativeFrameMatches(frame, AV_CODEC_ID_H264, AV_PROFILE_HEVC_REXT, 1, 3840, 2160));
    CHECK(!teraguchiNativeFrameMatches(frame, AV_CODEC_ID_HEVC, AV_PROFILE_HEVC_MAIN_10, 1, 3840, 2160));
    for (const auto format : {AV_PIX_FMT_YUV444P, AV_PIX_FMT_P010LE, AV_PIX_FMT_P210LE,
                              AV_PIX_FMT_YUV444P12LE, AV_PIX_FMT_NONE}) {
        context->sw_format = format; CHECK(!accepts());
    }
    reset(); frame->format = AV_PIX_FMT_YUV444P10LE; CHECK(!accepts());
    reset(); context->format = AV_PIX_FMT_NONE; CHECK(!accepts());
    reset(); frame->data[3] = nullptr; CHECK(!accepts());
    reset(); frame->colorspace = AVCOL_SPC_BT709; CHECK(!accepts());
    reset(); frame->colorspace = AVCOL_SPC_UNSPECIFIED; CHECK(!accepts());
    reset(); frame->color_range = AVCOL_RANGE_MPEG; CHECK(!accepts());
    reset(); frame->color_range = AVCOL_RANGE_UNSPECIFIED; CHECK(!accepts());
    reset(); frame->width = 1920; CHECK(!accepts());
    reset(); frame->height = 1080; CHECK(!accepts());
    reset(); CHECK(!teraguchiNativeFrameMatches(frame, AV_CODEC_ID_HEVC, AV_PROFILE_HEVC_REXT, 1, 0, 2160));
    reset(); frame->hw_frames_ctx->size = 1; CHECK(!accepts());
    frame->hw_frames_ctx->size = sizeof(AVHWFramesContext);
    av_buffer_unref(&frame->hw_frames_ctx); CHECK(!accepts());
    av_frame_free(&frame);
    std::printf("video_frame_metadata assertions=%d result=PASS hardware_test=false\n", assertions);
}
