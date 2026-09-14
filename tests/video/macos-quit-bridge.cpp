// Exercise the production Quit bridge without a window, Host, or input injection.
#include <QCoreApplication>
#include <QElapsedTimer>
#include <QTimer>
#include <functional>
#include <string>
#define SDL_MAIN_HANDLED
#include <SDL3/SDL_main.h>
#include "macquitbridge.h"

class TestApplication final : public QCoreApplication
{
public:
    using QCoreApplication::QCoreApplication;
    int quitEvents = 0;
protected:
    bool event(QEvent* event) override
    {
        if (event->type() == QEvent::Quit) ++quitEvents;
        return QCoreApplication::event(event);
    }
};

int main(int argc, char** argv)
{
    if (argc != 2) return 2;
    const std::string scenario = argv[1];
    if (scenario != "idle" && scenario != "streaming" && scenario != "disconnect" &&
        scenario != "unrelated" && scenario != "queued-quit" &&
        scenario != "duplicate-quit" && scenario != "after-sdl-shutdown" &&
        scenario != "repeated-disconnect") return 2;
    SDL_SetMainReady();
    TestApplication application(argc, argv);
#ifndef TEST_WITHOUT_BRIDGE
    MacQuitBridge bridge(application);
#endif
    const bool idle = scenario == "idle";
    if (!idle && !SDL_Init(SDL_INIT_EVENTS)) return 3;
    if (scenario == "after-sdl-shutdown") SDL_Quit();
    int failure = 0;
    int cleanedUp = 0;
    int qtResumed = 0;
    auto nativeQuit = [&] {
        QEvent quit(QEvent::Quit);
        QCoreApplication::sendEvent(&application, &quit);
    };
    auto consumeQuit = [&] {
        QElapsedTimer deadline;
        deadline.start();
        SDL_Event event;
        while (deadline.elapsed() < 250) {
            // Queued Qt requests must still reach the production bridge.
            if (scenario == "queued-quit") QCoreApplication::processEvents();
            if (SDL_PollEvent(&event) && event.type == SDL_EVENT_QUIT) {
                ++cleanedUp;
                return true;
            }
        }
        failure = 12;
        application.exit();
        return false;
    };
    std::function<void()> disconnectCycle;
    disconnectCycle = [&] {
        if (qtResumed && !SDL_Init(SDL_INIT_EVENTS)) {
            failure = 3;
            application.exit();
            return;
        }
        SDL_Event quit = {};
        quit.type = SDL_EVENT_QUIT;
        if (!SDL_PushEvent(&quit) || !consumeQuit()) {
            failure = 15;
            application.exit();
            return;
        }
        SDL_Quit();
        QTimer::singleShot(0, [&] {
            ++qtResumed;
            if (scenario == "repeated-disconnect" && qtResumed < 25)
                disconnectCycle();
            else
                nativeQuit();
        });
    };
    // A broken event handoff must fail with a bounded exit, not hang CI.
    QTimer::singleShot(3000, [&] { failure = 20; application.exit(); });
    QTimer::singleShot(0, [&] {
        if (scenario == "disconnect" || scenario == "repeated-disconnect") {
            disconnectCycle();
        }
        else if (scenario == "unrelated") {
            QEvent event(QEvent::User);
            QCoreApplication::sendEvent(&application, &event);
            if (SDL_HasEvent(SDL_EVENT_QUIT)) failure = 14;
            application.exit();
        }
        else if (idle || scenario == "after-sdl-shutdown") {
            nativeQuit();
        }
        else {
            if (scenario == "queued-quit")
                QCoreApplication::postEvent(&application, new QEvent(QEvent::Quit));
            else
                nativeQuit();
            if (scenario == "duplicate-quit") nativeQuit();
            consumeQuit();
        }
    });
    application.exec();
    const int expectedQtQuits = scenario == "unrelated" ? 0 : scenario == "duplicate-quit" ? 2 : 1;
    const int expectedCleanups = scenario == "repeated-disconnect" ? 25 :
        (idle || scenario == "after-sdl-shutdown" || scenario == "unrelated") ? 0 : 1;
    if (application.quitEvents != expectedQtQuits) failure = 13;
    if (cleanedUp != expectedCleanups) failure = 12;
    if ((scenario == "disconnect" || scenario == "repeated-disconnect") && qtResumed != expectedCleanups)
        failure = 15;
    SDL_Quit();
    return failure;
}
