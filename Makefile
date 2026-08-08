ARCHS = arm64 arm64e
TARGET = iphone:latest:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BiliHomeBlocker
BiliHomeBlocker_FILES = Tweak.xm
BiliHomeBlocker_CFLAGS = -fobjc-arc
BiliHomeBlocker_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk
