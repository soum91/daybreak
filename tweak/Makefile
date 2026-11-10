THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:16.0
FINALPACKAGE = 1
INSTALL_TARGET_PROCESSES = SpringBoard Preferences Health
SUBPROJECTS += prefs app

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Daybreak DaybreakHealthProbe
Daybreak_FILES = Tweak.m DBPlanner.m
Daybreak_CFLAGS = -fobjc-arc -fblocks -Wall -Wextra
Daybreak_FRAMEWORKS = Foundation EventKit

# A separate dylib keeps HealthKit out of SpringBoard. This probe is READ ONLY.
DaybreakHealthProbe_FILES = DBHealthProbe.m
DaybreakHealthProbe_CFLAGS = -fobjc-arc -fblocks -Wall -Wextra
DaybreakHealthProbe_FRAMEWORKS = Foundation HealthKit

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
