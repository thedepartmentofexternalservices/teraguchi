#include "streaming/mactabletcursor.h"
#include "streaming/plankpresentation.h"
#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#include <cstdio>
#include <cstdlib>
#include <cmath>

static int checks = 0;
#define CHECK(x) do { ++checks; if (!(x)) { std::fprintf(stderr, "cursor assertion line %d\n", __LINE__); std::exit(1); } } while (0)

static NSView* content(SDL_Window* window)
{
    return ((__bridge NSWindow*)SDL_GetPointerProperty(SDL_GetWindowProperties(window),
        SDL_PROP_WINDOW_COCOA_WINDOW_POINTER, nullptr)).contentView;
}

int main()
{ @autoreleasepool {
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
    SDL_SetHint(SDL_HINT_MAC_BACKGROUND_APP, "1");
    CHECK(SDL_Init(SDL_INIT_VIDEO));
    SDL_Window* first = SDL_CreateWindow("Hidden tablet cursor check", 800, 400, SDL_WINDOW_HIDDEN | SDL_WINDOW_METAL);
    SDL_Window* second = SDL_CreateWindow("Hidden tablet cursor check", 400, 400, SDL_WINDOW_HIDDEN);
    CHECK(first && second);
    SDL_MetalView videoView = SDL_Metal_CreateView(first);
    CHECK(videoView != nullptr);
    NSWindow* keyWindow = NSApp.keyWindow;
    NSView* parent = content(first);
    NSUInteger originalChildren = parent.subviews.count;
    auto cursor = MacTabletCursor::create(first);
    auto other = MacTabletCursor::create(second);
    CHECK(cursor && other);
    CHECK(cursor->isAttachedTo(first) && !cursor->isAttachedTo(second));
    CHECK(parent.subviews.count == originalChildren + 1);
    NSView* overlay = parent.subviews.lastObject;
    CHECK(originalChildren > 0 && overlay.layer != (__bridge CALayer*)SDL_Metal_GetLayer(videoView));
    CHECK(overlay.isFlipped && !overlay.isOpaque && !overlay.acceptsFirstResponder);
    CHECK([overlay hitTest:NSMakePoint(200, 100)] == nil);
    CHECK(overlay.hidden);
    cursor->setVisible(true);
    CHECK(overlay.hidden); // No stale/default position before a host sample.
    QImage image(8, 8, QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);
    image.setPixelColor(1, 1, QColor(255, 0, 0));
    image.setPixelColor(1, 6, QColor(0, 0, 255));
    cursor->setImage(image, 1, 2);
    cursor->setVisible(true);
    CHECK(overlay.hidden); // Image alone cannot reveal an old pointer.
    cursor->setPosition(667, 67);
    cursor->setVisible(true);
    CHECK(!overlay.hidden);
    CALayer* shape = overlay.layer.sublayers.lastObject;
    CHECK(shape.position.x == 666 && shape.position.y == 65);
    CHECK(shape.bounds.size.width == 8 && shape.bounds.size.height == 8);
    CHECK(overlay.layer.geometryFlipped);
    CGImageRef pixels = (__bridge CGImageRef)shape.contents;
    CHECK(CGImageGetWidth(pixels) == 8 && CGImageGetHeight(pixels) == 8);
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(pixels));
    const UInt8* rgba = CFDataGetBytePtr(data);
    const size_t row = CGImageGetBytesPerRow(pixels);
    CHECK(rgba[row + 4] == 255 && rgba[row + 7] == 255);
    CHECK(rgba[6 * row + 6] == 255 && rgba[6 * row + 7] == 255);
    CHECK(rgba[3] == 0); // Preserve transparency, not a cursor-shaped rectangle.
    CFRelease(data);
    // The input sample was (0.8, 0.2), but the host reports (3200, 360)
    // after a 5%-per-edge driver crop. Place the pointer at the host hit target.
    QPointF point;
    CHECK(PlankPresentation::mapStreamPointToWindow(QPointF(3200, 360), QSize(3840, 2160),
        QSize(800, 450), QRect(0, 0, 800, 450), QSize(800, 450), point));
    CHECK(std::abs(point.x() - 666.666667) < 0.001 && std::abs(point.y() - 75) < 0.001);
    cursor->setPosition(qRound(point.x()), qRound(point.y()));
    CHECK(shape.position.x == 666 && shape.position.y == 73);
    // Paired outputs: reported position selects the second output, including
    // the stream-to-window scale and hotspot, without moving the OS pointer.
    CHECK(!PlankPresentation::mapStreamPointToWindow(QPointF(5760, 1080), QSize(7680, 2160),
        QSize(1600, 450), QRect(0, 0, 800, 450), QSize(800, 450), point));
    CHECK(PlankPresentation::mapStreamPointToWindow(QPointF(5760, 1080), QSize(7680, 2160),
        QSize(1600, 450), QRect(800, 0, 800, 450), QSize(400, 225), point));
    CHECK(point == QPointF(200, 112.5));
    other->setImage(image, 1, 2);
    other->setPosition(qRound(point.x()), qRound(point.y()));
    cursor->setVisible(false);
    other->setVisible(true);
    CHECK(overlay.hidden && !content(second).subviews.lastObject.hidden);
    cursor->setVisible(false); // Idempotent focus/capture cleanup.
    CHECK(overlay.hidden);
    [parent setFrameSize:NSMakeSize(1000, 500)];
    CHECK(NSEqualSizes(overlay.frame.size, parent.bounds.size));
    CHECK(shape.position.x == 666 && shape.position.y == 73);
    cursor->dispatchPending();
    CHECK(NSApp.keyWindow == keyWindow && !parent.window.visible);
    // Content-view replacement invalidates the old attachment, as a renderer
    // recreation does. Destruction removes the old layer before reattaching.
    NSView* replacement = [[NSView alloc] initWithFrame:parent.bounds];
    [parent retain];
    parent.window.contentView = replacement;
    [replacement release];
    CHECK(!cursor->isAttachedTo(first));
    cursor.reset();
    CHECK(parent.subviews.count == originalChildren);
    cursor = MacTabletCursor::create(first);
    CHECK(cursor && cursor->isAttachedTo(first));
    CHECK(content(first).subviews.lastObject.hidden);
    cursor.reset(); other.reset();
    content(first).window.contentView = parent;
    [parent release];
    SDL_Metal_DestroyView(videoView);
    SDL_DestroyWindow(second); SDL_DestroyWindow(first); SDL_Quit();
    std::printf("Mac tablet cursor: %d checks passed (hidden windows; no host input)\n", checks);
    return 0;
} }
