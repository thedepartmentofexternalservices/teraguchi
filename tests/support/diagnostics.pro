QT += core gui qml testlib
CONFIG += c++17 console testcase
CONFIG -= app_bundle
TEMPLATE = app
TARGET = support-diagnostics-tests
INCLUDEPATH += ../../apps/client/app/backend/teraguchi
HEADERS += ../../apps/client/app/backend/teraguchi/supportdiagnostics.h
SOURCES += diagnostics.cpp ../../apps/client/app/backend/teraguchi/supportdiagnostics.cpp
macx {
    QMAKE_APPLE_DEVICE_ARCHS = arm64
    QMAKE_MACOSX_DEPLOYMENT_TARGET = 26.0
    QMAKE_CXXFLAGS += -include arm_acle.h
}
