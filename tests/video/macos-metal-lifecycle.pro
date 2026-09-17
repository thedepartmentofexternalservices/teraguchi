QT += core gui network qml quick
CONFIG += c++17 console
CONFIG -= app_bundle
TARGET = mac-metal-lifecycle
TEMPLATE = app
INCLUDEPATH += ../../apps/client/app ../../apps/client/moonlight-common-c/moonlight-common-c/src \
               ../../apps/client/qmdnsengine/qmdnsengine/src/include ../../apps/client/qmdnsengine \
               $$(PLANK_MAC_CLIENT_DEPS)/install/include $$(PLANK_MAC_CLIENT_DEPS)/install/include/opus
OBJECTIVE_SOURCES += macos-metal-lifecycle.mm \
    ../../apps/client/app/streaming/video/ffmpeg-renderers/vt_metal.mm \
    ../../apps/client/app/streaming/video/ffmpeg-renderers/vt_base.mm
SOURCES += ../../apps/client/app/streaming/plankpresentation.cpp
LIBS += -L$$(PLANK_MAC_CLIENT_DEPS)/install/lib -lSDL3 -lavcodec -lavutil \
    -framework Metal -framework MetalKit -framework VideoToolbox -framework AVFoundation \
    -framework CoreVideo -framework QuartzCore -framework AppKit
QMAKE_LFLAGS += -Wl,-rpath,$$(PLANK_MAC_CLIENT_DEPS)/install/lib
QMAKE_APPLE_DEVICE_ARCHS = arm64
QMAKE_MACOSX_DEPLOYMENT_TARGET = 26.0
QMAKE_CXXFLAGS += -include arm_acle.h
