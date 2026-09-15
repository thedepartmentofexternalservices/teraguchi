QT += core testlib
CONFIG += c++17 console testcase
CONFIG -= app_bundle
TARGET = mac-display-binding-tests
TEMPLATE = app
INCLUDEPATH += ../../apps/client/app $$(PLANK_MAC_CLIENT_DEPS)/install/include
SOURCES += macos-display-binding.cpp ../../apps/client/app/backend/teraguchi/macdisplaybinding.cpp
macx: LIBS += -framework CoreGraphics -framework ColorSync
QMAKE_APPLE_DEVICE_ARCHS = arm64
QMAKE_MACOSX_DEPLOYMENT_TARGET = 26.0

QMAKE_CXXFLAGS += -include arm_acle.h
