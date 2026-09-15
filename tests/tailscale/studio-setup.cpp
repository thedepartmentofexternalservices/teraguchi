#include <QtTest>
#include <QJsonObject>
#include <QJsonArray>
#include "hosttrust.h"
#include <QJsonDocument>
#include <QTemporaryDir>
#include <QFile>
#include <openssl/evp.h>
#include "studiosetup.h"
#include "tailscaleworkstations.h"
class SetupTests : public QObject {
    Q_OBJECT
    std::unique_ptr<EVP_PKEY, decltype(&EVP_PKEY_free)> key{nullptr, EVP_PKEY_free};
    QByteArray publicKey;
    qint64 now = QDateTime::currentSecsSinceEpoch();
    QJsonObject payload(int revision=1) {
        const auto iso=[](qint64 seconds) { return QDateTime::fromSecsSinceEpoch(seconds,Qt::UTC).toString("yyyy-MM-ddTHH:mm:ss'Z'"); };
        return {{"version",1},{"revision",revision},{"label","Example Studio"},{"dns_suffix","studio-example.ts.net"},
            {"issued_at",iso(now-60)},{"expires_at",iso(now+3600)}};
    }
    QByteArray sign(const QJsonObject& payload, QByteArray domain="Teraguchi studio setup v1\n") {
        const auto bytes=QJsonDocument(payload).toJson(QJsonDocument::Compact);
        const auto message=domain+bytes;
        std::unique_ptr<EVP_MD_CTX,decltype(&EVP_MD_CTX_free)> ctx(EVP_MD_CTX_new(),EVP_MD_CTX_free);
        if (EVP_DigestSignInit(ctx.get(),nullptr,nullptr,nullptr,key.get())!=1) qFatal("Fixture signing init failed");
        size_t size=64; QByteArray signature(64,0);
        if(EVP_DigestSign(ctx.get(),reinterpret_cast<unsigned char*>(signature.data()),&size,
            reinterpret_cast<const unsigned char*>(message.data()),message.size())!=1) qFatal("Fixture signing failed");
        return QJsonDocument(QJsonObject{{"payload",QString::fromLatin1(bytes.toBase64())},{"signature",QString::fromLatin1(signature.toBase64())}}).toJson(QJsonDocument::Compact);
    }
    QUrl file(const QTemporaryDir& dir,const QByteArray& bytes) {
        QFile file(dir.filePath("import.teraguchi-studio"));
        if(!file.open(QIODevice::WriteOnly) || file.write(bytes)!=bytes.size()) qFatal("Fixture write failed");
        return QUrl::fromLocalFile(file.fileName());
    }
private slots:
    void initTestCase() {
        auto* ctx=EVP_PKEY_CTX_new_id(EVP_PKEY_ED25519,nullptr); QVERIFY(ctx);
        EVP_PKEY* generated=nullptr;
        QCOMPARE(EVP_PKEY_keygen_init(ctx),1); QCOMPARE(EVP_PKEY_keygen(ctx,&generated),1);
        EVP_PKEY_CTX_free(ctx); key.reset(generated);
        publicKey.resize(32); size_t length=32;
        QCOMPARE(EVP_PKEY_get_raw_public_key(key.get(),reinterpret_cast<unsigned char*>(publicKey.data()),&length),1);
    }
    void signatureAndDomain() {
        QString error; const auto envelope=sign(payload());
        const auto verified=TeraguchiStudio::verify(envelope,publicKey,now,&error);
        QCOMPARE(verified.revision,1); QVERIFY(error.isEmpty());
        QCOMPARE(verified.suffix,QString("studio-example.ts.net"));
        QVERIFY(!TeraguchiStudio::verify(envelope,QByteArray(),now,&error).revision);
        QVERIFY(!TeraguchiStudio::verify(envelope,QByteArray(32,'x'),now,&error).revision);
        QVERIFY(!TeraguchiStudio::verify(sign(payload(),"other protocol\n"),publicKey,now,&error).revision);
        auto tampered=QJsonDocument::fromJson(envelope).object();
        auto content=payload(); content["dns_suffix"]="different.ts.net";
        tampered["payload"]=QString::fromLatin1(QJsonDocument(content).toJson(QJsonDocument::Compact).toBase64());
        QVERIFY(!TeraguchiStudio::verify(QJsonDocument(tampered).toJson(QJsonDocument::Compact),publicKey,now,&error).revision);
    }
    void invalid_data() {
        QTest::addColumn<QString>("field"); QTest::addColumn<QJsonValue>("value");
        QTest::newRow("version") << QString("version") << QJsonValue(2);
        QTest::newRow("fractional-revision") << QString("revision") << QJsonValue(1.5);
        QTest::newRow("negative-revision") << QString("revision") << QJsonValue(-1);
        QTest::newRow("revision-overflow") << QString("revision") << QJsonValue(2147483648.0);
        QTest::newRow("wildcard") << QString("dns_suffix") << QJsonValue("*.ts.net");
        QTest::newRow("normal-domain") << QString("dns_suffix") << QJsonValue("example.org");
        QTest::newRow("trailing-dot") << QString("dns_suffix") << QJsonValue("studio-example.ts.net.");
        QTest::newRow("markup") << QString("label") << QJsonValue("<b>Studio</b>");
        QTest::newRow("control") << QString("label") << QJsonValue("Studio\nOther");
        QTest::newRow("unknown-field") << QString("auth_key") << QJsonValue("not-allowed");
        QTest::newRow("bad-date") << QString("expires_at") << QJsonValue("soon");
        QTest::newRow("expired") << QString("expires_at") << QJsonValue(QDateTime::fromSecsSinceEpoch(now-1,Qt::UTC).toString("yyyy-MM-ddTHH:mm:ss'Z'"));
        QTest::newRow("future") << QString("issued_at") << QJsonValue(QDateTime::fromSecsSinceEpoch(now+30,Qt::UTC).toString("yyyy-MM-ddTHH:mm:ss'Z'"));
        QTest::newRow("too-long") << QString("expires_at") << QJsonValue(QDateTime::fromSecsSinceEpoch(now+91*86400,Qt::UTC).toString("yyyy-MM-ddTHH:mm:ss'Z'"));
    }
    void invalid() {
        QFETCH(QString,field); QFETCH(QJsonValue,value);
        auto content=payload(); content[field]=value; QString error;
        QVERIFY(!TeraguchiStudio::verify(sign(content),publicKey,now,&error).revision); QVERIFY(!error.isEmpty());
    }
    void malformedEnvelope() {
        QString error;
        for(const auto& envelope : {QByteArray(),QByteArray("{}"),QByteArray("[]"),QByteArray(8193,'x'),QByteArray("{\"payload\":\"!\",\"signature\":\"!\"}")})
            QVERIFY(!TeraguchiStudio::verify(envelope,publicKey,now,&error).revision);
        auto envelope=sign(payload()); envelope.prepend("{\"payload\":\"duplicate\",");
        QVERIFY(!TeraguchiStudio::verify(envelope,publicKey,now,&error).revision);
    }
    void importPersistAndRollback() {
        QTemporaryDir dir; QVERIFY(dir.isValid());
        StudioSetup setup(publicKey,dir.filePath("data/studio.json"),[this]{return now;});
        QVERIFY(!setup.ready()); QVERIFY(setup.importFile(file(dir,sign(payload(2))))); QVERIFY(setup.ready());
        auto retained=setup.permit();
        QVERIFY(!setup.importFile(file(dir,sign(payload(1))))); QCOMPARE(setup.permit(),retained);
        auto conflict=payload(2); conflict["label"]="Changed";
        QVERIFY(!setup.importFile(file(dir,sign(conflict)))); QCOMPARE(setup.permit(),retained);
        QVERIFY(!setup.importFile(file(dir,"corrupt"))); QCOMPARE(setup.permit(),retained);
        QVERIFY(!setup.importFile(QUrl("https://example.org/setup"))); QCOMPARE(setup.permit(),retained);
        StudioSetup reopened(publicKey,dir.filePath("data/studio.json"),[this]{return now;});
        QVERIFY(reopened.ready()); QCOMPARE(reopened.permit()->profile.revision,2);
        const auto permissions=QFile::permissions(dir.filePath("data/studio.json"));
        QVERIFY(!(permissions & (QFile::ReadGroup|QFile::WriteGroup|QFile::ReadOther|QFile::WriteOther)));
        QVERIFY(setup.importFile(file(dir,sign(payload(3))))); QVERIFY(setup.permit()!=retained);
    }
    void expiryAndLease() {
        QTemporaryDir dir; qint64 clock=now;
        const auto path=dir.filePath("data/studio.json");
        StudioSetup setup(publicKey,path,[&]{return clock;});
        QVERIFY(setup.importFile(file(dir,sign(payload(4)))));
        const auto permit=setup.permit();
        QVERIFY(permit->valid(now,permit->admittedClock));
        QVERIFY(!permit->valid(now-1,permit->admittedClock));
        QVERIFY(!permit->valid(now+3600,permit->admittedClock));
        QVERIFY(!permit->valid(now,permit->admittedClock+std::chrono::seconds(3600)));
        clock=now+3600; setup.refresh(); QVERIFY(!setup.ready()); QCOMPARE(setup.state(),QString("expired"));
        StudioSetup expired(publicKey,path,[&]{return clock;}); QVERIFY(!expired.ready());
        auto older=payload(3); older["expires_at"]=QDateTime::fromSecsSinceEpoch(now+7200,Qt::UTC).toString("yyyy-MM-ddTHH:mm:ss'Z'");
        QVERIFY(!expired.importFile(file(dir,sign(older))));
    }
    void discoveryRequiresNativeSetup() {
        TailscaleWorkstations provider;
        provider.setStudioDnsSuffix("studio-example.ts.net");
        QVERIFY(!provider.setupPermitsConnection());
        QObject fake; provider.setStudioSetup(&fake); QVERIFY(!provider.setupPermitsConnection());
        QTemporaryDir dir;
        StudioSetup setup(publicKey,dir.filePath("setup.json"),[this]{return now;});
        provider.setStudioSetup(&setup); QVERIFY(!provider.setupPermitsConnection());
        QVERIFY(setup.importFile(file(dir,sign(payload())))); QVERIFY(provider.setupPermitsConnection());
        TailscaleWorkstations worker;
        worker.setSessionStudioPermit(setup.permit()); worker.setStudioDnsSuffix(setup.suffix());
        QVERIFY(worker.setupPermitsConnection());
        provider.setStudioDnsSuffix("another.ts.net"); QVERIFY(!provider.setupPermitsConnection());
        setup.setDevelopmentSuffix("another.ts.net"); QCOMPARE(setup.state(),QString("ready"));
    }
    void signingToolInteroperabilityAndPinnedKey() {
        const auto path=qEnvironmentVariable("STUDIO_SETUP_TEST_FILE");
        QVERIFY(!path.isEmpty()); QFile envelope(path); QVERIFY(envelope.open(QIODevice::ReadOnly));
        const auto expected=QByteArray::fromHex(qgetenv("STUDIO_SETUP_TEST_PUBLIC_KEY"));
        const auto buildKey=QByteArray::fromHex(qgetenv("STUDIO_SETUP_TEST_BUILD_KEY"));
        QCOMPARE(TeraguchiStudio::pinnedPublicKey(),buildKey);
        qputenv("PLANK_STUDIO_CONFIG_PUBLIC_KEY",QByteArray(64,'0'));
        QCOMPARE(TeraguchiStudio::pinnedPublicKey(),buildKey); // Runtime environment is not a trust input.
        QString error;
        QVERIFY(TeraguchiStudio::verify(envelope.readAll(),expected,now,&error).revision);
    }
    QJsonObject trustedPayload(int revision = 1) {
        auto content = payload(revision); content["version"] = 2;
        content["workstations"] = QJsonArray{QJsonObject{
            {"node_id", "node-a"}, {"host_id", "host-a"},
            {"certificate_sha256", QJsonArray{QString(64,'a'), QString(64,'b')}}}};
        return content;
    }
    void trustedWorkstationAndRotation() {
        QString error;
        const auto profile = TeraguchiStudio::verify(sign(trustedPayload()), publicKey, now, &error);
        QVERIFY2(profile.revision, qPrintable(error));
        auto setup = std::make_shared<TeraguchiStudio::Permit>();
        setup->profile = profile; setup->admittedAt = now;
        TeraguchiStudio::HostTrust trust{setup,"node-a","host-a","192.0.2.10",28989};
        QVERIFY(trust.valid()); QVERIFY(trust.permits(QUrl("https://192.0.2.10:28989/plank/auth/start")));
        QVERIFY(trust.accepts(QByteArray::fromHex(QByteArray(64,'a'))));
        QVERIFY(trust.accepts(QByteArray::fromHex(QByteArray(64,'b'))));
        QVERIFY(!trust.accepts(QByteArray::fromHex(QByteArray(64,'c'))));
        for (const auto& url : {"http://192.0.2.10:28989/", "https://192.0.2.11:28989/",
                "https://192.0.2.10:22/", "https://user@192.0.2.10:28989/", "https://host.example.com:28989/"})
            QVERIFY(!trust.permits(QUrl(url)));
        auto wrong = trust; wrong.nodeId = "node-b"; QVERIFY(!wrong.valid());
        wrong = trust; wrong.hostId = "host-b"; QVERIFY(!wrong.valid());
        setup->development = true; QVERIFY(!trust.valid()); setup->development = false;
        setup->profile.expires = now; QVERIFY(!trust.valid());
        QTemporaryDir dir;
        StudioSetup stored(publicKey, dir.filePath("saved/setup.json"), [this]{return now;});
        QVERIFY(stored.importFile(file(dir, sign(trustedPayload(3)))));
        auto rotated = trustedPayload(4);
        auto entries = rotated["workstations"].toArray(); auto host = entries[0].toObject();
        host["certificate_sha256"] = QJsonArray{QString(64,'b')}; entries[0] = host; rotated["workstations"] = entries;
        QVERIFY(stored.importFile(file(dir, sign(rotated))));
        QVERIFY(!stored.importFile(file(dir, sign(trustedPayload(3)))));
        TeraguchiStudio::HostTrust current{stored.permit(),"node-a","host-a","192.0.2.10",28989};
        QVERIFY(!current.accepts(QByteArray::fromHex(QByteArray(64,'a'))));
        QVERIFY(current.accepts(QByteArray::fromHex(QByteArray(64,'b'))));
    }
    void bundledSetupBootstrapsAndPersists() {
        QTemporaryDir dir;
        const auto bundle = file(dir, sign(trustedPayload())).toLocalFile();
        const auto storage = dir.filePath("data/studio.json");
        StudioSetup setup(publicKey, storage, [this]{return now;}, nullptr, bundle);
        QVERIFY(setup.ready()); QCOMPARE(setup.label(), QString("Example Studio"));
        QVERIFY(setup.permit()->profile.workstations.contains("node-a"));
        QVERIFY(QFile::exists(storage));
        QVERIFY(!(QFile::permissions(storage) & (QFile::ReadGroup | QFile::ReadOther)));
        QFile::remove(bundle);
        StudioSetup reopened(publicKey, storage, [this]{return now;}, nullptr, bundle);
        QVERIFY(reopened.ready());
    }
    void bundledUpdatePreservesNewerManualSetup() {
        QTemporaryDir dir; const auto storage = dir.filePath("data/studio.json");
        const auto bundle = file(dir, sign(trustedPayload(2))).toLocalFile();
        StudioSetup first(publicKey, storage, [this]{return now;}, nullptr, bundle);
        QVERIFY(first.ready());
        file(dir, sign(trustedPayload(3)));
        StudioSetup upgraded(publicKey, storage, [this]{return now;}, nullptr, bundle);
        QCOMPARE(upgraded.permit()->profile.revision, 3);
        file(dir, sign(trustedPayload(2)));
        StudioSetup older(publicKey, storage, [this]{return now;}, nullptr, bundle);
        QCOMPARE(older.permit()->profile.revision, 3);
        auto conflict = trustedPayload(3); conflict["label"] = "Conflicting Studio";
        file(dir, sign(conflict));
        StudioSetup conflicting(publicKey, storage, [this]{return now;}, nullptr, bundle);
        QCOMPARE(conflicting.label(), QString("Example Studio"));
        QVERIFY(!conflicting.message().isEmpty());
    }
    void invalidBundlesCannotBootstrap() {
        QTemporaryDir dir;
        const auto bundle = file(dir, sign(trustedPayload())).toLocalFile();
        StudioSetup noKey({}, dir.filePath("none.json"), [this]{return now;}, nullptr, bundle);
        QVERIFY(!noKey.ready());
        StudioSetup wrongKey(QByteArray(32,'x'), dir.filePath("wrong.json"), [this]{return now;}, nullptr, bundle);
        QVERIFY(!wrongKey.ready()); QVERIFY(!QFile::exists(dir.filePath("wrong.json")));
        for (const auto& bytes : {QByteArray("corrupt"), sign(payload())}) {
            file(dir, bytes);
            StudioSetup rejected(publicKey, dir.filePath("invalid.json"), [this]{return now;}, nullptr, bundle);
            QVERIFY(!rejected.ready()); QVERIFY(!QFile::exists(dir.filePath("invalid.json")));
        }
        file(dir, sign(trustedPayload()));
        StudioSetup expired(publicKey, dir.filePath("expired.json"), [this]{return now+7200;}, nullptr, bundle);
        QVERIFY(!expired.ready()); QVERIFY(!QFile::exists(dir.filePath("expired.json")));
    }
    void bundleCannotResetExpiredOrDamagedHistory() {
        QTemporaryDir dir; const auto storage = dir.filePath("data/studio.json");
        const auto bundle = file(dir, sign(trustedPayload(5))).toLocalFile();
        StudioSetup initial(publicKey, storage, [this]{return now;}, nullptr, bundle);
        QVERIFY(initial.ready());
        auto older = trustedPayload(4);
        older["expires_at"] = QDateTime::fromSecsSinceEpoch(now+10000,Qt::UTC).toString("yyyy-MM-ddTHH:mm:ss'Z'");
        file(dir, sign(older));
        StudioSetup expired(publicKey, storage, [this]{return now+7200;}, nullptr, bundle);
        QVERIFY(!expired.ready()); QCOMPARE(expired.state(), QString("expired"));
        QFile damaged(storage); QVERIFY(damaged.open(QIODevice::WriteOnly)); damaged.write("damaged"); damaged.close();
        StudioSetup invalid(publicKey, storage, [this]{return now;}, nullptr, bundle);
        QVERIFY(!invalid.ready()); QCOMPARE(invalid.state(), QString("invalid"));
    }
    void invalidWorkstationBindings() {
        QString error;
        const auto reject = [&](QJsonObject content) {
            return !TeraguchiStudio::verify(sign(content), publicKey, now, &error).revision;
        };
        for (const auto& value : {QJsonValue(), QJsonValue(QJsonArray()), QJsonValue("host")}) {
            auto content = trustedPayload(); content["workstations"] = value; QVERIFY(reject(content));
        }
        const auto valid = trustedPayload()["workstations"].toArray()[0].toObject();
        for (const auto& change : {QJsonObject{{"node_id","node-a\n"}}, QJsonObject{{"host_id",""}},
                QJsonObject{{"address","192.0.2.10"}}, QJsonObject{{"certificate_sha256",QJsonArray{QString(64,'A')}}},
                QJsonObject{{"certificate_sha256",QJsonArray{QString(64,'a'),QString(64,'a')}}},
                QJsonObject{{"certificate_sha256",QJsonArray{QString(64,'a'),QString(64,'b'),QString(64,'c')}}}}) {
            auto host = valid;
            for(auto it = change.begin(); it != change.end(); ++it) host[it.key()] = it.value();
            auto content = trustedPayload(); content["workstations"] = QJsonArray{host}; QVERIFY(reject(content));
        }
        auto other = valid; other["node_id"]="node-b"; other["host_id"]="host-b";
        auto content=trustedPayload(); content["workstations"]=QJsonArray{valid,other}; QVERIFY(reject(content));
        content=trustedPayload(); content["workstations"]=QJsonArray{valid,valid}; QVERIFY(reject(content));
        content=trustedPayload(); content["version"]=1; QVERIFY(reject(content));
        auto setup=std::make_shared<TeraguchiStudio::Permit>(); setup->profile=TeraguchiStudio::verify(sign(payload()),publicKey,now,&error); setup->admittedAt=now;
        TeraguchiStudio::HostTrust legacy{setup,"node-a","host-a","192.0.2.10",28989}; QVERIFY(!legacy.valid());
    }
    void noKeyCannotImport() {
        QTemporaryDir dir; StudioSetup setup({},dir.filePath("setup.json"),[this]{return now;});
        QVERIFY(!setup.canImport()); QVERIFY(!setup.importFile(file(dir,sign(payload())))); QVERIFY(!setup.ready());
        setup.setDevelopmentSuffix("studio-example.ts.net"); QVERIFY(setup.ready()); QCOMPARE(setup.state(),QString("development"));
    }
};
QTEST_GUILESS_MAIN(SetupTests)
#include "studio-setup.moc"
