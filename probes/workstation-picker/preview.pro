QT += quick qml quickcontrols2 network
CONFIG += c++17 console
CONFIG -= app_bundle
TEMPLATE = app
TARGET = teraguchi-ui-preview
SOURCES += main.cpp
RESOURCES += preview.qrc
macx {
    QMAKE_APPLE_DEVICE_ARCHS = arm64
    QMAKE_MACOSX_DEPLOYMENT_TARGET = 26.0
}
