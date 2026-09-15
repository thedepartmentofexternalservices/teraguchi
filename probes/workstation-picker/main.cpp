// Standalone preview: no ComputerManager, settings, authentication or streaming.
#if defined(__APPLE__) && defined(__aarch64__)
#include <arm_acle.h>
#endif
#include <QCommandLineParser>
#include <QGuiApplication>
#include <QImage>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlNetworkAccessManagerFactory>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTimer>

class BlockedReply final : public QNetworkReply {
public:
    explicit BlockedReply(const QNetworkRequest& request, QObject* parent) : QNetworkReply(parent) {
        setRequest(request);
        setUrl(request.url());
        open(QIODevice::ReadOnly);
        setError(QNetworkReply::ContentAccessDenied, QStringLiteral("Network disabled in UI preview"));
        QTimer::singleShot(0, this, [this] { setFinished(true); emit errorOccurred(error()); emit finished(); });
    }
    void abort() override {}
    qint64 readData(char*, qint64) override { return -1; }
};
class OfflineNetwork final : public QNetworkAccessManager {
public:
    using QNetworkAccessManager::QNetworkAccessManager;
protected:
    QNetworkReply* createRequest(Operation, const QNetworkRequest& request, QIODevice*) override {
        return new BlockedReply(request, this);
    }
};
class OfflineFactory final : public QQmlNetworkAccessManagerFactory {
public:
    QNetworkAccessManager* create(QObject* parent) override { return new OfflineNetwork(parent); }
};
int main(int argc, char** argv) {
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("Teraguchi UI Preview"));
    app.setOrganizationName(QStringLiteral("TeraguchiPreview"));
    QQuickStyle::setStyle(QStringLiteral("Basic"));
    QCommandLineParser parser;
    parser.addHelpOption();
    parser.addOption({"capture", "Save an offscreen preview and exit.", "file"});
    parser.addOption({"scenario", "Sample state to preview.", "name", "ready"});
    parser.addOption({"compact", "Use the minimum supported preview size."});
    parser.addOption({"verify-network-block", "Verify the preview denies network requests without opening a window."});
    parser.process(app);
    if (parser.isSet("verify-network-block")) {
        OfflineNetwork blocked;
        auto* reply = blocked.get(QNetworkRequest(QUrl(QStringLiteral("https://example.invalid/preview-test"))));
        QObject::connect(reply, &QNetworkReply::finished, &app, [&] {
            app.exit(reply->error() == QNetworkReply::ContentAccessDenied && reply->readAll().isEmpty() ? 0 : 5);
        });
        QTimer::singleShot(1000, &app, [&] { app.exit(6); });
        return app.exec();
    }
    const QStringList scenarios {"ready", "offline", "occupied", "incompatible", "empty", "connected",
                                 "interrupted", "display-mismatch", "source-depth", "permissions", "seat-race", "connection-failure",
                                 "power-off", "power-standby", "power-unknown", "power-starting", "power-unavailable", "power-no-access", "power-stale"};
    if (!scenarios.contains(parser.value("scenario"))) return 2;
    OfflineFactory network;
    QQmlApplicationEngine engine;
    engine.setNetworkAccessManagerFactory(&network);
    bool qmlWarnings = false;
    QObject::connect(&engine, &QQmlEngine::warnings, &app, [&](const QList<QQmlError>&) { qmlWarnings = true; });
    engine.rootContext()->setContextProperty("initialScenario", parser.value("scenario"));
    engine.rootContext()->setContextProperty("previewWidth", parser.isSet("compact") ? 860 : 1120);
    engine.rootContext()->setContextProperty("previewHeight", parser.isSet("compact") ? 680 : 790);
    engine.load(QUrl(QStringLiteral("qrc:/preview/Preview.qml")));
    if (engine.rootObjects().isEmpty()) return 3;
    if (parser.isSet("capture")) {
        QTimer::singleShot(1800, &app, [&] {
            auto* window = qobject_cast<QQuickWindow*>(engine.rootObjects().first());
            const QImage image = window ? window->grabWindow() : QImage();
            app.exit(!qmlWarnings && !image.isNull() && image.save(parser.value("capture")) ? 0 : 4);
        });
    }
    return app.exec();
}
