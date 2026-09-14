// Headless regression test for Qt application Quit while SDL owns the loop.
#include <QCoreApplication>
#include <QElapsedTimer>
#include <QTimer>
#define SDL_MAIN_HANDLED
#include <SDL3/SDL_main.h>
#include <cstring>
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
    SDL_SetMainReady();
    TestApplication application(argc, argv);
#ifndef TEST_WITHOUT_BRIDGE
    MacQuitBridge bridge(application);
#endif
    const bool idle = !strcmp(argv[1], "idle");
    const bool nativeQuit = !strcmp(argv[1], "streaming");
    const bool disconnect = !strcmp(argv[1], "disconnect");
    const bool unrelated = !strcmp(argv[1], "unrelated");
    if (!idle && !nativeQuit && !disconnect && !unrelated) return 2;
    if (!idle && !SDL_Init(SDL_INIT_EVENTS)) return 3;
    bool cleanedUp = false;
    bool qtResumed = false;
    int failure = 0;
    QTimer::singleShot(0, [&] {
        if (idle || nativeQuit) {
            // Equivalent to the synchronous Quit delivered by the Cocoa QPA.
            QEvent event(QEvent::Quit);
            QCoreApplication::sendEvent(&application, &event);
        }
        else if (disconnect) {
            SDL_Event event = {};
            event.type = SDL_EVENT_QUIT;
            SDL_PushEvent(&event);
        }
        else {
            QEvent event(QEvent::User);
            QCoreApplication::sendEvent(&application, &event);
            if (SDL_HasEvent(SDL_EVENT_QUIT)) failure = 14;
            application.exit();
            return;
        }
        if (idle) return;

        QElapsedTimer deadline;
        deadline.start();
        SDL_Event event;
        bool received = false;
        while (deadline.elapsed() < 250 && !received) {
            if (SDL_PollEvent(&event) && event.type == SDL_EVENT_QUIT)
                received = true;
        }
        if (!received) {
            failure = 11;
            application.exit();
            return;
        }
        cleanedUp = true;
        if (disconnect) {
            QTimer::singleShot(0, [&] {
                qtResumed = true;
                application.exit();
            });
        }
    });
    application.exec();
    if (nativeQuit && (!cleanedUp || application.quitEvents != 1)) failure = 12;
    if (idle && application.quitEvents != 1) failure = 13;
    if (disconnect && (!cleanedUp || !qtResumed || application.quitEvents != 0)) failure = 15;
    SDL_Quit();
    return failure;
}
