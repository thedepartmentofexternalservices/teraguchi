#include "../../apps/client/app/streaming/input/mackeyboard.h"
#include "../../apps/client/app/streaming/input/keyboardmap.h"
#include "../../apps/client/app/streaming/input/macpen.h"
#include <Limelight.h>
#include <cstdio>
#include <cstdlib>
#include <vector>

static int checks;
#define CHECK(x) do { ++checks; if (!(x)) { std::fprintf(stderr,"line %d failed\n",__LINE__); std::exit(1); } } while (0)
using Packet = MacKeyboardState::Packet;
struct Fixture {
    std::vector<Packet> packets;
    int failures = 0;
    bool accept = true, active = true;
    MacKeyboardState state{[&](const Packet& p) { if (!accept) return false; packets.push_back(p); return true; },
                           [&] { ++failures; }};
    void key(SDL_Scancode scancode, bool down = true, bool repeat = false) {
        const auto key = PlankKeyboardMap::map(scancode);
        CHECK(key.code >= 0);
        state.key(scancode,0x8000|key.code,key.nonNormalized?SS_KBE_FLAG_NON_NORMALIZED:0,down,repeat,active);
    }
};
int main()
{
    const struct { SDL_Scancode physical; int code; } baseline[] = {
        {SDL_SCANCODE_RALT,0xA5},{SDL_SCANCODE_RCTRL,0xA3},
        {SDL_SCANCODE_V,0x56},{SDL_SCANCODE_SPACE,0x20},
        {SDL_SCANCODE_GRAVE,0xC0},{SDL_SCANCODE_ESCAPE,0x1B},
        {SDL_SCANCODE_LALT,0xA4},{SDL_SCANCODE_UP,0x26},{SDL_SCANCODE_DOWN,0x28},
        {SDL_SCANCODE_LSHIFT,0xA0},{SDL_SCANCODE_RSHIFT,0xA1},
        {SDL_SCANCODE_LCTRL,0xA2},{SDL_SCANCODE_LGUI,0x5B},{SDL_SCANCODE_RGUI,0x5C},
        {SDL_SCANCODE_A,0x41},{SDL_SCANCODE_TAB,0x09},{SDL_SCANCODE_Q,0x51},
        {SDL_SCANCODE_RETURN,0x0D},{SDL_SCANCODE_KP_ENTER,0x0D},
    };
    for (const auto& key : baseline) CHECK(PlankKeyboardMap::map(key.physical).code == key.code);
    CHECK(PlankKeyboardMap::map(SDL_SCANCODE_UNKNOWN).code == -1);
    {
        Fixture f;
        f.key(SDL_SCANCODE_LCTRL); f.key(SDL_SCANCODE_RCTRL);
        f.key(SDL_SCANCODE_LCTRL,false); f.key(SDL_SCANCODE_V);
        CHECK(f.packets[2].modifiers == MODIFIER_CTRL);
        CHECK(f.packets[3].modifiers == MODIFIER_CTRL);
        f.state.releaseAll();
        CHECK(f.packets[4].key == 0x8056 && !f.packets[4].down);
        CHECK(f.packets[5].key == 0x80A3 && !f.packets[5].down && f.packets[5].modifiers == 0);
        f.state.releaseAll(); CHECK(f.packets.size() == 6);
    }
    {
        Fixture f; f.key(SDL_SCANCODE_LSHIFT); f.key(SDL_SCANCODE_LCTRL);
        f.key(SDL_SCANCODE_LGUI); f.key(SDL_SCANCODE_A);
        CHECK(f.packets.back().modifiers == (MODIFIER_SHIFT|MODIFIER_CTRL|MODIFIER_META));
        CHECK(f.packets[2].key == 0x805B); // No client Command-to-Control remap.
        f.state.releaseAll();
        CHECK(f.packets[4].key == 0x8041 && !f.packets[4].down);
        CHECK(f.packets[5].key == 0x805B && !f.packets[5].down);
        CHECK(f.packets[7].modifiers == 0);
    }
    {
        Fixture f; f.key(SDL_SCANCODE_V); f.key(SDL_SCANCODE_V); f.key(SDL_SCANCODE_V,true,true);
        CHECK(f.packets.size() == 1);
        f.state.releaseAll();
        f.key(SDL_SCANCODE_V); CHECK(f.packets.size() == 2); // Held across focus/capture change.
        f.key(SDL_SCANCODE_V,false); CHECK(f.packets.size() == 2);
        f.key(SDL_SCANCODE_V); CHECK(f.packets.size() == 3);
    }
    {
        Fixture f; f.active = false; f.key(SDL_SCANCODE_RALT);
        f.active = true; f.key(SDL_SCANCODE_RALT); CHECK(f.packets.empty());
        f.key(SDL_SCANCODE_RALT,false); f.key(SDL_SCANCODE_RALT);
        CHECK(f.packets.size() == 1 && f.packets[0].key == 0x80A5);
        f.key(SDL_SCANCODE_RALT,false); CHECK(f.packets.size() == 2);
    }
    {
        Fixture f; f.state.consumeLocal(SDL_SCANCODE_Q); f.key(SDL_SCANCODE_Q,false);
        f.key(SDL_SCANCODE_W,false); f.key(SDL_SCANCODE_Q,true,true);
        CHECK(f.packets.empty()); // No orphan key-up or acquisition from a repeat.
    }
    {
        Fixture f; f.key(SDL_SCANCODE_INTERNATIONAL1);
        f.state.key(SDL_SCANCODE_INTERNATIONAL1,0x8041,0,false,false,true);
        CHECK(f.packets[0].key == 0x80E2 && f.packets[1].key == 0x80E2);
        CHECK(f.packets[1].flags == SS_KBE_FLAG_NON_NORMALIZED); // Down-time identity/flags.
    }
    {
        Fixture f; f.key(SDL_SCANCODE_RETURN); f.key(SDL_SCANCODE_KP_ENTER);
        CHECK(f.packets.size() == 1);
        f.key(SDL_SCANCODE_RETURN,false); CHECK(f.packets.size() == 1);
        f.key(SDL_SCANCODE_KP_ENTER,false); CHECK(f.packets.size() == 2);
        CHECK(!f.packets.back().down); // Legacy alias remains held until both release.
    }
    {
        Fixture f; f.accept = false; f.key(SDL_SCANCODE_A); f.key(SDL_SCANCODE_V); f.state.releaseAll();
        CHECK(f.failures == 1 && f.packets.empty());
    }
    {
        std::vector<int> order;
        MacKeyboardState keys{[&](const Packet& p) { order.push_back(p.down?1:4); return true; },[] { CHECK(false); }};
        MacPenInput pen{[&](const MacPenInput::Packet& p) { order.push_back(p.action==LI_TOUCH_EVENT_CANCEL_ALL?3:2); return true; },
            [](SDL_WindowID,float,float,float& x,float& y) { x=y=0.5f; return true; },[] { CHECK(false); }};
        keys.key(SDL_SCANCODE_RALT,0x80A5,0,true,false,true);
        SDL_Event sample{}; sample.ptouch.type=SDL_EVENT_PEN_DOWN; sample.ptouch.which=1;
        sample.ptouch.windowID=1; sample.ptouch.pen_state=SDL_PEN_INPUT_DOWN;
        pen.handle(sample);
        SDL_Event marker{}; marker.type=SDL_EVENT_USER;
        pen.beforeEvent(marker); // Production loop flushes the sample before a captured key marker.
        pen.suspend(); keys.releaseAll();
        CHECK((order == std::vector<int>{1,2,3,4}));
    }
    std::printf("macos_keyboard assertions=%d result=PASS physical_input=false keypad_distinct=false\n",checks);
}
