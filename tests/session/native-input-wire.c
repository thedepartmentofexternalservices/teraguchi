// Actual common-c input worker, with an in-memory native sender only.
// No host, socket, input device, desktop or upstream application version.
#include "Limelight-internal.h"
#include "plank_transport_input.h"
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>

#define CHECK(x) do { if (!(x)) { fprintf(stderr, "line %d failed\n", __LINE__); exit(1); } } while (0)
static struct { uint8_t type; size_t size; uint8_t payload[32]; } records[32];
static atomic_uint count;
static int sendNative(void* context, uint8_t type, const uint8_t* data, size_t size) {
    (void)context;
    unsigned index = atomic_load(&count);
    CHECK(index < 32 && size <= 32);
    records[index].type = type; records[index].size = size;
    memcpy(records[index].payload, data, size);
    atomic_store(&count, index + 1);
    return 0;
}
static void waitFor(unsigned total) {
    for (unsigned i = 0; atomic_load(&count) < total && i < 200; ++i) PltSleepMs(5);
    CHECK(atomic_load(&count) == total);
}
int main(void) {
    CHECK(initializePlatform() == 0);
    LiSetPlankNativeInputSender(sendNative, NULL);
    CHECK(initializeInputStream() == 0 && startInputStream() == 0);
    CHECK(LiSendMousePositionEvent(123, 456, 1920, 1080) == 0); waitFor(1);
    CHECK(records[0].type == PLANK_TRANSPORT_INPUT_ABSOLUTE_MOUSE && records[0].size == 8);
    CHECK(plank_transport_input_read_u16(records[0].payload) == 123);
    CHECK(plank_transport_input_read_u16(records[0].payload + 2) == 456);
    CHECK(plank_transport_input_read_u16(records[0].payload + 4) == 1919);
    CHECK(plank_transport_input_read_u16(records[0].payload + 6) == 1079);
    CHECK(LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_LEFT) == 0); waitFor(2);
    CHECK(LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT) == 0); waitFor(3);
    CHECK(records[1].type == PLANK_TRANSPORT_INPUT_MOUSE_BUTTON && records[1].payload[1] == 1);
    CHECK(records[2].type == PLANK_TRANSPORT_INPUT_MOUSE_BUTTON && records[2].payload[1] == 0);
    CHECK(LiSendKeyboardEvent2(0x41, KEY_ACTION_DOWN, MODIFIER_CTRL, 0) == 0); waitFor(4);
    CHECK(LiSendKeyboardEvent2(0x41, KEY_ACTION_UP, 0, 0) == 0); waitFor(5);
    CHECK(records[3].type == PLANK_TRANSPORT_INPUT_KEYBOARD && records[3].payload[2] == 1);
    CHECK(records[3].payload[3] == MODIFIER_CTRL && records[4].payload[2] == 0);
    CHECK(LiSendHighResScrollEvent(30) == 0); waitFor(6);
    CHECK(LiSendHighResHScrollEvent(-30) == 0); waitFor(7);
    CHECK(records[5].type == PLANK_TRANSPORT_INPUT_VERTICAL_SCROLL);
    CHECK(plank_transport_input_read_u16(records[5].payload) == 30);
    CHECK(records[6].type == PLANK_TRANSPORT_INPUT_HORIZONTAL_SCROLL);
    CHECK((int16_t)plank_transport_input_read_u16(records[6].payload) == -30);
    SunshineFeatureFlags |= LI_FF_PEN_TOUCH_EVENTS;
    // Queue the entire chord/stroke without per-packet waits. Motion batching
    // must not move pressure changes across a keyboard transition.
    CHECK(LiSendKeyboardEvent2(0x80A2, KEY_ACTION_DOWN, MODIFIER_CTRL, 0) == 0);
    CHECK(LiSendPenEvent(LI_TOUCH_EVENT_DOWN, LI_TOOL_TYPE_PEN, LI_PEN_BUTTON_PRIMARY,
                        0.25f,0.5f,1.0f/8191.0f,0,0,270,30) == 0);
    CHECK(LiSendPenEvent(LI_TOUCH_EVENT_MOVE, LI_TOOL_TYPE_PEN, LI_PEN_BUTTON_PRIMARY,
                        0.3f,0.5f,0.25f,0,0,270,30) == 0);
    CHECK(LiSendKeyboardEvent2(0x80A0, KEY_ACTION_DOWN, MODIFIER_CTRL|MODIFIER_SHIFT, 0) == 0);
    CHECK(LiSendPenEvent(LI_TOUCH_EVENT_MOVE, LI_TOOL_TYPE_PEN, LI_PEN_BUTTON_PRIMARY,
                        0.4f,0.5f,0.75f,0,0,270,30) == 0);
    CHECK(LiSendPenEvent(LI_TOUCH_EVENT_UP, LI_TOOL_TYPE_PEN, 0,
                        0.4f,0.5f,0,0,0,270,30) == 0);
    CHECK(LiSendKeyboardEvent2(0x80A0, KEY_ACTION_UP, MODIFIER_CTRL, 0) == 0);
    CHECK(LiSendKeyboardEvent2(0x80A2, KEY_ACTION_UP, 0, 0) == 0);
    CHECK(LiSendPenEvent(LI_TOUCH_EVENT_CANCEL_ALL, LI_TOOL_TYPE_UNKNOWN, 0,
                        0,0,0,0,0,0,0) == 0);
    waitFor(16);
    CHECK(records[7].type == PLANK_TRANSPORT_INPUT_KEYBOARD && records[7].payload[2] == 1);
    CHECK(plank_transport_input_read_u16(records[7].payload) == 0x80A2);
    CHECK(records[8].type == PLANK_TRANSPORT_INPUT_PEN && records[8].payload[0] == LI_TOUCH_EVENT_DOWN);
    CHECK(records[8].payload[2] == LI_PEN_BUTTON_PRIMARY);
    CHECK(plank_transport_input_read_float(records[8].payload + 16) == 1.0f/8191.0f);
    CHECK(records[9].type == PLANK_TRANSPORT_INPUT_PEN && records[9].payload[0] == LI_TOUCH_EVENT_MOVE);
    CHECK(plank_transport_input_read_float(records[9].payload + 16) == 0.25f);
    CHECK(records[10].type == PLANK_TRANSPORT_INPUT_KEYBOARD && records[10].payload[2] == 1);
    CHECK(plank_transport_input_read_u16(records[10].payload) == 0x80A0);
    CHECK(records[11].type == PLANK_TRANSPORT_INPUT_PEN && records[11].payload[0] == LI_TOUCH_EVENT_MOVE);
    CHECK(plank_transport_input_read_float(records[11].payload + 16) == 0.75f);
    CHECK(records[12].type == PLANK_TRANSPORT_INPUT_PEN && records[12].payload[0] == LI_TOUCH_EVENT_UP);
    CHECK(records[13].type == PLANK_TRANSPORT_INPUT_KEYBOARD && records[13].payload[2] == 0);
    CHECK(records[14].type == PLANK_TRANSPORT_INPUT_KEYBOARD && records[14].payload[2] == 0);
    CHECK(records[15].type == PLANK_TRANSPORT_INPUT_PEN && records[15].payload[0] == LI_TOUCH_EVENT_CANCEL_ALL);
    CHECK(stopInputStream() == 0); destroyInputStream(); cleanupPlatform();
    puts("native_input_wire=pass absolute_geometry=1 buttons=1 modifiers=1 scrolling=1 modifier_pen_order=1 pressure_float=1 appversion_required=0");
}
