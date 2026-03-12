PROJECT = portlessbar
SCHEME = portlessbar
APP_NAME = portlessbar
ARCHIVE_PATH = build/$(APP_NAME).xcarchive
EXPORT_PATH = build/export
PKG_PATH = build/$(APP_NAME).pkg
TEAM_ID ?= $(TEAM_ID)
INSTALLER_IDENTITY ?= $(INSTALLER_IDENTITY)

PBXPROJ = $(PROJECT).xcodeproj/project.pbxproj
CURRENT_VERSION = $(shell grep 'MARKETING_VERSION' $(PBXPROJ) | grep -o '[0-9]*\.[0-9]*\.[0-9]*' | head -1)
CURRENT_BUILD = $(shell grep 'CURRENT_PROJECT_VERSION' $(PBXPROJ) | grep -o '[0-9]*' | head -1)

.PHONY: all archive export pkg notarize clean release-patch release-minor release-major

all: pkg

archive:
	xcodebuild archive \
		-project $(PROJECT).xcodeproj \
		-scheme $(SCHEME) \
		-archivePath $(ARCHIVE_PATH) \
		-configuration Release \
		SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(SWIFT_ACTIVE_COMPILATION_CONDITIONS) PRODUCTION'

export: archive
	@sed 's/$$(TEAM_ID)/$(TEAM_ID)/' ExportOptions.plist > build/ExportOptions.plist
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportPath $(EXPORT_PATH) \
		-exportOptionsPlist build/ExportOptions.plist

pkg: export
	productbuild \
		--component "$(EXPORT_PATH)/$(APP_NAME).app" /Applications \
		--sign "$(INSTALLER_IDENTITY)" \
		$(PKG_PATH)
	@echo "\nBuilt: $(PKG_PATH)"

notarize:
	xcrun notarytool submit $(PKG_PATH) --keychain-profile "notarytool-profile" --wait
	xcrun stapler staple $(PKG_PATH)
	@echo "\nNotarized: $(PKG_PATH)"

clean:
	rm -rf build

release-patch release-minor release-major:
	$(eval OLD := $(CURRENT_VERSION))
	$(eval PARTS := $(subst ., ,$(OLD)))
	$(eval MAJOR := $(word 1,$(PARTS)))
	$(eval MINOR := $(word 2,$(PARTS)))
	$(eval PATCH := $(word 3,$(PARTS)))
	$(eval NEW := $(if $(filter release-patch,$@),$(MAJOR).$(MINOR).$(shell echo $$(($(PATCH)+1))),$(if $(filter release-minor,$@),$(MAJOR).$(shell echo $$(($(MINOR)+1))).0,$(shell echo $$(($(MAJOR)+1))).0.0)))
	@echo "Bumping version: $(OLD) → $(NEW)"
	$(eval NEW_BUILD := $(shell echo $$(($(CURRENT_BUILD)+1))))
	@sed -i '' 's/MARKETING_VERSION = $(OLD)/MARKETING_VERSION = $(NEW)/g' $(PBXPROJ)
	@sed -i '' 's/CURRENT_PROJECT_VERSION = $(CURRENT_BUILD)/CURRENT_PROJECT_VERSION = $(NEW_BUILD)/g' $(PBXPROJ)
	@git add $(PBXPROJ)
	@git commit -m "release v$(NEW)"
	@git tag v$(NEW)
	@git push
	@git push origin v$(NEW)
	@$(MAKE) pkg
	@$(MAKE) notarize
	@gh release create v$(NEW) $(PKG_PATH) --title "v$(NEW)" --generate-notes
