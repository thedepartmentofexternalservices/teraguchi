// Production Metal vertices, shader and uniforms, rendered into two offscreen
// ten-bit textures. No windows, event taps, TCC requests or host connections.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include "streaming/video/ffmpeg-renderers/vt_presentation.h"
#include "streaming/video/ffmpeg-renderers/vt_colors.h"
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <vector>

static double code(int channel, double x, double y) {
    if (channel == 0) return 1 + 23 * x + 7 * y;
    if (channel == 1) return 2 + 11 * x + 19 * y;
    return 3 + 17 * x + 13 * y;
}

int main(int argc, char** argv) {
    @autoreleasepool {
        const bool uncroppedControl = argc == 3 && std::strcmp(argv[2], "--uncropped") == 0;
        if (argc != 2 && !uncroppedControl) return 2;
        auto device = MTLCreateSystemDefaultDevice();
        if (!device) { std::fprintf(stderr, "Metal device unavailable\n"); return 77; }
        NSError* error = nil;
        auto source = [NSString stringWithContentsOfFile:@(argv[1]) encoding:NSUTF8StringEncoding error:&error];
        auto library = [device newLibraryWithSource:source options:nil error:&error];
        if (!library) { NSLog(@"%@", error); return 3; }
        auto queue = [device newCommandQueue];
        struct Scenario { QSize stream, canvas; QVector<QRect> outputs; };
        const Scenario scenarios[] = {
            {{16, 8}, {16, 8}, {{0, 0, 16, 8}}},
            {{16, 8}, {16, 8}, {{0, 0, 8, 8}, {8, 0, 8, 8}}},
            {{24, 8}, {24, 8}, {{0, 0, 16, 8}, {16, 0, 8, 8}}},
            {{8, 8}, {16, 8}, {{0, 0, 8, 8}, {8, 0, 8, 8}}},
            {{16, 4}, {16, 8}, {{0, 0, 8, 8}, {8, 0, 8, 8}}},
            {{24, 8}, {24, 8}, {{0, 0, 16, 8}, {16, 0, 8, 4}}},
            {{4, 8}, {24, 8}, {{0, 0, 8, 8}, {8, 0, 16, 8}}}
        };
        unsigned checks = 0, targets = 0;
        double worst = 0;
        for (bool planar : {false, true}) for (int density : {1, 2}) {
            auto descriptor = [MTLRenderPipelineDescriptor new];
            descriptor.vertexFunction = [library newFunctionWithName:@"vs_draw"];
            descriptor.fragmentFunction = [library newFunctionWithName:planar ? @"ps_draw_triplanar" : @"ps_draw_biplanar"];
            descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGR10A2Unorm;
            auto pipeline = [device newRenderPipelineStateWithDescriptor:descriptor error:&error];
            if (!pipeline) { NSLog(@"%@", error); return 4; }
            for (const auto& scenario : scenarios) { @autoreleasepool {
                NSMutableArray<id<MTLTexture>>* textures = [NSMutableArray new];
                const int width = scenario.stream.width(), height = scenario.stream.height();
                for (int plane = 0; plane < (planar ? 3 : 2); ++plane) {
                    const int channels = !planar && plane == 1 ? 2 : 1;
                    auto desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:channels == 2 ? MTLPixelFormatRG16Unorm : MTLPixelFormatR16Unorm
                                width:width height:height mipmapped:NO];
                    desc.storageMode = MTLStorageModeShared;
                    desc.usage = MTLTextureUsageShaderRead;
                    auto texture = [device newTextureWithDescriptor:desc];
                    std::vector<uint16_t> pixels(width * height * channels);
                    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x)
                        for (int c = 0; c < channels; ++c) {
                            const int component = plane + c;
                            const int rgb = component == 0 ? 1 : component == 1 ? 2 : 0;
                            pixels[(y * width + x) * channels + c] = uint16_t(code(rgb, x, y)) << 6;
                        }
                    [texture replaceRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:0
                             withBytes:pixels.data() bytesPerRow:width * channels * sizeof(uint16_t)];
                    if (!texture) return 5;
                    [textures addObject:texture];
                }
                for (const auto& output : scenario.outputs) { @autoreleasepool {
                    const QSize drawable(output.width() * density, output.height() * density);
                    auto quad = PlankVT::outputQuad(scenario.stream, scenario.canvas, output);
                    if (uncroppedControl && scenario.outputs.size() == 2)
                        quad.texture = QRectF(0, 0, 1, 1);
                    const auto vertices = PlankVT::vertices(quad);
                    auto desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGR10A2Unorm
                                width:drawable.width() height:drawable.height() mipmapped:NO];
                    desc.storageMode = MTLStorageModeShared;
                    desc.usage = MTLTextureUsageRenderTarget;
                    auto target = [device newTextureWithDescriptor:desc];
                    auto pass = [MTLRenderPassDescriptor renderPassDescriptor];
                    pass.colorAttachments[0].texture = target;
                    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
                    pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
                    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
                    auto command = [queue commandBuffer];
                    auto encoder = [command renderCommandEncoderWithDescriptor:pass];
                    if (!target || !command || !encoder) return 5;
                    const auto params = plankVTColorParams(PlankVTMatrix::IdentityGbr, true, 10, true);
                    [encoder setRenderPipelineState:pipeline];
                    [encoder setVertexBytes:vertices.data() length:sizeof(vertices) atIndex:0];
                    [encoder setFragmentBytes:&params length:sizeof(params) atIndex:0];
                    for (NSUInteger i = 0; i < textures.count; ++i) [encoder setFragmentTexture:textures[i] atIndex:i];
                    if (quad.visible) [encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
                    [encoder endEncoding]; [command commit]; [command waitUntilCompleted];
                    if (command.status != MTLCommandBufferStatusCompleted) return 6;
                    std::vector<uint32_t> pixels(drawable.width() * drawable.height());
                    [target getBytes:pixels.data() bytesPerRow:drawable.width() * sizeof(uint32_t)
                            fromRegion:MTLRegionMake2D(0, 0, drawable.width(), drawable.height()) mipmapLevel:0];
                    for (int y = 0; y < drawable.height(); ++y) for (int x = 0; x < drawable.width(); ++x) {
                        QPointF streamPoint;
                        const bool inside = PlankPresentation::mapWindowPointToStream(
                            {x + 0.5, y + 0.5}, drawable, scenario.stream, scenario.canvas, output, streamPoint, false);
                        const double sx = std::clamp(streamPoint.x() - 0.5, 0.0, double(width - 1));
                        const double sy = std::clamp(streamPoint.y() - 0.5, 0.0, double(height - 1));
                        const uint32_t packed = pixels[y * drawable.width() + x];
                        for (int c = 0; c < 3; ++c) {
                            const unsigned value = (packed >> (c == 0 ? 20 : c == 1 ? 10 : 0)) & 1023;
                            const double expected = inside ? code(c, sx, sy) : 0;
                            const double difference = std::abs(value - expected);
                            worst = std::max(worst, difference); ++checks;
                            if (difference > 1.1) {
                                std::fprintf(stderr, "crop mismatch target=%u pixel=%d,%d channel=%d actual=%u expected=%.3f\n", targets, x, y, c, value, expected);
                                return 7;
                            }
                        }
                    }
                    ++targets;
                }}
            }}
        }
        std::printf("metal_output_targets=%u rgb10_checks=%u worst_code_error=%.3f PASS physical_displays=false\n", targets, checks, worst);
    }
}
