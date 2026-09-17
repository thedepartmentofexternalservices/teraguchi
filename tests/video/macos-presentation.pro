QT += core testlib
QT -= gui
CONFIG += c++17 console testcase
CONFIG -= app_bundle
TARGET = mac-presentation-tests
TEMPLATE = app
INCLUDEPATH += ../../apps/client/app $$(PLANK_MAC_CLIENT_DEPS)/install/include
SOURCES += macos-presentation.cpp ../../apps/client/app/streaming/plankpresentation.cpp
HEADERS += ../../apps/client/app/streaming/video/ffmpeg-renderers/vt_presentation.h
macx {
    QMAKE_APPLE_DEVICE_ARCHS = arm64
    QMAKE_MACOSX_DEPLOYMENT_TARGET = 26.0
    QMAKE_CXXFLAGS += -include arm_acle.h
}
