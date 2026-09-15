QT += core network gui qml
CONFIG += c++17 console
CONFIG -= app_bundle
TEMPLATE = app
TARGET = host-trust-probe
SOURCES += host-trust-probe.cpp ../../apps/client/app/backend/nvhttp.cpp \
    ../../apps/client/app/backend/nvaddress.cpp ../../apps/client/app/backend/outputtopology.cpp
HEADERS += ../../apps/client/app/backend/nvhttp.h
INCLUDEPATH += ../../apps/client/app ../../apps/client/moonlight-common-c/moonlight-common-c/src
macx {
    QMAKE_APPLE_DEVICE_ARCHS = arm64
    QMAKE_MACOSX_DEPLOYMENT_TARGET = 26.0
    QMAKE_CXXFLAGS += -include arm_acle.h
}
