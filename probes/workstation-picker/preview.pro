QT += quick qml quickcontrols2 network
CONFIG += c++17 console
CONFIG -= app_bundle
TEMPLATE = app
TARGET = teraguchi-ui-preview
SOURCES += main.cpp
SOURCES += ../../apps/client/app/backend/teraguchi/supportdiagnostics.cpp
HEADERS += ../../apps/client/app/backend/teraguchi/supportdiagnostics.h
RESOURCES += preview.qrc
macx {
    QMAKE_APPLE_DEVICE_ARCHS = arm64
    QMAKE_MACOSX_DEPLOYMENT_TARGET = 26.0
    QMAKE_CXXFLAGS += -include arm_acle.h
}
