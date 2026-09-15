// Real production NvHTTP against synthetic loopback TLS. No real credentials.
#include "backend/nvhttp.h"
#include "backend/nvcomputer.h"
#include <QCoreApplication>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QTimer>
#include <cstdio>

int main(int argc, char** argv)
{
    QCoreApplication app(argc, argv);
    QFile input; if (!input.open(stdin, QIODevice::ReadOnly)) return 2;
    const auto values = QJsonDocument::fromJson(input.readAll()).object();
    const auto mode = values.value("mode").toString();
    const int port = values.value("port").toInt();
    if (port < 1 || port > 65535) return 2;
    const auto now = QDateTime::currentSecsSinceEpoch();
    auto setup = std::make_shared<TeraguchiStudio::Permit>();
    setup->admittedAt = now; setup->profile.issued = now - 60; setup->profile.expires = now + 3600;
    TeraguchiStudio::Workstation host; host.hostId = "host-a";
    for (const auto& value : values.value("pins").toArray()) host.certificates.append(QByteArray::fromHex(value.toString().toLatin1()));
    setup->profile.workstations.insert("node-a", host);
    auto trust = std::make_shared<TeraguchiStudio::HostTrust>();
    trust->setup = setup; trust->nodeId = "node-a"; trust->hostId = "host-a";
    trust->address = "127.0.0.1"; trust->port = static_cast<quint16>(port);
    if (mode == "unknown-host") trust->nodeId = "node-b";
    if (mode == "expired-setup") setup->profile.expires = now;
    if (mode == "development") setup->development = true;
    if (mode == "wrong-port") trust->port = port == 65535 ? 65534 : port + 1;
    bool permitted = true;
    QTimer boundary;
    if (mode == "expiry-during-auth" || mode == "cancel-during-auth") {
        QObject::connect(&boundary, &QTimer::timeout, &app, [&] {
            if (!QFile::exists(values.value("boundary_file").toString())) return;
            if (mode == "expiry-during-auth") setup->profile.expires = QDateTime::currentSecsSinceEpoch();
            else permitted = false;
            boundary.stop();
        });
        boundary.start(5);
    }
    NvHTTP http(NvAddress("127.0.0.1", static_cast<quint16>(port)));
    if (mode != "negative-unpinned") http.setHostTrust(trust, [&] { return permitted; });
    const bool success = mode == "success" || mode == "rotation-overlap" || mode == "negative-unpinned";
    try {
        const auto token = http.authenticate("synthetic-artist", values.value("password").toString());
        if (token != values.value("token").toString()) return 1;
        http.getAppList();
        if (mode == "reconnect-swap") {
            NvComputer snapshot;
            snapshot.activeAddress = http.address(); snapshot.assignedHostTrust = trust;
            NvComputer copied(snapshot);
            NvHTTP reconnect(&copied);
            reconnect.authenticate("synthetic-artist", values.value("password").toString());
        }
        if (!success) return 1;
    } catch (const GfeHttpResponseException&) {
        if (success) return 1;
    } catch (const QtNetworkReplyException&) {
        if (success) return 1;
    }
    std::puts("host_trust_probe=pass");
    return 0;
}
