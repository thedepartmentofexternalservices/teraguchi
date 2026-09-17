QT += core
CONFIG += c++17 console
CONFIG -= app_bundle
TARGET = mac-window-placement
TEMPLATE = app
INCLUDEPATH += ../../apps/client/app $$(PLANK_MAC_CLIENT_DEPS)/install/include
OBJECTIVE_SOURCES += macos-window-placement.mm ../../apps/client/app/streaming/macpresentationwindows.mm
SOURCES += ../../apps/client/app/backend/teraguchi/macdisplaybinding.cpp
LIBS += -L$$(PLANK_MAC_CLIENT_DEPS)/install/lib -lSDL3 -framework AppKit -framework CoreGraphics -framework ColorSync
QMAKE_LFLAGS += -Wl,-rpath,$$(PLANK_MAC_CLIENT_DEPS)/install/lib
QMAKE_APPLE_DEVICE_ARCHS = arm64
QMAKE_MACOSX_DEPLOYMENT_TARGET = 26.0

QMAKE_CXXFLAGS += -include arm_acle.h
