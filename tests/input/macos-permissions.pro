QT += core gui testlib
CONFIG += c++17 console testcase
CONFIG -= app_bundle
TEMPLATE = app
TARGET = mac-input-permissions-tests
INCLUDEPATH += ../../apps/client/app
HEADERS += ../../apps/client/app/backend/teraguchi/macinputpermissions.h \
           ../../apps/client/app/backend/teraguchi/macinputaccess.h
SOURCES += macos-permissions.cpp ../../apps/client/app/backend/teraguchi/macinputpermissions.cpp
macx {
    LIBS += -framework ApplicationServices
    QMAKE_APPLE_DEVICE_ARCHS = arm64
    QMAKE_MACOSX_DEPLOYMENT_TARGET = 26.0
    QMAKE_CXXFLAGS += -include arm_acle.h
}
