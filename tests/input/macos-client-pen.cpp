// The production Cocoa/SDL sample assembler, with recording output only.
#include "../../apps/client/app/streaming/input/macpen.h"
#include "../../protocol/plank-transport/include/plank_transport_input.h"
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <limits>
#include <vector>

static int checks = 0;
#define CHECK(x) do { ++checks; if (!(x)) { std::fprintf(stderr, "pen assertion line %d\n", __LINE__); std::exit(1); } } while (0)
static constexpr auto hover = SDL_PEN_INPUT_IN_PROXIMITY;
static constexpr auto contact = hover | SDL_PEN_INPUT_DOWN;

static SDL_Event point(SDL_EventType type, Uint64 time, SDL_PenInputFlags state,
                       float x = 400, float y = 200, SDL_PenID pen = 1)
{
    SDL_Event e{};
    // Populate the correct union member; all pen point structures have the
    // same public prefix, but tests should not depend on union aliasing.
    if (type == SDL_EVENT_PEN_AXIS) {
        e.paxis = {type, 0, time, 10, pen, state, x, y, SDL_PEN_AXIS_PRESSURE, 0.5f};
    } else if (type == SDL_EVENT_PEN_DOWN || type == SDL_EVENT_PEN_UP) {
        e.ptouch = {type, 0, time, 10, pen, state, x, y,
                   bool(state & SDL_PEN_INPUT_ERASER_TIP), bool(state & SDL_PEN_INPUT_DOWN)};
    } else if (type == SDL_EVENT_PEN_MOTION) {
        e.pmotion = {type, 0, time, 10, pen, state, x, y};
    } else {
        e.pbutton = {type, 0, time, 10, pen, state, x, y, 1, bool(state & SDL_PEN_INPUT_BUTTON_1)};
    }
    return e;
}

struct Fixture {
    std::vector<MacPenInput::Packet> packets;
    bool active = true, accept = true;
    int failures = 0;
    MacPenInput pen{
        [this](const MacPenInput::Packet& p) { if (!accept) return false; packets.push_back(p); return true; },
        [this](SDL_WindowID id, float x, float y, float& nx, float& ny) {
            nx = x / 800; ny = y / 400;
            return active && id == 10 && x >= 0 && x < 800 && y >= 0 && y < 400;
        }, [this] { ++failures; }};
    void event(const SDL_Event& e) { pen.beforeEvent(e); pen.handle(e); }
    void down(Uint64 time = 1) {
        event(point(SDL_EVENT_PEN_DOWN, time, contact));
        event(point(SDL_EVENT_PEN_AXIS, time, contact));
        pen.flush();
    }
};

