// Local, foreground-only Wacom diagnostic. No host, networking or injection.
#include "../../apps/client/app/streaming/input/macpen.h"
#include <cstdio>
#include <cstring>
#include <set>

int main(int argc, char** argv)
{
    if (argc > 1) {
        if (argc == 2 && std::strcmp(argv[1], "--help") == 0) {
            std::puts("Local pen monitor: move, draw, flip the eraser and press barrel buttons. Escape closes; timeout is two minutes. No host connection.");
            return 0;
        }
        return 2;
    }
    if (!SDL_Init(SDL_INIT_VIDEO)) { std::fprintf(stderr,"%s\n",SDL_GetError()); return 1; }
    SDL_Window* window = SDL_CreateWindow("Teraguchi local pen check",800,480,0);
    SDL_Renderer* renderer = window ? SDL_CreateRenderer(window,nullptr) : nullptr;
    if (!renderer) { SDL_DestroyWindow(window); SDL_Quit(); return 1; }
    const SDL_WindowID windowId = SDL_GetWindowID(window);
    MacPenInput::Packet latest;
    std::set<float> pressures;
    unsigned packets = 0, penEvents = 0;
    MacPenInput input{
        [&](const MacPenInput::Packet& packet) {
            latest = packet; ++packets;
            if (packet.pressure > 0) pressures.insert(packet.pressure);
            return true;
        },
        [&](SDL_WindowID id,float x,float y,float& nx,float& ny) {
            nx=x/800; ny=y/480;
            return id==windowId && (SDL_GetWindowFlags(window)&SDL_WINDOW_INPUT_FOCUS) &&
                    x>=0 && x<800 && y>=0 && y<480;
        }, [] {} };
    bool running = true;
    const Uint64 start = SDL_GetTicks();
    while (running && SDL_GetTicks()-start < 120000) {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            input.beforeEvent(event);
            if (MacPenInput::isPenEvent(event.type)) { ++penEvents; input.handle(event); }
            if (event.type == SDL_EVENT_QUIT ||
                    (event.type == SDL_EVENT_KEY_DOWN && event.key.key == SDLK_ESCAPE)) running=false;
            if (event.type == SDL_EVENT_WINDOW_FOCUS_LOST) input.suspend();
        }
        input.flush();
        SDL_SetRenderDrawColor(renderer,22,25,31,255); SDL_RenderClear(renderer);
        SDL_SetRenderDrawColor(renderer,235,240,245,255);
        SDL_RenderDebugText(renderer,20,20,"LOCAL PEN CHECK - no Flame connection");
        SDL_RenderDebugText(renderer,20,45,"Move the pen. Press lightly, then firmly. Try eraser and side buttons.");
        SDL_RenderDebugText(renderer,20,65,"Escape closes. This window closes automatically after two minutes.");
        char text[200];
        std::snprintf(text,sizeof(text),"Tool: %s  Pressure: %.6f  Buttons: %u  Tilt: %u  Direction: %u",
                      latest.tool==LI_TOOL_TYPE_ERASER?"eraser":"pen",latest.pressure,
                      latest.buttons,latest.tilt,latest.rotation);
        SDL_RenderDebugText(renderer,20,110,text);
        std::snprintf(text,sizeof(text),"Pen events: %u  Samples: %u  Distinct pressure values: %zu",
                      penEvents,packets,pressures.size());
        SDL_RenderDebugText(renderer,20,135,text);
        SDL_SetRenderDrawColor(renderer,80,190,225,255);
        SDL_FRect bar{20,175,760*latest.pressure,30}; SDL_RenderFillRect(renderer,&bar);
        SDL_FRect pointer{latest.x*800-5,latest.y*480-5,10,10}; SDL_RenderFillRect(renderer,&pointer);
        SDL_RenderPresent(renderer); SDL_Delay(16);
    }
    input.suspend();
    std::printf("local_pen_monitor events=%u samples=%u distinct_pressure_values=%zu host_connected=false\n",
                penEvents,packets,pressures.size());
    SDL_DestroyRenderer(renderer); SDL_DestroyWindow(window); SDL_Quit();
}
