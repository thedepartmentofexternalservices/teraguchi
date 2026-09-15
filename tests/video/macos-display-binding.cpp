#include <QtTest>
#include "backend/teraguchi/macdisplaybinding.h"
#include "streaming/macpresentationwindows.h"
using namespace MacDisplayBinding;
class DisplayTests : public QObject {
    Q_OBJECT
    QVector<Display> inventory() {
        return {{7, "left", 1, QRect(-1920, 0, 1920, 1080), QSize(3840,2160), QSize(3840,2160), 5, 60, 0, false},
                {9, "right", 1, QRect(0, 100, 2560,1440), QSize(2560,1440), QSize(2560,1440), 6, 60, 0, false}};
    }
private slots:
    void bindOneAndTwo() {
        const auto inputs = inventory();
        const auto one = select(inputs, inputs[1].bounds, 1);
        QCOMPARE(one.primary, 9u); QCOMPARE(one.outputs.size(), 1);
        QVERIFY(current(one, inputs));
        const auto two = select(inputs, inputs[1].bounds, 2);
        QCOMPARE(two.primary, 9u); QCOMPARE(two.outputs, inputs);
        QVERIFY(current(two, inputs));
        auto reordered = inputs; std::reverse(reordered.begin(), reordered.end());
        QVERIFY(current(two, reordered));
        QCOMPARE(select(reordered, inputs[1].bounds, 2).outputs, inputs);
        QVERIFY(select(inputs, QRect(0,0,10,10), 1).outputs.isEmpty());
    }
    void unsupportedCountsAndLayouts() {
        auto inputs = inventory();
        for (int count : {-1,0,3}) QVERIFY(select(inputs, inputs[0].bounds, count).outputs.isEmpty());
        auto extra = inputs[0]; extra.id = 12; extra.identity = "extra"; extra.bounds.translate(-3000,0);
        inputs.append(extra);
        QVERIFY(select(inputs, inputs[0].bounds, 2).outputs.isEmpty());
        QVERIFY(!select(inputs, inputs[0].bounds, 1).outputs.isEmpty());
        inputs = inventory(); inputs[1].bounds.moveTop(1080);
        QVERIFY(select(inputs, inputs[0].bounds, 2).outputs.isEmpty());
        inputs = inventory(); inputs[1].bounds.moveLeft(-100);
        QVERIFY(select(inputs, inputs[0].bounds, 2).outputs.isEmpty());
        inputs = inventory(); inputs[1].mirrored = true;
        QVERIFY(select(inputs, inputs[0].bounds, 2).outputs.isEmpty());
        inputs = inventory(); inputs[1].rotation = 90;
        QVERIFY(select(inputs, inputs[0].bounds, 2).outputs.isEmpty());
    }
    void changes_data() {
        QTest::addColumn<int>("field");
        const char* names[] = {"identity", "id", "unplug-replug", "position", "logical-size", "pixels", "native-pixels", "mode", "refresh", "rotation", "mirroring", "missing"};
        for (int i=0; i<12; ++i) QTest::newRow(names[i]) << i;
    }
    void changes() {
        QFETCH(int, field);
        auto inputs = inventory(); const auto two = select(inputs, inputs[1].bounds, 2);
        switch(field) {
        case 0: inputs[0].identity = "replacement"; break;
        case 1: ++inputs[0].id; break;
        case 2: ++inputs[0].generation; break;
        case 3: inputs[0].bounds.translate(1,0); break;
        case 4: inputs[0].bounds.setWidth(1800); break;
        case 5: inputs[0].pixels.setWidth(1920); break;
        case 6: inputs[0].nativePixels.setWidth(1920); break;
        case 7: ++inputs[0].mode; break;
        case 8: inputs[0].refresh = 59.94; break;
        case 9: inputs[0].rotation = 90; break;
        case 10: inputs[0].mirrored = true; break;
        case 11: inputs.removeFirst(); break;
        }
        QVERIFY(!current(two, inputs));
    }
    void unselectedDisplayChange() {
        auto inputs = inventory(); auto one = select(inputs, inputs[1].bounds, 1);
        inputs.removeFirst(); QVERIFY(current(one, inputs));
        one.primary = 999; QVERIFY(!current(one, inputs));
    }
    void ambiguity() {
        auto inputs = inventory(); const auto two = select(inputs, inputs[1].bounds, 2);
        inputs[1].id = inputs[0].id; QVERIFY(!current(two, inputs));
        inputs = inventory(); inputs[1].identity = inputs[0].identity;
        QVERIFY(select(inputs, inputs[0].bounds, 1).outputs.isEmpty());
        inputs = inventory(); inputs[1].bounds = inputs[0].bounds;
        QVERIFY(select(inputs, inputs[0].bounds, 1).outputs.isEmpty());
    }
    void sdlMappingDoesNotUseEnumerationOrder() {
        const auto inputs = inventory(); const auto two = select(inputs, inputs[1].bounds, 2);
        QVector<Surface> surfaces = {{200, inputs[1].bounds}, {100, inputs[0].bounds}};
        QCOMPARE(resolve(two, surfaces), QVector<quint32>({100,200}));
        surfaces[0].id = 100; QVERIFY(resolve(two, surfaces).isEmpty());
        surfaces = {{100, inputs[0].bounds}}; QVERIFY(resolve(two, surfaces).isEmpty());
        surfaces.append({200, inputs[0].bounds}); QVERIFY(resolve(two, surfaces).isEmpty());
    }
    void pairedFramesKeepEachOutput() {
        for (const auto& display : inventory()) {
            QCOMPARE(MacPresentationWindows::frame(display.bounds, true), display.bounds);
            const auto windowed = MacPresentationWindows::frame(display.bounds, false);
            QVERIFY(display.bounds.contains(windowed));
            QCOMPARE(windowed.width(), display.bounds.width()*4/5);
        }
    }
    void systemUiFollowsPairFocusAndVisibility() {
        using MacPresentationWindows::needsHiddenSystemUi;
        const SDL_WindowFlags focused = SDL_WINDOW_INPUT_FOCUS | SDL_WINDOW_BORDERLESS;
        const SDL_WindowFlags unfocused = SDL_WINDOW_BORDERLESS;
        QVERIFY(needsHiddenSystemUi(true, focused, unfocused));
        QVERIFY(needsHiddenSystemUi(true, unfocused, focused));
        QVERIFY(!needsHiddenSystemUi(false, focused, unfocused));
        QVERIFY(!needsHiddenSystemUi(true, unfocused, unfocused));
        for (const auto unavailable : {SDL_WINDOW_HIDDEN, SDL_WINDOW_MINIMIZED}) {
            QVERIFY(!needsHiddenSystemUi(true, focused | unavailable, unfocused));
            QVERIFY(!needsHiddenSystemUi(true, focused, unfocused | unavailable));
        }
    }
};
QTEST_GUILESS_MAIN(DisplayTests)
#include "macos-display-binding.moc"
