#include "tailscaleworkstations.h"
#include "assignmenttarget.h"
#include <QCoreApplication>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSignalSpy>
#include <QTest>

namespace {
QJsonObject peer(QString id = "node-a", QString name = "flame.studio-example.ts.net.", QString ip = "100.100.1.1")
{
    return {{"ID", id}, {"DNSName", name}, {"HostName", "not-a-trust-signal"},
            {"InNetworkMap", true}, {"Online", true}, {"TailscaleIPs", QJsonArray{ip}}};
}
QJsonObject status()
{
    return {{"BackendState", "Running"}, {"Self", QJsonObject{{"ID", "self-a"}, {"UserID", 123}}},
            {"CurrentTailnet", QJsonObject{{"MagicDNSSuffix", "artist-example.ts.net"}}},
            {"Peer", QJsonObject{{"nodekey:a", peer()}}}};
}
QByteArray bytes(const QJsonObject& value) { return QJsonDocument(value).toJson(QJsonDocument::Compact); }
TailscaleWorkstations::Snapshot parse(const QJsonObject& value)
{
    return TailscaleWorkstations::parseStatus(bytes(value), QStringLiteral("studio-example.ts.net"));
}
}
class ProviderTests : public QObject {
    Q_OBJECT
private slots:
    void loginTargetBinding() {
        QVariantMap expected{{"id", "node-a"}, {"identity", "account-a"}, {"computerId", "bookmark-a"},
                             {"hostId", "host-a"}, {"address", "100.100.1.1"}, {"status", "ready"}};
        QVERIFY(TeraguchiAssignment::matches(expected, expected));
        for (const auto& key : {"id", "identity", "computerId", "hostId", "address", "status"}) {
            auto changed = expected; changed[QLatin1String(key)] = "changed";
            QVERIFY(!TeraguchiAssignment::matches(expected, changed));
            auto missing = expected; missing.remove(QLatin1String(key));
            QVERIFY(!TeraguchiAssignment::matches(expected, missing));
        }
    }
    void sharedPeerWithoutTags() {
        const auto result = parse(status());
        QVERIFY(result.valid);
        QCOMPARE(result.workstations.size(), 1);
        const auto entry = result.workstations[0].toMap();
        QCOMPARE(entry["id"].toString(), QString("node-a"));
        QCOMPARE(entry["name"].toString(), QString("flame"));
        QCOMPARE(entry["address"].toString(), QString("100.100.1.1"));
        QVERIFY(!entry.contains("authorized")); QVERIFY(!entry.contains("seatAvailable"));
    }
    void filtersForeignAndReversePeers() {
        auto reverse = peer("recipient", "recipient.studio-example.ts.net.", "100.100.1.2");
        reverse["ShareeNode"] = true;
        auto removed = peer("removed", "removed.studio-example.ts.net.", "100.100.1.3");
        removed["InNetworkMap"] = false;
        auto root = status();
        root["Peer"] = QJsonObject{{"a", peer()}, {"b", peer("foreign", "flame.other-example.ts.net.")},
                                  {"c", reverse}, {"d", removed}, {"e", peer("spoof", "flame.studio-example.ts.net.evil.example.")}};
        const auto result = parse(root);
        QVERIFY(result.valid); QCOMPARE(result.workstations.size(), 1);
    }
    void badSchema_data() {
        QTest::addColumn<QJsonObject>("value");
        auto root = status(); root.remove("Peer"); QTest::newRow("missing peers") << root;
        root = status(); root["Peer"] = QJsonArray(); QTest::newRow("array peers") << root;
        root = status(); root.remove("Self"); QTest::newRow("missing identity") << root;
        root = status(); root["Peer"] = QJsonObject{{"a", peer()}, {"b", peer()}}; QTest::newRow("duplicate id") << root;
        root = status(); root["Peer"] = QJsonObject{{"a", peer()}, {"b", peer("b", "other.studio-example.ts.net.")}}; QTest::newRow("duplicate address") << root;
        root = status(); root["Peer"] = QJsonObject{{"a", peer("a", "flame.studio-example.ts.net.", "192.0.2.1")}}; QTest::newRow("public endpoint") << root;
        auto bad = peer(); bad["Online"] = "true";
        root = status(); root["Peer"] = QJsonObject{{"a", bad}}; QTest::newRow("truthy online") << root;
    }
    void badSchema() { QFETCH(QJsonObject, value); QVERIFY(!parse(value).valid); }
    void unavailableStates_data() {
        QTest::addColumn<QString>("backend"); QTest::addColumn<QString>("expected");
        QTest::newRow("sign in") << "NeedsLogin" << "needs-login";
        QTest::newRow("approve") << "NeedsMachineAuth" << "needs-approval";
        QTest::newRow("stopped") << "Stopped" << "stopped";
        QTest::newRow("starting") << "Starting" << "unavailable";
    }
    void unavailableStates() {
        QFETCH(QString, backend); QFETCH(QString, expected);
        auto root = status(); root["BackendState"] = backend;
        const auto result = parse(root); QVERIFY(!result.valid); QCOMPARE(result.state, expected);
    }
    void invalidStudioConfiguration() {
        for (const auto& value : {"", "ts.net", "*.ts.net", "example.org", "studio-example.ts.net.evil.example"})
            QVERIFY(TailscaleWorkstations::normalizedSuffix(QString::fromLatin1(value)).isEmpty());
        QCOMPARE(TailscaleWorkstations::normalizedSuffix("STUDIO-EXAMPLE.ts.net."), QString("studio-example.ts.net"));
    }
    void malformedAndOversized() {
        QVERIFY(!TailscaleWorkstations::parseStatus("{", "studio-example.ts.net").valid);
        QVERIFY(!TailscaleWorkstations::parseStatus(QByteArray(2 * 1024 * 1024 + 1, ' '), "studio-example.ts.net").valid);
    }
    void ipv6OfflineExpiredAndEmpty() {
        auto root = status(); auto item = peer("a", "flame.studio-example.ts.net.", "fd7a:115c:a1e0::1");
        item["Expired"] = true; root["Peer"] = QJsonObject{{"a", item}};
        auto result = parse(root); QVERIFY(result.valid);
        QCOMPARE(result.workstations[0].toMap()["status"].toString(), QString("offline"));
        root["Peer"] = QJsonObject(); result = parse(root);
        QVERIFY(result.valid); QCOMPARE(result.state, QString("no-shared-workstations"));
    }
    void stableIdSurvivesAddressChange() {
        auto before = parse(status()); auto root = status();
        root["Peer"] = QJsonObject{{"new-key", peer("node-a", "renamed.studio-example.ts.net.", "100.100.1.2")}};
        const auto after = parse(root); QVERIFY(after.valid);
        QCOMPARE(before.workstations[0].toMap()["id"], after.workstations[0].toMap()["id"]);
        QVERIFY(before.workstations[0].toMap()["address"] != after.workstations[0].toMap()["address"]);
    }
    void processAndResolve() {
        TailscaleWorkstations provider(QCoreApplication::applicationFilePath(), {"--fixture", "success"}, nullptr);
        provider.setStudioDnsSuffix("studio-example.ts.net");
        QSignalSpy ready(&provider, &TailscaleWorkstations::catalogReady);
        provider.refresh(7); QVERIFY(provider.busy()); QVERIFY(provider.resolve("node-a").isEmpty());
        QVERIFY(ready.wait(3000)); QCOMPARE(ready.first()[0].toInt(), 7);
        QVERIFY(provider.fresh()); QCOMPARE(provider.resolve("node-a")["address"].toString(), QString("100.100.1.1"));
        QVERIFY(provider.resolve("missing").isEmpty());
        provider.setStudioDnsSuffix("other-example.ts.net");
        QVERIFY(provider.resolve("node-a").isEmpty());
    }
    void failedProcessDoesNotPublish() {
        TailscaleWorkstations provider(QCoreApplication::applicationFilePath(), {"--fixture", "failure"}, nullptr);
        provider.setStudioDnsSuffix("studio-example.ts.net");
        QSignalSpy failed(&provider, &TailscaleWorkstations::catalogFailed);
        QSignalSpy ready(&provider, &TailscaleWorkstations::catalogReady);
        provider.refresh(3); QVERIFY(failed.wait(3000)); QCOMPARE(ready.size(), 0); QVERIFY(!provider.fresh());
    }
    void cancellationAndSupersession() {
        TailscaleWorkstations provider(QCoreApplication::applicationFilePath(), {"--fixture", "delayed"}, nullptr);
        provider.setStudioDnsSuffix("studio-example.ts.net");
        QSignalSpy ready(&provider, &TailscaleWorkstations::catalogReady);
        provider.refresh(1); provider.cancel(999); QVERIFY(provider.busy());
        provider.refresh(2); QVERIFY(ready.wait(3000)); QCOMPARE(ready.size(), 1); QCOMPARE(ready.first()[0].toInt(), 2);
        provider.refresh(3); provider.cancel(3); QTest::qWait(350); QCOMPARE(ready.size(), 1); QVERIFY(!provider.fresh());
    }
};
int main(int argc, char** argv)
{
    QCoreApplication app(argc, argv);
    if (app.arguments().contains("--fixture")) {
        const auto mode = app.arguments().last();
        if (mode == "failure") return 4;
        if (mode == "delayed") QTest::qSleep(200);
        QFile out; out.open(stdout, QIODevice::WriteOnly); out.write(bytes(status())); out.close();
        return 0;
    }
    if (app.arguments().contains("--live-check")) {
        TailscaleWorkstations provider;
        provider.setStudioDnsSuffix(qEnvironmentVariable("TERAGUCHI_TEST_STUDIO_SUFFIX"));
        QObject::connect(&provider, &TailscaleWorkstations::catalogReady, &app, [&](int, const QVariantList& entries, int) {
            qInfo("Local status parsed; %lld studio peers; no host probes or login", static_cast<long long>(entries.size()));
            app.exit(0);
        });
        QObject::connect(&provider, &TailscaleWorkstations::catalogFailed, &app, [&](int, const QString&) {
            qInfo("Local status unavailable or rejected"); app.exit(1);
        });
        QTimer::singleShot(0, &provider, [&] { provider.refresh(1); });
        return app.exec();
    }
    ProviderTests tests;
    return QTest::qExec(&tests, argc, argv);
}
#include "provider.moc"