int main()
{
    {
        Fixture f;
        // Real Cocoa ordering: contact at the OLD position, then motion and pressure.
        f.event(point(SDL_EVENT_PEN_DOWN, 1, contact, 10, 10));
        SDL_Event mouse{}; mouse.motion.type = SDL_EVENT_MOUSE_MOTION;
        mouse.motion.timestamp = 1; mouse.motion.which = SDL_PEN_MOUSEID;
        f.event(mouse);
        SDL_Event finger{}; finger.tfinger.type = SDL_EVENT_FINGER_DOWN;
        finger.tfinger.timestamp = 1; finger.tfinger.touchID = SDL_PEN_TOUCHID;
        f.event(finger);
        CHECK(f.packets.empty());
        f.event(point(SDL_EVENT_PEN_MOTION, 1, contact));
        f.event(point(SDL_EVENT_PEN_AXIS, 1, contact));
        f.pen.flush();
        CHECK(f.packets.size() == 1);
        CHECK(f.packets[0].action == LI_TOUCH_EVENT_DOWN);
        CHECK(f.packets[0].x == 0.5f && f.packets[0].y == 0.5f && f.packets[0].pressure == 0.5f);
        f.event(point(SDL_EVENT_PEN_UP, 2, hover)); f.pen.flush();
        CHECK(f.packets.back().action == LI_TOUCH_EVENT_UP && f.packets.back().pressure == 0);
    }
    {
        Fixture f; f.down();
        for (int value = 1; value <= 8191; ++value) {
            auto event = point(SDL_EVENT_PEN_AXIS, value + 1, contact);
            const float pressure = float(value) / 8191;
            event.paxis.value = pressure;
            f.event(event); f.pen.flush();
            CHECK(f.packets.back().pressure == pressure);
            uint8_t payload[PLANK_TRANSPORT_INPUT_PEN_SIZE];
            const auto& p = f.packets.back();
            plank_transport_input_encode_pen(payload,p.action,p.tool,p.buttons,p.tilt,p.rotation,p.x,p.y,p.pressure,0,0);
            CHECK(plank_transport_input_read_float(payload + 16) == pressure);
        }
        CHECK(f.packets.size() == 8192);
    }
    {
        Fixture f;
        f.event(point(SDL_EVENT_PEN_MOTION, 1, hover | SDL_PEN_INPUT_BUTTON_1 | SDL_PEN_INPUT_BUTTON_2));
        auto tilt = point(SDL_EVENT_PEN_AXIS, 1, hover | SDL_PEN_INPUT_BUTTON_1 | SDL_PEN_INPUT_BUTTON_2);
        tilt.paxis.axis = SDL_PEN_AXIS_XTILT; tilt.paxis.value = 30; f.event(tilt);
        f.pen.flush();
        CHECK(f.packets.back().buttons == (LI_PEN_BUTTON_PRIMARY | LI_PEN_BUTTON_SECONDARY));
        CHECK(f.packets.back().tilt == 30 && f.packets.back().rotation == 270);
        CHECK(f.packets.back().pressure == 0);
        f.event(point(SDL_EVENT_PEN_DOWN, 2, contact | SDL_PEN_INPUT_ERASER_TIP)); f.pen.flush();
        CHECK(f.packets[f.packets.size()-2].action == LI_TOUCH_EVENT_CANCEL_ALL);
        CHECK(f.packets.back().tool == LI_TOOL_TYPE_ERASER && f.packets.back().action == LI_TOUCH_EVENT_DOWN);
        f.pen.suspend(); f.pen.suspend();
        CHECK(f.packets.back().action == LI_TOUCH_EVENT_CANCEL_ALL && f.packets.back().buttons == 0);
        CHECK(f.packets.size() == 4);
    }
    {
        Fixture f; f.down(); f.pen.suspend();
        f.event(point(SDL_EVENT_PEN_MOTION, 2, contact)); f.pen.flush();
        CHECK(f.packets.size() == 2); // Refocus must not restart a held stroke.
        f.event(point(SDL_EVENT_PEN_UP, 3, hover)); f.pen.flush();
        CHECK(f.packets.back().action == LI_TOUCH_EVENT_HOVER);
        f.down(4); CHECK(f.packets.back().action == LI_TOUCH_EVENT_DOWN);
    }
    {
        Fixture f; f.down();
        f.event(point(SDL_EVENT_PEN_MOTION, 2, contact, 900)); f.pen.flush();
        CHECK(f.packets.back().action == LI_TOUCH_EVENT_CANCEL_ALL);
        f.event(point(SDL_EVENT_PEN_MOTION, 3, contact)); f.pen.flush();
        CHECK(f.packets.size() == 2);
        f.active = false;
        f.event(point(SDL_EVENT_PEN_UP, 4, hover)); f.pen.flush();
        CHECK(f.packets.size() == 2);
    }
    {
        Fixture f; f.down();
        SDL_Event out{}; out.pproximity = {SDL_EVENT_PEN_PROXIMITY_OUT,0,2,0,2};
        f.event(out); CHECK(f.packets.size() == 1); // An unrelated pen leaves.
        out.pproximity.which = 1; f.event(out); f.event(out);
        CHECK(f.packets.size() == 2 && f.packets.back().action == LI_TOUCH_EVENT_CANCEL_ALL);
    }
    {
        Fixture f; f.down();
        f.event(point(SDL_EVENT_PEN_DOWN, 2, contact, 100, 100, 2)); f.pen.flush();
        CHECK(f.packets.size() == 3 && f.packets[1].action == LI_TOUCH_EVENT_CANCEL_ALL);
        CHECK(f.packets[2].pressure == 0); // New pen never inherits pressure.
    }
    {
        Fixture f; f.down();
        auto invalid = point(SDL_EVENT_PEN_AXIS, 2, contact);
        invalid.paxis.value = std::numeric_limits<float>::quiet_NaN();
        f.event(invalid); f.pen.flush();
        CHECK(f.packets.back().action == LI_TOUCH_EVENT_CANCEL_ALL);
    }
    {
        Fixture f; f.accept = false; f.down(); f.down(2); f.pen.suspend();
        CHECK(f.packets.empty() && f.failures == 1);
    }
    {
        Fixture f;
        f.event(point(SDL_EVENT_PEN_DOWN, 1, contact));
        f.event(point(SDL_EVENT_PEN_UP, 1, hover)); f.pen.flush();
        CHECK(f.packets.size() == 2); // Never merge distinct contact transitions.
        CHECK(f.packets[0].action == LI_TOUCH_EVENT_DOWN && f.packets[1].action == LI_TOUCH_EVENT_UP);
    }
    {
        Fixture f;
        f.event(point(SDL_EVENT_PEN_MOTION, 1, hover));
        SDL_Event key{}; key.key.type = SDL_EVENT_KEY_DOWN; key.key.timestamp = 2;
        f.event(key);
        CHECK(f.packets.size() == 1 && !f.pen.pending()); // Pen precedes modifier.
        auto next = point(SDL_EVENT_PEN_MOTION, 3, contact); f.event(next);
        SDL_Event mouse{}; mouse.motion.type = SDL_EVENT_MOUSE_MOTION;
        mouse.motion.timestamp = 4; f.event(mouse);
        CHECK(f.packets.size() == 2); // Ordinary mouse is also an ordering boundary.
    }
    {
        int localSamples = 0, resets = 0, remote = 0;
        float localX = 0;
        MacPenInput pen{
            [&](const MacPenInput::Packet&) { ++remote; return true; },
            [](SDL_WindowID,float,float,float&,float&) { return false; },
            [] { CHECK(false); },
            [&](SDL_PenID,SDL_WindowID,float x,float,SDL_PenInputFlags,Uint64) {
                ++localSamples; localX = x; return true;
            }, [&] { ++resets; }};
        pen.handle(point(SDL_EVENT_PEN_DOWN,1,contact,10));
        pen.handle(point(SDL_EVENT_PEN_MOTION,1,contact,600));
        CHECK(localSamples == 0);
        pen.flush();
        CHECK(localSamples == 1 && localX == 600 && remote == 0);
        pen.suspend(false); // Local toolbar takes ownership of this drag.
        pen.handle(point(SDL_EVENT_PEN_MOTION,2,contact,700)); pen.flush();
        CHECK(localSamples == 2 && localX == 700);
        const int before = resets;
        pen.suspend(); // Focus loss must prevent a held pen clicking on return.
        CHECK(resets == before + 1);
        pen.handle(point(SDL_EVENT_PEN_MOTION,3,contact,500)); pen.flush();
        CHECK(localSamples == 2);
        pen.handle(point(SDL_EVENT_PEN_UP,4,hover,500)); pen.flush();
        CHECK(localSamples == 3 && remote == 0);
    }
    {
        Fixture f;
        f.event(point(SDL_EVENT_PEN_MOTION,1,hover | SDL_PEN_INPUT_BUTTON_1)); f.pen.flush();
        f.pen.suspend();
        f.event(point(SDL_EVENT_PEN_MOTION,2,hover | SDL_PEN_INPUT_BUTTON_1)); f.pen.flush();
        CHECK(f.packets.size() == 2); // Held barrel button also waits for release.
        f.event(point(SDL_EVENT_PEN_MOTION,3,hover)); f.pen.flush();
        CHECK(f.packets.size() == 3 && f.packets.back().buttons == 0);
    }
    for (const auto& sample : std::vector<std::pair<float,int>>{{30,0},{-30,180},{90,0},{-90,180}}) {
        Fixture f;
        auto tilt = point(SDL_EVENT_PEN_AXIS,1,hover);
        tilt.paxis.axis = SDL_PEN_AXIS_YTILT; tilt.paxis.value = sample.first;
        f.event(tilt); f.pen.flush();
        CHECK(f.packets.back().rotation == sample.second);
        CHECK(f.packets.back().tilt == std::abs(sample.first));
    }
    std::printf("macos_client_pen assertions=%d result=PASS physical_input=false\n", checks);
}
