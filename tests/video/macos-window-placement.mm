#include "backend/teraguchi/macdisplaybinding.h"
#include "streaming/macpresentationwindows.h"
#import <AppKit/AppKit.h>
#include <cstdio>
#include <cstdlib>
static unsigned checks = 0;
#define CHECK(value) do { ++checks; if (!(value)) { std::fprintf(stderr,"window check failed at line %d\n",__LINE__); std::exit(1); } } while(0)
int main() {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
        SDL_SetHint(SDL_HINT_MAC_BACKGROUND_APP, "1");
        CHECK(SDL_Init(SDL_INIT_VIDEO));
        const auto inventory = MacDisplayBinding::read();
        CHECK(MacDisplayBinding::validInventory(inventory));
        // Read actual identity/modes without emitting or persisting them.
        auto selection = MacDisplayBinding::select(inventory, inventory[0].bounds, 1);
        CHECK(MacDisplayBinding::current(selection));
        const auto displayId = SDL_GetPrimaryDisplay();
        SDL_Rect bounds; CHECK(SDL_GetDisplayBounds(displayId, &bounds));
        const QRect rect(bounds.x,bounds.y,bounds.w,bounds.h);
        for (int output=0; output<2; ++output) {
            auto* window = SDL_CreateWindow("Hidden presentation check",64,64,SDL_WINDOW_HIDDEN | SDL_WINDOW_HIGH_PIXEL_DENSITY);
            CHECK(window);
            CHECK(MacPresentationWindows::configure(window));
            auto* native = (NSWindow*)SDL_GetPointerProperty(SDL_GetWindowProperties(window),SDL_PROP_WINDOW_COCOA_WINDOW_POINTER,nullptr);
            CHECK(native && !native.visible);
            CHECK(native.collectionBehavior & NSWindowCollectionBehaviorFullScreenNone);
            CHECK(![native standardWindowButton:NSWindowZoomButton].enabled);
            for (bool fullscreen : {true,false,true,false}) {
                CHECK(MacPresentationWindows::place(window,displayId,rect,fullscreen));
                CHECK(!native.visible);
                CHECK(native.collectionBehavior & NSWindowCollectionBehaviorFullScreenNone);
                CHECK(![native standardWindowButton:NSWindowZoomButton].enabled);
                CHECK(!(SDL_GetWindowFlags(window) & SDL_WINDOW_FULLSCREEN));
                CHECK(bool(SDL_GetWindowFlags(window) & SDL_WINDOW_BORDERLESS) == fullscreen);
                CHECK(SDL_GetDisplayForWindow(window) == displayId);
                int width,height; CHECK(SDL_GetWindowSize(window,&width,&height));
                CHECK(QSize(width,height) == MacPresentationWindows::frame(rect,fullscreen).size());
            }
            CHECK(!MacPresentationWindows::place(window,0,rect,true));
            CHECK(!MacPresentationWindows::place(window,displayId,QRect(),true));
            SDL_DestroyWindow(window);
        }
        CHECK(!MacPresentationWindows::configure(nullptr));
        CHECK(MacDisplayBinding::current(selection));
        SDL_Quit();
        std::printf("window_checks=%u PASS hidden=true physical_pair=false\n",checks);
    }
}
