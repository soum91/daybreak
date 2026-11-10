THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:16.0
FINALPACKAGE = 1
INSTALL_TARGET_PROCESSES = SpringBoard Preferences
SUBPROJECTS += prefs

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Daybreak
Daybreak_FILES = Tweak.m DBPlanner.m
Daybreak_CFLAGS = -fobjc-arc -fblocks -Wall -Wextra
Daybreak_FRAMEWORKS = Foundation EventKit

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
