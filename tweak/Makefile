THEOS_PACKAGE_SCHEME = rootless
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:16.0
FINALPACKAGE = 1
INSTALL_TARGET_PROCESSES = SpringBoard Preferences Health
SUBPROJECTS += prefs app

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Daybreak DaybreakHealthProbe DaybreakSleepDaemonProbe
Daybreak_FILES = Tweak.m DBPlanner.m DBNativeSleep.m
Daybreak_CFLAGS = -fobjc-arc -fblocks -Wall -Wextra
Daybreak_FRAMEWORKS = Foundation EventKit HealthKit UserNotifications

# A separate dylib keeps the native Health and Sleep framework calls entirely
# inside Apple's Health process, never SpringBoard or the unsigned companion.
DaybreakHealthProbe_FILES = DBHealthProbe.m DBNativeSleep.m
DaybreakHealthProbe_CFLAGS = -fobjc-arc -fblocks -Wall -Wextra
DaybreakHealthProbe_FRAMEWORKS = Foundation HealthKit UIKit

# Read-only sleepd inspection: observes Apple's real running environment.
# The third dylib never changes Sleep schedules or forces cloud sync.
DaybreakSleepDaemonProbe_FILES = DBSleepDaemonProbe.xm
DaybreakSleepDaemonProbe_CFLAGS = -fobjc-arc -fblocks -Wall -Wextra
DaybreakSleepDaemonProbe_FRAMEWORKS = Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
