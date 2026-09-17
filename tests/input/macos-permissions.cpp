#include "backend/teraguchi/macinputpermissions.h"
#include "backend/teraguchi/macstartuparguments.h"
#include <QSignalSpy>
#include <QTest>

class PermissionTests : public QObject {
    Q_OBJECT
private slots:
    void requestsAreExplicitAndDoNotImplyAccess() {
        int opens = 0;
        QList<MacInputPermissions::Permission> requests;
        MacInputAccess::Status status{true, false, false};
        MacInputPermissions permissions([&] { return status; }, [&](const QUrl&) { ++opens; return true; },
            [&](MacInputPermissions::Permission permission) { requests.append(permission); });
        permissions.refresh(); permissions.refresh();
        QVERIFY(requests.isEmpty()); QCOMPARE(opens, 0);
        QVERIFY(permissions.requestAccessibility());
        QCOMPARE(requests, QList<MacInputPermissions::Permission>{MacInputPermissions::Permission::Accessibility});
        QVERIFY(!permissions.accessibility()); QVERIFY(!permissions.ready());
        QVERIFY(permissions.requestInputMonitoring());
        QCOMPARE(requests.last(), MacInputPermissions::Permission::InputMonitoring);
        QVERIFY(!permissions.inputMonitoring()); QCOMPARE(opens, 0);
        status = {true, true, true};
        QVERIFY(permissions.requestAccessibility()); QVERIFY(permissions.requestInputMonitoring());
        QCOMPARE(requests.size(), 2); QVERIFY(permissions.ready());
        status.supported = false;
        QVERIFY(!permissions.requestAccessibility()); QVERIFY(!permissions.requestInputMonitoring());
        QCOMPARE(requests.size(), 2);
    }
    void permissionResultIsReadFromTheOsProbe() {
        MacInputAccess::Status status{true, false, false};
        MacInputPermissions permissions([&] { return status; }, [](const QUrl&) { return false; },
            [&](MacInputPermissions::Permission permission) {
                if (permission == MacInputPermissions::Permission::Accessibility) status.accessibility = true;
                else status.inputMonitoring = true;
            });
        QVERIFY(permissions.requestAccessibility()); QVERIFY(permissions.accessibility());
        QVERIFY(!permissions.ready());
        QVERIFY(permissions.requestInputMonitoring()); QVERIFY(permissions.ready());
    }
    void bundleEntryDoesNotNeedASeparateExecutable() {
        const QStringList ordinary{"client"};
        QCOMPARE(TeraguchiStartup::arguments(ordinary, false), ordinary);
        QCOMPARE(TeraguchiStartup::arguments(ordinary, true), QStringList({"client", "--workstations"}));
        for (const auto& args : {QStringList{"client", "--version"}, QStringList{"client", "--help"},
                                QStringList{"client", "--workstations"}, QStringList{"client", "stream", "example"}})
            QCOMPARE(TeraguchiStartup::arguments(args, true), args);
    }
    void readsNeverOpenSettings() {
        int reads = 0, opens = 0;
        MacInputAccess::Status status{true, false, false};
        MacInputPermissions permissions([&] { ++reads; return status; }, [&](const QUrl&) { ++opens; return true; });
        QSignalSpy changes(&permissions, &MacInputPermissions::statusChanged);
        QVERIFY(!permissions.checked()); QVERIFY(!permissions.ready());
        QVERIFY(!permissions.openAccessibilitySettings()); QCOMPARE(opens, 0);
        QVERIFY(!permissions.refresh()); QCOMPARE(reads, 1); QCOMPARE(opens, 0);
        QCOMPARE(changes.size(), 1);
        QVERIFY(!permissions.refresh()); QCOMPARE(changes.size(), 1); QCOMPARE(opens, 0);
        status.accessibility = true;
        QVERIFY(!permissions.refresh()); QCOMPARE(changes.size(), 2);
        status.inputMonitoring = true;
        QVERIFY(permissions.refresh()); QCOMPARE(changes.size(), 3);
        status.accessibility = false;
        QVERIFY(!permissions.refresh()); QCOMPARE(changes.size(), 4);
        QCOMPARE(opens, 0);
    }
    void openingSettingsDoesNotGrantAccess() {
        QList<QUrl> opened;
        bool canOpen = true;
        MacInputPermissions permissions([] { return MacInputAccess::Status{true, false, false}; },
            [&](const QUrl& url) { opened.append(url); return canOpen; });
        permissions.refresh();
        QVERIFY(permissions.openAccessibilitySettings());
        QVERIFY(!permissions.ready()); QVERIFY(!permissions.accessibility());
        QVERIFY(permissions.openInputMonitoringSettings());
        QCOMPARE(opened, QList<QUrl>({QUrl("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"),
                                    QUrl("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")}));
        canOpen = false;
        QVERIFY(!permissions.openInputMonitoringSettings()); QVERIFY(!permissions.ready());
    }
    void platformAndBothGrantsRequired() {
        for (bool supported : {false, true}) {
            for (bool accessibility : {false, true}) {
                for (bool monitoring : {false, true}) {
                    MacInputPermissions permissions([=] { return MacInputAccess::Status{supported, accessibility, monitoring}; },
                        [](const QUrl&) { return true; });
                    QCOMPARE(permissions.refresh(), supported && accessibility && monitoring);
                    QCOMPARE(permissions.openAccessibilitySettings(), supported);
                }
            }
        }
    }
};
QTEST_GUILESS_MAIN(PermissionTests)
#include "macos-permissions.moc"
