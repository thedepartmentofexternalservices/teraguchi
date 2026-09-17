#include <QTest>
#include "streaming/video/ffmpeg-renderers/vt_presentation.h"

class PresentationTests : public QObject {
    Q_OBJECT
    SDL_Window* first = reinterpret_cast<SDL_Window*>(1);
    SDL_Window* second = reinterpret_cast<SDL_Window*>(2);
    PlankPresentationLayout dual() const {
        return {QSize(7680, 2160), {{first, QRect(0, 0, 3840, 2160), true},
                                  {second, QRect(3840, 0, 3840, 2160), false}}};
    }
private slots:
    void acceptsPrimaryOnEitherSide() {
        auto layout = dual();
        QVERIFY(PlankVT::validLayout(layout, first));
        layout.outputs[0].primary = false; layout.outputs[1].primary = true;
        QVERIFY(PlankVT::validLayout(layout, second));
        std::swap(layout.outputs[0], layout.outputs[1]);
        QVERIFY(PlankVT::validLayout(layout, second));
    }
    void rejectsIncompleteOrAmbiguousTargets() {
        auto layout = dual(); layout.outputs[1].window = nullptr;
        QVERIFY(!PlankVT::validLayout(layout, first));
        layout = dual(); layout.outputs[1].window = first;
        QVERIFY(!PlankVT::validLayout(layout, first));
        layout = dual(); layout.outputs[1].primary = true;
        QVERIFY(!PlankVT::validLayout(layout, first));
        layout = dual(); layout.outputs[0].primary = false;
        QVERIFY(!PlankVT::validLayout(layout, first));
        layout = dual(); layout.outputs.append(layout.outputs.first());
        QVERIFY(!PlankVT::validLayout(layout, first));
        QVERIFY(!PlankVT::validLayout({}, first));
        QVERIFY(!PlankVT::validLayout(dual(), nullptr));
    }
    void rejectsInvalidCanvasGeometry() {
        auto layout = dual(); layout.outputs[1].canvasRect.moveLeft(3800);
        QVERIFY(!PlankVT::validLayout(layout, first));
        layout = dual(); layout.outputs[1].canvasRect.moveLeft(4000);
        QVERIFY(!PlankVT::validLayout(layout, first));
        layout = dual(); layout.canvasSize = QSize(0, 2160);
        QVERIFY(!PlankVT::validLayout(layout, first));
        layout = dual(); layout.outputs[1].canvasRect = {};
        QVERIFY(!PlankVT::validLayout(layout, first));
        layout = dual(); layout.outputs[1].canvasRect.setWidth(100);
        QVERIFY(!PlankVT::validLayout(layout, first));
        layout = dual(); layout.outputs[0].canvasRect.setWidth(100);
        QVERIFY(!PlankVT::validLayout(layout, first));
        layout = dual(); layout.outputs[1].canvasRect.setHeight(1080);
        QVERIFY(PlankVT::validLayout(layout, first));
        layout = dual(); layout.outputs.removeLast();
        QVERIFY(!PlankVT::validLayout(layout, first));
    }
    void exactDualCropsMeetAtSeam() {
        const auto left = PlankVT::outputQuad({7680, 2160}, {7680, 2160}, {0, 0, 3840, 2160});
        const auto right = PlankVT::outputQuad({7680, 2160}, {7680, 2160}, {3840, 0, 3840, 2160});
        QVERIFY(left.visible && right.visible);
        QCOMPARE(left.position, QRectF(-1, -1, 2, 2));
        QCOMPARE(right.position, left.position);
        QCOMPARE(left.texture, QRectF(0, 0, 0.5, 1));
        QCOMPARE(right.texture, QRectF(0.5, 0, 0.5, 1));
    }
    void topAlignedShorterOutputUsesTopOfFrame() {
        const auto quad = PlankVT::outputQuad({24, 8}, {24, 8}, {16, 0, 8, 4});
        QCOMPARE(quad.position, QRectF(-1, -1, 2, 2));
        QCOMPARE(quad.texture, QRectF(2.0 / 3, 0, 1.0 / 3, 0.5));
        const auto vertices = PlankVT::vertices(quad);
        QCOMPARE(vertices[0].texCoord[1], 0.5f); // Bottom vertex samples lower source row.
        QCOMPARE(vertices[1].texCoord[1], 0.0f);
    }
    void letterboxAndInvisibleOutput() {
        auto quad = PlankVT::outputQuad({8, 8}, {16, 8}, {0, 0, 8, 8});
        QCOMPARE(quad.position, QRectF(0, -1, 1, 2));
        QCOMPARE(quad.texture, QRectF(0, 0, 0.5, 1));
        quad = PlankVT::outputQuad({16, 4}, {16, 8}, {0, 0, 8, 8});
        QCOMPARE(quad.position, QRectF(-1, -0.5, 2, 1));
        QVERIFY(!PlankVT::outputQuad({4, 8}, {24, 8}, {0, 0, 8, 8}).visible);
        QVERIFY(!PlankVT::outputQuad({0, 8}, {16, 8}, {0, 0, 8, 8}).visible);
    }
    void matchesInputAtDifferentPixelDensities() {
        const QSize canvas(7680, 2160);
        const QRect output(3840, 0, 3840, 2160);
        const auto quad = PlankVT::outputQuad(canvas, canvas, output);
        for (const auto window : {QSize(3840, 2160), QSize(1920, 1080), QSize(2560, 1440)}) {
            for (const auto fraction : {QPointF(0.001, 0.001), QPointF(0.5, 0.5), QPointF(0.999, 0.999)}) {
                QPointF stream;
                QVERIFY(PlankPresentation::mapWindowPointToStream(
                    {fraction.x() * window.width(), fraction.y() * window.height()},
                    window, canvas, canvas, output, stream, false));
                QVERIFY(qAbs(stream.x() / canvas.width() - (quad.texture.x() + fraction.x() * quad.texture.width())) < 1e-9);
                QVERIFY(qAbs(stream.y() / canvas.height() - (quad.texture.y() + fraction.y() * quad.texture.height())) < 1e-9);
            }
        }
    }
};
QTEST_GUILESS_MAIN(PresentationTests)
#include "macos-presentation.moc"
