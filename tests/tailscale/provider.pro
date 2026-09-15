QT += core network testlib
CONFIG += c++17 console testcase
CONFIG -= app_bundle
TEMPLATE = app
TARGET = tailscale-provider-tests
INCLUDEPATH += ../../apps/client/app/backend/teraguchi
HEADERS += ../../apps/client/app/backend/teraguchi/tailscaleworkstations.h
SOURCES += provider.cpp ../../apps/client/app/backend/teraguchi/tailscaleworkstations.cpp
macx {
    QMAKE_APPLE_DEVICE_ARCHS = arm64
    QMAKE_MACOSX_DEPLOYMENT_TARGET = 26.0
    QMAKE_CXXFLAGS += -include arm_acle.h
}

HEADERS += ../../apps/client/app/backend/teraguchi/assignmentwatch.h
SOURCES += ../../apps/client/app/backend/teraguchi/assignmentwatch.cpp
