// Exact-format qualification. No windows, capture, input or TCC edits.
#import <VideoToolbox/VideoToolbox.h>
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavcodec/videotoolbox.h>
#include <libavformat/avformat.h>
#include <libavutil/hwcontext.h>
#include <libavutil/pixdesc.h>
}
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cerrno>
#include <climits>
#include "decode-contract.h"
#include "../../apps/client/app/streaming/video/teraguchiframe.h"

static AVPixelFormat requireVT(AVCodecContext*, const AVPixelFormat* formats)
{
    for (; *formats != AV_PIX_FMT_NONE; ++formats)
        if (*formats == AV_PIX_FMT_VIDEOTOOLBOX) return *formats;
    return AV_PIX_FMT_NONE;
}

struct Resources {
    AVFormatContext* input = nullptr;
    AVCodecContext* context = nullptr;
    AVPacket* packet = nullptr;
    AVFrame* frame = nullptr;
    ~Resources() {
        av_frame_free(&frame);
        av_packet_free(&packet);
        avcodec_free_context(&context);
        avformat_close_input(&input);
    }
};

int main(int argc, char** argv)
{
    if (argc != 7 || (strcmp(argv[1], "hardware") && strcmp(argv[1], "software"))) {
        fprintf(stderr, "usage: probe hardware|software FILE EXPECTED_PROFILE WIDTH HEIGHT EXPECTED_FRAMES\n"
                        "profiles: hevc-rext10-444-identity, hevc-rext10-444-bt709-full, h264-44410-identity\n");
        return 2;
    }
    auto positive = [](const char* value) -> long {
        char* end = nullptr;
        errno = 0;
        long parsed = strtol(value, &end, 10);
        return errno || !*value || *end || parsed <= 0 || parsed > INT_MAX ? 0 : parsed;
    };
    const long expected = positive(argv[6]);
    const int expectedWidth = (int)positive(argv[4]), expectedHeight = (int)positive(argv[5]);
    if (!expected || !expectedWidth || !expectedHeight) return 2;
    DecodeFormat expectedFormat = {"hevc", AV_PROFILE_HEVC_REXT, expectedWidth, expectedHeight, 10, 0, 0,
                                   AVCOL_SPC_RGB, AVCOL_RANGE_JPEG};
    if (!strcmp(argv[3], "hevc-rext10-444-bt709-full")) expectedFormat.matrix = AVCOL_SPC_BT709;
    else if (!strcmp(argv[3], "h264-44410-identity")) {
        expectedFormat.codec = "h264";
        expectedFormat.profile = AV_PROFILE_H264_HIGH_444_PREDICTIVE;
    }
    else if (strcmp(argv[3], "hevc-rext10-444-identity")) return 2;
    const bool hardware = !strcmp(argv[1], "hardware");
    auto fail = [&](const char* reason, int code = 0) {
        char error[128] = {};
        if (code < 0) av_strerror(code, error, sizeof(error));
        fprintf(stderr, "decode=%s result=FAIL reason=%s error=%s\n", argv[1], reason, error);
        return 7;
    };
    Resources r;
    if (avformat_open_input(&r.input, argv[2], nullptr, nullptr) < 0 ||
        avformat_find_stream_info(r.input, nullptr) < 0) return fail("input");
    const int stream = av_find_best_stream(r.input, AVMEDIA_TYPE_VIDEO, -1, -1, nullptr, 0);
    if (stream < 0) return fail("video_stream", stream);
    const AVCodec* codec = avcodec_find_decoder(r.input->streams[stream]->codecpar->codec_id);
    if (!codec) return fail("decoder_missing");
    r.context = avcodec_alloc_context3(codec);
    if (!r.context || avcodec_parameters_to_context(r.context, r.input->streams[stream]->codecpar) < 0)
        return fail("decoder_allocation");
    r.context->thread_count = 1;
    if (hardware) {
        r.context->get_format = requireVT;
        // The required private FFmpeg patch requests hardware for HEVC/H.264.
        // Its accessor reads the actual session property; frames alone are insufficient.
        if (av_hwdevice_ctx_create(&r.context->hw_device_ctx, AV_HWDEVICE_TYPE_VIDEOTOOLBOX,
                                   nullptr, nullptr, 0) < 0) return fail("hardware_device");
    }
    if (avcodec_open2(r.context, codec, nullptr) < 0) return fail("decoder_open");
    r.packet = av_packet_alloc();
    r.frame = av_frame_alloc();
    if (!r.packet || !r.frame) return fail("frame_allocation");
    long frames = 0;
    int width = 0, height = 0, profile = 0, matrix = 0, range = 0;
    AVPixelFormat storage = AV_PIX_FMT_NONE;
    OSType cvFormat = 0;
    const auto started = std::chrono::steady_clock::now();
    const char* mismatch = nullptr;
    auto receive = [&]() -> int {
        int result;
        while ((result = avcodec_receive_frame_flags(r.context, r.frame,
                  AV_CODEC_RECEIVE_FRAME_FLAG_SYNCHRONOUS)) >= 0) {
            const int hardwareStatus = hardware ? av_videotoolbox_is_hardware_accelerated(r.context) : 0;
            if (hardware && (r.frame->format != AV_PIX_FMT_VIDEOTOOLBOX || !r.frame->data[3])) {
                mismatch = "hardware_surface";
                return AVERROR(ENOSYS);
            }
            AVPixelFormat current = (AVPixelFormat)r.frame->format;
            if (r.frame->hw_frames_ctx)
                current = ((AVHWFramesContext*)r.frame->hw_frames_ctx->data)->sw_format;
            const AVPixFmtDescriptor* description = av_pix_fmt_desc_get(current);
            if (!description || description->nb_components != 3) {
                mismatch = "pixel_description";
                return AVERROR_INVALIDDATA;
            }
            for (int component = 0; component < description->nb_components; ++component) {
                if (description->comp[component].depth != expectedFormat.depth) {
                    mismatch = "bit_depth";
                    return AVERROR_INVALIDDATA;
                }
            }
            const DecodeFormat observed = {avcodec_get_name(r.context->codec_id), r.context->profile,
                r.frame->width, r.frame->height, description->comp[0].depth,
                description->log2_chroma_w, description->log2_chroma_h,
                r.frame->colorspace, r.frame->color_range};
            mismatch = decodeMismatch(expectedFormat, observed, hardware, hardwareStatus);
            if (mismatch) return AVERROR_INVALIDDATA;
            if (hardware && !strcmp(argv[3], "hevc-rext10-444-identity") &&
                    !teraguchiNativeFrameMatches(r.frame, r.context->codec_id,
                        r.context->profile, hardwareStatus, expectedWidth, expectedHeight)) {
                mismatch = "product_frame_contract";
                return AVERROR_INVALIDDATA;
            }
            if (frames >= expected) { mismatch = "frame_count"; return AVERROR_INVALIDDATA; }
            const OSType cv = hardware ? CVPixelBufferGetPixelFormatType((CVPixelBufferRef)r.frame->data[3]) : 0;
            if (!frames) {
                width = r.frame->width; height = r.frame->height; profile = r.context->profile;
                matrix = r.frame->colorspace; range = r.frame->color_range;
                storage = current; cvFormat = cv;
            } else if (width != r.frame->width || height != r.frame->height ||
                       profile != r.context->profile || matrix != r.frame->colorspace ||
                       range != r.frame->color_range || storage != current || cvFormat != cv) {
                return AVERROR_INVALIDDATA;
            }
            ++frames;
            av_frame_unref(r.frame);
        }
        return result;
    };
    int result;
    while ((result = av_read_frame(r.input, r.packet)) >= 0) {
        if (r.packet->stream_index == stream) {
            int sent = avcodec_send_packet(r.context, r.packet);
            if (sent < 0) return fail("send_packet", sent);
            int received = receive();
            if (received != AVERROR(EAGAIN)) return fail(mismatch ? mismatch : "receive", received);
        }
        av_packet_unref(r.packet);
    }
    if (result != AVERROR_EOF) return fail("read_packet", result);
    result = avcodec_send_packet(r.context, nullptr);
    if (result < 0) return fail("flush_send", result);
    result = receive();
    if (result != AVERROR_EOF) return fail(mismatch ? mismatch : "flush_receive", result);
    if (frames != expected) return fail("frame_count");
    const double elapsed = std::chrono::duration<double>(std::chrono::steady_clock::now()-started).count();
    const auto* desc = av_pix_fmt_desc_get(storage);
    if (!desc || elapsed <= 0) return fail("output_description");
    printf("decode=%s result=PASS expected_profile=%s hardware_attested=%s frames=%ld seconds=%.6f fps=%.3f "
           "size=%dx%d profile=%d storage=%s depth=%d chroma=%d:%d matrix=%d range=%d cv=%c%c%c%c\n",
           argv[1], argv[3], hardware ? "true" : "not-requested", frames, elapsed, frames/elapsed,
           width, height, profile, av_get_pix_fmt_name(storage), desc->comp[0].depth,
           desc->log2_chroma_w, desc->log2_chroma_h, matrix, range,
           hardware ? (cvFormat >> 24) & 255 : '-', hardware ? (cvFormat >> 16) & 255 : '-',
           hardware ? (cvFormat >> 8) & 255 : '-', hardware ? cvFormat & 255 : '-');
    return 0;
}
