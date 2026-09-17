// Exercise the production renderer on non-activating, hidden Cocoa windows.
// Overlay/session entry points abort if called; no live input or networking.
#define AVMediaType AVMediaType_FFmpeg
#include "streaming/video/ffmpeg-renderers/vt.h"
#undef AVMediaType
#include "streaming/session.h"
#include "streaming/streamutils.h"
#include "path.h"
#include <QFile>
#include <memory>
#include <cstdio>
#include <cstdlib>
#import <Cocoa/Cocoa.h>
#import <QuartzCore/CAMetalLayer.h>

static unsigned checks = 0;
#define CHECK(condition) do { ++checks; if (!(condition)) { std::fprintf(stderr, "lifecycle check failed at line %d\n", __LINE__); std::exit(1); } } while (0)
static QString shaderPath;
static int shaderReads = 0, failShaderAt = 0;
Session* Session::s_ActiveSession = nullptr;
QByteArray Path::readDataFile(QString name) {
    CHECK(name == QStringLiteral("vt_renderer.metal"));
    if (++shaderReads == failShaderAt) return QByteArray("invalid shader fixture");
    QFile shader(shaderPath); CHECK(shader.open(QIODevice::ReadOnly)); return shader.readAll();
}
bool Overlay::OverlayManager::isOverlayEnabled(Overlay::OverlayType) { std::abort(); }
SDL_Surface* Overlay::OverlayManager::getUpdatedOverlaySurface(Overlay::OverlayType) { std::abort(); }
float Overlay::OverlayManager::getOverlayHorizontalPosition(Overlay::OverlayType) const { std::abort(); }
void StreamUtils::screenSpaceToNormalizedDeviceCoords(SDL_FRect*, int, int) { std::abort(); }

static void layers(NSView* view, NSMutableArray<CAMetalLayer*>* result) {
    if ([view.layer isKindOfClass:[CAMetalLayer class]]) [result addObject:(CAMetalLayer*)view.layer];
    for (NSView* child in view.subviews) layers(child, result);
}
static NSArray<CAMetalLayer*>* layers(SDL_Window* window) {
    auto native = (NSWindow*)SDL_GetPointerProperty(SDL_GetWindowProperties(window), SDL_PROP_WINDOW_COCOA_WINDOW_POINTER, nullptr);
    CHECK(native != nil && !native.visible);
    auto result = [NSMutableArray array]; layers(native.contentView, result); return result;
}

int main(int argc, char** argv) {
    @autoreleasepool {
        if (argc != 2) return 2;
        shaderPath = QString::fromUtf8(argv[1]);
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
        SDL_SetHint(SDL_HINT_MAC_BACKGROUND_APP, "1");
        CHECK(SDL_Init(SDL_INIT_VIDEO));
        auto first = SDL_CreateWindow("Metal lifecycle test", 64, 64, SDL_WINDOW_HIDDEN | SDL_WINDOW_METAL);
        auto second = SDL_CreateWindow("Metal lifecycle test", 64, 64, SDL_WINDOW_HIDDEN | SDL_WINDOW_METAL);
        CHECK(first && second);
        CHECK(layers(first).count == 0 && layers(second).count == 0);
        DECODER_PARAMETERS params{};
        params.window = first; params.width = 128; params.height = 64;
        params.videoFormat = VIDEO_FORMAT_H265_REXT10_444;
        params.enableIdentityGbr = true; params.enableVsync = true; params.testOnly = true;
        PlankPresentationLayout layout{QSize(128, 64), {{first, QRect(0, 0, 64, 64), true},
                                                     {second, QRect(64, 0, 64, 64), false}}};
        params.presentationLayout = &layout;

        // Invalid second target must fail before either Metal view is allocated.
        layout.outputs[1].window = nullptr;
        {
            std::unique_ptr<IFFmpegRenderer> renderer(VTMetalRendererFactory::createRenderer(false));
            CHECK(!renderer->initialize(&params));
            CHECK(shaderReads == 0);
        }
        layout.outputs[1].window = second;
        CHECK(layers(first).count == 0 && layers(second).count == 0);

        // Failure after first-output initialization must still release both views.
        failShaderAt = 2;
        {
            std::unique_ptr<IFFmpegRenderer> renderer(VTMetalRendererFactory::createRenderer(false));
            CHECK(!renderer->initialize(&params));
            CHECK(shaderReads == 2);
        }
        CHECK(layers(first).count == 0 && layers(second).count == 0);
        failShaderAt = 0;

        AVFrame* frame = av_frame_alloc();
        CHECK(frame != nullptr);
        frame->format = AV_PIX_FMT_YUV444P10;
        frame->width = 128; frame->height = 64;
        frame->colorspace = AVCOL_SPC_RGB; frame->color_range = AVCOL_RANGE_JPEG;
        CHECK(av_frame_get_buffer(frame, 32) == 0);
        for (int plane = 0; plane < 3; ++plane)
            for (int y = 0; y < frame->height; ++y)
                for (int x = 0; x < frame->width; ++x)
                    reinterpret_cast<uint16_t*>(frame->data[plane] + y * frame->linesize[plane])[x] = (x + y + plane) % 1024;

        // Repeated setup/teardown uses the unchanged factory and renderer source.
        // A synthetic software frame checks Metal resources only, not decode.
        for (int iteration = 0; iteration < 3; ++iteration) {
            {
                std::unique_ptr<IFFmpegRenderer> renderer(VTMetalRendererFactory::createRenderer(false));
                CHECK(renderer->initialize(&params));
                CHECK(layers(first).count == 1 && layers(second).count == 1);
                CHECK(renderer->testRenderFrame(frame));
                CHECK(layers(first).firstObject.pixelFormat == MTLPixelFormatBGR10A2Unorm);
                CHECK(layers(second).firstObject.pixelFormat == MTLPixelFormatBGR10A2Unorm);
                WINDOW_STATE_CHANGE_INFO change{};
                change.window = first; change.stateChangeFlags = WINDOW_STATE_CHANGE_SIZE;
                CHECK(!renderer->notifyWindowChanged(&change));
                renderer->renderFrame(frame);
                renderer->cleanupRenderContext();
            }
            CHECK(layers(first).count == 0 && layers(second).count == 0);
        }
        av_frame_free(&frame);
        SDL_DestroyWindow(second); SDL_DestroyWindow(first); SDL_Quit();
        std::printf("metal_lifecycle_checks=%u PASS hidden_windows=true hardware_decode=false physical_displays=false\n", checks);
    }
}
