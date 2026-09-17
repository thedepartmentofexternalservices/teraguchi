#include "supportdiagnostics.h"
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryDir>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QtTest>
#include <sys/stat.h>

class DiagnosticsTests : public QObject {
    Q_OBJECT
    QVariantMap state() const {
        return {{"studio_setup", "ready"}, {"tailscale", "ready"}, {"phase", "blocked"},
            {"issue", "displays"}, {"catalog_fresh", true}, {"catalog_refreshing", false},
            {"runtime_pending", false}, {"workstation", "ready"}, {"selected_displays", 2.0},
            {"permissions_checked", true}, {"permissions_supported", true},
            {"accessibility", true}, {"input_monitoring", false}};
    }
    QJsonObject status(const QVariantMap& input) const {
        return QJsonDocument::fromJson(SupportDiagnostics::serialize(input, "1.2.3-test", "26.5.2")).object().value("status").toObject();
    }
    QString directory(QTemporaryDir& temporary) const { return QDir(temporary.path()).canonicalPath() + "/reports"; }
private slots:
    void qmlCallsProductionSerializerWithTypedValues() {
        qmlRegisterType<SupportDiagnostics>("SupportDiagnostics", 1, 0, "SupportDiagnostics");
        QQmlEngine engine;
        QQmlComponent component(&engine);
        component.setData(R"(import QtQml
import SupportDiagnostics 1.0
SupportDiagnostics {
    Component.onCompleted: prepare({phase: "blocked", issue: "displays", selected_displays: 2,
        permissions_checked: true, permissions_supported: true, accessibility: true, input_monitoring: false})
})", QUrl());
        std::unique_ptr<QObject> object(component.create());
        QVERIFY2(object, qPrintable(component.errorString()));
        const auto values = QJsonDocument::fromJson(object->property("preview").toString().toUtf8()).object().value("status").toObject();
        QCOMPARE(values.value("selected_displays").toInt(), 2);
        QCOMPARE(values.value("accessibility").toString(), QString("allowed"));
        QCOMPARE(values.value("input_monitoring").toString(), QString("needed"));
        QCOMPARE(values.value("issue").toString(), QString("displays"));
        QVERIFY(!object->property("saved").toBool());
    }
    void exactSchemaAndHonestQualification() {
        const auto bytes = SupportDiagnostics::serialize(state(), "1.2.3-test-candidate", "26.5.2");
        QVERIFY(bytes.size() < 4096);
        const auto root = QJsonDocument::fromJson(bytes).object();
        QCOMPARE(root.keys(), QStringList({"client_version", "os_version", "platform", "qt_version", "schema_version", "scope", "status"}));
        QCOMPARE(root.value("client_version").toString(), QString("1.2.3"));
        QCOMPARE(root.value("scope").toString(), QString("launcher-status-only"));
        const auto values = root.value("status").toObject();
        QCOMPARE(values.size(), 14);
        QCOMPARE(values.value("selected_displays").toInt(), 2);
        QCOMPARE(values.value("input_monitoring").toString(), QString("needed"));
        for (const auto* name : {"tablet_path", "physical_displays", "video_path"})
            QCOMPARE(values.value(name).toString(), QString("not-tested"));
    }
    void privateDataNeverPassesThrough() {
        auto input = state();
        const QString canary = "SYNTHETIC-PRIVATE-CANARY";
        for (const auto* key : {"username", "password", "token", "address", "certificate", "node_id", "host_id", "serial", "log", "artwork", "pen", "keystrokes", "error"})
            input.insert(key, QVariantMap{{"nested", canary}});
        for (const auto* key : {"studio_setup", "tailscale", "phase", "issue", "workstation"})
            input.insert(key, canary);
        const auto bytes = SupportDiagnostics::serialize(input, "1.2.3-" + canary, canary);
        QVERIFY(!bytes.contains(canary.toUtf8()));
        const auto root = QJsonDocument::fromJson(bytes).object();
        QCOMPARE(root.value("client_version").toString(), QString("1.2.3"));
        QCOMPARE(root.value("os_version").toString(), QString("unknown"));
        QCOMPARE(root.value("status").toObject().value("issue").toString(), QString("unknown"));
    }
    void oversizedAndNestedInputsStayBounded() {
        auto input = state();
        for (const auto& key : input.keys()) input[key] = QString(1024 * 1024, 'x');
        input.insert("logs", QVariantList{input, input});
        const auto bytes = SupportDiagnostics::serialize(input, QString(1024 * 1024, 'x'), "26.5.2");
        QVERIFY(bytes.size() < 4096);
        QVERIFY(!bytes.contains(QByteArray(65, 'x')));
    }
    void booleansCannotBeCoerced() {
        auto input = state();
        for (const auto& fake : {QVariant("true"), QVariant(1), QVariant(QVariantList{true})}) {
            input["accessibility"] = fake;
            input["catalog_fresh"] = fake;
            QCOMPARE(status(input).value("accessibility").toString(), QString("unknown"));
            QCOMPARE(status(input).value("catalog").toString(), QString("unknown"));
        }
    }
    void uncheckedAndUnsupportedAreExplicit() {
        auto input = state();
        input["permissions_checked"] = false;
        QCOMPARE(status(input).value("accessibility").toString(), QString("unknown"));
        input["permissions_checked"] = true;
        input["permissions_supported"] = false;
        QCOMPARE(status(input).value("accessibility").toString(), QString("unsupported"));
        QCOMPARE(status({}).value("selected_displays"), QJsonValue(QJsonValue::Null));
    }
    void displayCountCannotBeCoerced() {
        auto input = state();
        for (const auto& fake : {QVariant("2"), QVariant(true), QVariant(3), QVariant(1.5)}) {
            input["selected_displays"] = fake;
            QVERIFY(status(input).value("selected_displays").isNull());
        }
    }
    void versionCannotContainPathsOrText() {
        for (const auto& value : {QString("1.2.3\nPRIVATE"), QString("/Users/example/1.2.3"), QString("PRIVATE")}) {
            const auto root = QJsonDocument::fromJson(SupportDiagnostics::serialize({}, value, value)).object();
            QCOMPARE(root.value("client_version").toString(), QString("unknown"));
            QCOMPARE(root.value("os_version").toString(), QString("unknown"));
        }
    }
    void previewHasNoFileOrOpenerSideEffects() {
        QTemporaryDir temporary;
        const auto path = directory(temporary);
        int opens = 0;
        SupportDiagnostics report(path, [&](const QUrl&) { ++opens; return true; });
        QVERIFY(!report.save());
        QVERIFY(!report.showFolder());
        report.prepare(state());
        QVERIFY(!report.preview().isEmpty());
        QVERIFY(!QFileInfo::exists(path));
        QCOMPARE(opens, 0);
    }
    void savedBytesMatchReviewedPreviewAndStayPrivate() {
        QTemporaryDir temporary;
        const auto path = directory(temporary);
        SupportDiagnostics report(path, [](const QUrl&) { return false; });
        report.prepare(state());
        const auto preview = report.preview().toUtf8();
        QVERIFY(report.save());
        const auto files = QDir(path).entryList({"support-*.json"}, QDir::Files);
        QCOMPARE(files.size(), 1);
        QFile file(path + '/' + files.first());
        QVERIFY(file.open(QIODevice::ReadOnly));
        QCOMPARE(file.readAll(), preview);
        struct stat info {};
        QVERIFY(::stat(QFile::encodeName(path).constData(), &info) == 0);
        QCOMPARE(info.st_mode & 0777, mode_t(0700));
        QVERIFY(::stat(QFile::encodeName(file.fileName()).constData(), &info) == 0);
        QCOMPARE(info.st_mode & 0777, mode_t(0600));
        QVERIFY(!report.save());
        QCOMPARE(QDir(path).entryList({"support-*.json"}, QDir::Files).size(), 1);
        report.prepare(state());
        QVERIFY(!report.saved());
        QVERIFY(report.save());
        QCOMPARE(QDir(path).entryList({"support-*.json"}, QDir::Files).size(), 2);
    }
    void folderOpensOnlyAfterSaveAndOnExplicitCall() {
        QTemporaryDir temporary;
        const auto path = directory(temporary);
        int opens = 0;
        SupportDiagnostics report(path, [&](const QUrl& url) { ++opens; return url == QUrl::fromLocalFile(path); });
        report.prepare(state());
        QVERIFY(!report.showFolder());
        QVERIFY(report.save());
        QCOMPARE(opens, 0);
        QVERIFY(report.showFolder());
        QCOMPARE(opens, 1);
    }
    void failedFolderOpenRetainsSavedReport() {
        QTemporaryDir temporary;
        SupportDiagnostics report(directory(temporary), [](const QUrl&) { return false; });
        report.prepare(state());
        QVERIFY(report.save());
        QVERIFY(!report.showFolder());
        QVERIFY(report.saved());
        QVERIFY(!report.message().contains(temporary.path()));
    }
    void existingBroadDirectoryIsNotChanged() {
        QTemporaryDir temporary;
        const auto path = directory(temporary);
        QVERIFY(QDir().mkdir(path));
        QVERIFY(::chmod(QFile::encodeName(path).constData(), 0755) == 0);
        SupportDiagnostics report(path, [](const QUrl&) { return false; });
        report.prepare(state());
        QVERIFY(!report.save());
        struct stat info {};
        QVERIFY(::stat(QFile::encodeName(path).constData(), &info) == 0);
        QCOMPARE(info.st_mode & 0777, mode_t(0755));
        QVERIFY(QDir(path).entryList(QDir::Files).isEmpty());
    }
    void symlinkAndGitDestinationsAreRejected() {
        QTemporaryDir temporary;
        const auto base = QDir(temporary.path()).canonicalPath();
        QVERIFY(QDir().mkdir(base + "/real"));
        QVERIFY(QFile::link(base + "/real", base + "/link"));
        QFile marker(base + "/real/.git");
        QVERIFY(marker.open(QIODevice::WriteOnly));
        marker.close();
        for (const auto& path : {base + "/link", base + "/link/reports", base + "/real/reports"}) {
            SupportDiagnostics report(path, [](const QUrl&) { return false; });
            report.prepare(state());
            QVERIFY(!report.save());
        }
        QVERIFY(!QFileInfo::exists(base + "/real/reports"));
    }
};
QTEST_GUILESS_MAIN(DiagnosticsTests)
#include "diagnostics.moc"
