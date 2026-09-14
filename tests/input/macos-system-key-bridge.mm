// Exercise the production callback and AppKit->SDL marker queue with in-memory
// CGEvents. Never install a global tap, request permissions or post system input.
#import <ApplicationServices/ApplicationServices.h>
static bool trusted = false, listenAllowed = false;
static int tapCreates = 0;
static bool testTrusted() { return trusted; }
static bool testListen() { return listenAllowed; }
static CFMachPortRef testCreate(CGEventTapLocation,CGEventTapPlacement,CGEventTapOptions,
                               CGEventMask,CGEventTapCallBack,void*) { ++tapCreates; return nullptr; }
#define AXIsProcessTrusted testTrusted
#define CGPreflightListenEventAccess testListen
#define CGEventTapCreate testCreate
#include "../../apps/client/app/streaming/input/macsystemkeys.mm"
#undef AXIsProcessTrusted
#undef CGPreflightListenEventAccess
#undef CGEventTapCreate
#include <cstdio>
#include <cstdlib>
#include <vector>
static int checks;
#define CHECK(x) do { ++checks; if (!(x)) { std::fprintf(stderr,"line %d failed\n",__LINE__); std::exit(1); } } while (0)
struct Fixture {
    SDL_WindowID active = 1;
    int failures = 0;
    std::vector<SDL_KeyboardEvent> received;
    MacSystemKeys::Impl impl{[&] { return active; },[&](SDL_KeyboardEvent& e) { received.push_back(e); },[&] { ++failures; }};
    Fixture() { CHECK(impl.prepareDelivery()); CHECK(impl.eventType != SDL_EVENT_USER); }
    bool key(CGKeyCode code, bool down, CGEventFlags flags=0, bool repeat=false) {
        CGEventRef event=CGEventCreateKeyboardEvent(nullptr,code,down);
        CGEventSetFlags(event,flags);
        CGEventSetIntegerValueField(event,kCGKeyboardEventAutorepeat,repeat);
        bool swallowed=impl.accept(down?kCGEventKeyDown:kCGEventKeyUp,event)==nullptr;
        CFRelease(event); return swallowed;
    }
    void cocoa() {
        while (NSEvent* event=[NSApp nextEventMatchingMask:NSEventMaskAny untilDate:[NSDate distantPast]
                               inMode:NSDefaultRunLoopMode dequeue:YES]) [NSApp sendEvent:event];
    }
    void dispatch() {
        SDL_Event event; while (SDL_PeepEvents(&event,1,SDL_GETEVENT,SDL_EVENT_FIRST,SDL_EVENT_LAST)>0) impl.dispatch(event);
    }
    void drain() { cocoa(); dispatch(); }
};
int main()
{
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
        CHECK(SDL_Init(SDL_INIT_EVENTS));
        {
            Fixture f;
            SDL_Event prior{}; prior.type=SDL_EVENT_USER; prior.user.code=73; CHECK(SDL_PushEvent(&prior));
            id nativeMonitor=[NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskApplicationDefined handler:^NSEvent*(NSEvent* e) {
                if (e.subtype!=31036) return e;
                SDL_Event priorNative{}; priorNative.type=SDL_EVENT_USER; priorNative.user.code=74;
                CHECK(SDL_PushEvent(&priorNative)); return nil;
            }];
            [NSApp postEvent:[NSEvent otherEventWithType:NSEventTypeApplicationDefined location:NSZeroPoint
                modifierFlags:0 timestamp:0 windowNumber:0 context:nil subtype:31036 data1:0 data2:0] atStart:NO];
            CHECK(f.key(kVK_Tab,true,kCGEventFlagMaskCommand));
            CHECK(f.received.empty() && !SDL_HasEvent(f.impl.eventType));
            f.cocoa(); CHECK(f.received.empty());
            SDL_Event event{}; CHECK(SDL_PeepEvents(&event,1,SDL_GETEVENT,SDL_EVENT_FIRST,SDL_EVENT_LAST)>0 && event.type==SDL_EVENT_USER && event.user.code==73);
            CHECK(SDL_PeepEvents(&event,1,SDL_GETEVENT,SDL_EVENT_FIRST,SDL_EVENT_LAST)>0 && event.type==SDL_EVENT_USER && event.user.code==74);
            CHECK(SDL_PeepEvents(&event,1,SDL_GETEVENT,SDL_EVENT_FIRST,SDL_EVENT_LAST)>0 && f.impl.dispatch(event));
            [NSEvent removeMonitor:nativeMonitor];
            CHECK(f.received.size()==1 && f.received[0].scancode==SDL_SCANCODE_TAB && f.received[0].down);
            CHECK(f.key(kVK_Tab,true,kCGEventFlagMaskCommand,true));
            CHECK(f.key(kVK_Tab,false)); // Command can be released before Tab.
            f.drain(); CHECK(f.received.size()==2 && !f.received[1].down);
        }
        {
            Fixture f; CHECK(f.key(kVK_Space,true,kCGEventFlagMaskCommand));
            f.cocoa(); f.impl.cancel(); f.dispatch(); CHECK(f.received.empty());
            CHECK(f.key(kVK_Space,true,kCGEventFlagMaskCommand));
            CHECK(f.key(kVK_Space,false));
            CHECK(f.key(kVK_Space,true,kCGEventFlagMaskCommand)); f.drain();
            CHECK(f.received.size()==1);
        }
        {
            Fixture f; f.active=0;
            CHECK(!f.key(kVK_Tab,true,kCGEventFlagMaskCommand));
            f.active=1;
            CHECK(!f.key(kVK_Tab,true,kCGEventFlagMaskCommand,true));
            CHECK(!f.key(kVK_Tab,false));
            CHECK(!f.key(kVK_ANSI_A,true));
            CHECK(!f.key(kVK_F1,true));
            CHECK(!f.key(kVK_Function,true));
            CHECK(!f.key(kVK_Escape,true,kCGEventFlagMaskCommand|kCGEventFlagMaskAlternate));
            f.drain(); CHECK(f.received.empty());
        }
        {
            Fixture f;
            for (auto code : {kVK_LeftArrow,kVK_UpArrow,kVK_RightArrow,kVK_DownArrow}) {
                CHECK(f.key(code,true,kCGEventFlagMaskControl)); CHECK(f.key(code,false));
            }
            f.drain(); CHECK(f.received.size()==8);
            CHECK(f.key(kVK_ANSI_Q,true,kCGEventFlagMaskCommand));
            f.impl.accept(kCGEventTapDisabledByTimeout,nullptr); f.drain();
            CHECK(f.failures==1 && f.received.size()==8);
            f.impl.accept(kCGEventTapDisabledByUserInput,nullptr); CHECK(f.failures==1);
        }
        {
            Fixture f; CHECK(f.key(kVK_ANSI_W,true,kCGEventFlagMaskCommand));
            f.active=0; CHECK(f.key(kVK_ANSI_W,false)); f.drain(); CHECK(f.received.empty());
        }
        {
            Fixture f;
            for (int i=0; i<65; ++i) {
                f.key(kVK_Tab,true,kCGEventFlagMaskCommand); f.key(kVK_Tab,false);
            }
            CHECK(f.failures==1 && f.impl.pending.empty()); f.drain(); CHECK(f.received.empty());
        }
        {
            Fixture f;
            CHECK(!f.impl.start() && tapCreates==0);
            trusted=true;
            CHECK(!f.impl.start() && tapCreates==0);
            listenAllowed=true;
            CHECK(!f.impl.start() && tapCreates==1); // Failed creation never claims capture.
        }
        SDL_Quit();
        std::printf("macos_system_keys assertions=%d result=PASS live_tap=false system_input_posted=false\n",checks);
    }
}
