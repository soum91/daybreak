include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = DaybreakPrefs
DaybreakPrefs_FILES = DBRootListController.m
DaybreakPrefs_INSTALL_PATH = /Library/PreferenceBundles
DaybreakPrefs_FRAMEWORKS = Foundation UIKit EventKit
# Preferences.framework is loaded by the Settings host, but its linker stub is
# absent from Apple's stock SDK. Resolve PSListController from that host at load.
DaybreakPrefs_LDFLAGS = -Wl,-undefined,dynamic_lookup
DaybreakPrefs_CFLAGS = -fobjc-arc -fblocks -Wall -Wextra
DaybreakPrefs_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/bundle.mk
