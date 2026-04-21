APP_NAME ?= geMMaFloW
BUNDLE_ID ?= com.verdana86.gemmaflow
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
CODESIGN_IDENTITY ?= geMMaFloW Dev Signer
CONTENTS = $(APP_BUNDLE)/Contents
MACOS_DIR = $(CONTENTS)/MacOS
empty :=
space := $(empty) $(empty)
APP_EXECUTABLE = $(MACOS_DIR)/$(APP_NAME)
APP_EXECUTABLE_TARGET := $(subst $(space),\ ,$(APP_EXECUTABLE))

SWIFT_CONFIG ?= release
SWIFT_EXECUTABLE_NAME = GemmaFlowCore

SOURCES := $(wildcard Sources/*.swift) Package.swift
RESOURCES = $(CONTENTS)/Resources
ICON_SOURCE = Resources/AppIcon-Source.png
ICON_ICNS = Resources/AppIcon.icns

# MLX requires a precompiled Metal shader library (default.metallib).
# SwiftPM does not compile .metal files, so we delegate to Xcode's build
# of Cmlx.framework and extract default.metallib from its Resources.
MLX_XCODEPROJ = .build/checkouts/mlx-swift/xcode/MLX.xcodeproj
MLX_DERIVED_DATA = .build/mlx-xcode
MLX_METALLIB = $(MLX_DERIVED_DATA)/Build/Products/Release/Cmlx.framework/Versions/A/Resources/default.metallib

.PHONY: all clean clean-user-state run icon dmg codesign-dmg notarize test metallib

all: $(APP_EXECUTABLE_TARGET)

test:
	swift test

# Build default.metallib via xcodebuild Cmlx scheme. Requires the Metal
# Toolchain Xcode component (`xcodebuild -downloadComponent MetalToolchain`
# installs it once). Skipped if metallib already exists.
$(MLX_METALLIB):
	@if [ ! -f "$(MLX_XCODEPROJ)/project.pbxproj" ]; then \
		echo "MLX checkout missing — running swift package resolve first"; \
		swift package resolve; \
	fi
	@echo "Building MLX default.metallib via xcodebuild..."
	@xcodebuild build -project "$(MLX_XCODEPROJ)" -scheme Cmlx \
		-configuration Release -derivedDataPath "$(MLX_DERIVED_DATA)" \
		ARCHS=arm64 ONLY_ACTIVE_ARCH=YES 2>&1 | tail -3

metallib: $(MLX_METALLIB)

$(APP_EXECUTABLE_TARGET): $(SOURCES) Info.plist $(ICON_ICNS) $(MLX_METALLIB)
	@mkdir -p "$(MACOS_DIR)" "$(RESOURCES)"
	swift build -c $(SWIFT_CONFIG) --product $(SWIFT_EXECUTABLE_NAME)
	@cp "$$(swift build -c $(SWIFT_CONFIG) --show-bin-path)/$(SWIFT_EXECUTABLE_NAME)" "$(MACOS_DIR)/$(APP_NAME)"
	@cp Info.plist "$(CONTENTS)/"
	@plutil -replace CFBundleName -string "$(APP_NAME)" "$(CONTENTS)/Info.plist"
	@plutil -replace CFBundleDisplayName -string "$(APP_NAME)" "$(CONTENTS)/Info.plist"
	@plutil -replace CFBundleExecutable -string "$(APP_NAME)" "$(CONTENTS)/Info.plist"
	@plutil -replace CFBundleIdentifier -string "$(BUNDLE_ID)" "$(CONTENTS)/Info.plist"
	@cp $(ICON_ICNS) "$(RESOURCES)/"
	@cp "$(MLX_METALLIB)" "$(MACOS_DIR)/mlx.metallib"
	@cp "$(MLX_METALLIB)" "$(RESOURCES)/default.metallib"
	@bash -c 'set -e; APP="$(APP_BUNDLE)"; find "$$APP" -name "._*" -delete 2>/dev/null || true; find "$$APP" -exec xattr -c {} + 2>/dev/null || true; xattr -c "$$APP" 2>/dev/null || true; sync; sleep 0.3; xattr -c "$$APP" 2>/dev/null || true; codesign --force --options runtime --deep --sign "$(CODESIGN_IDENTITY)" --entitlements GemmaFlow.entitlements "$$APP"'
	@echo "Built $(APP_BUNDLE)"

icon: $(ICON_ICNS)

$(ICON_ICNS): $(ICON_SOURCE)
	@mkdir -p $(BUILD_DIR)/AppIcon.iconset
	@sips -z 16 16 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_16x16.png > /dev/null
	@sips -z 32 32 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_16x16@2x.png > /dev/null
	@sips -z 32 32 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_32x32.png > /dev/null
	@sips -z 64 64 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_32x32@2x.png > /dev/null
	@sips -z 128 128 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_128x128.png > /dev/null
	@sips -z 256 256 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_128x128@2x.png > /dev/null
	@sips -z 256 256 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_256x256.png > /dev/null
	@sips -z 512 512 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_256x256@2x.png > /dev/null
	@sips -z 512 512 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_512x512.png > /dev/null
	@sips -z 1024 1024 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_512x512@2x.png > /dev/null
	@iconutil -c icns -o $@ $(BUILD_DIR)/AppIcon.iconset
	@rm -rf $(BUILD_DIR)/AppIcon.iconset
	@echo "Generated $@"

dmg: all
	@rm -f "$(BUILD_DIR)/$(APP_NAME).dmg"
	@rm -rf $(BUILD_DIR)/dmg-staging
	@mkdir -p $(BUILD_DIR)/dmg-staging
	@cp -R "$(APP_BUNDLE)" $(BUILD_DIR)/dmg-staging/
	@osascript -e 'tell application "Finder" to make alias file to POSIX file "/Applications" at POSIX file "'"$$(cd $(BUILD_DIR)/dmg-staging && pwd)"'"'
	@ALIAS=$$(find $(BUILD_DIR)/dmg-staging -maxdepth 1 -not -name '*.app' -not -name '.DS_Store' -type f | head -1) && mv "$$ALIAS" "$(BUILD_DIR)/dmg-staging/Applications"
	@fileicon set "$(BUILD_DIR)/dmg-staging/Applications" /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ApplicationsFolderIcon.icns
	@echo "Creating DMG..."
	@create-dmg \
		--volname "$(APP_NAME)" \
		--volicon "$(ICON_ICNS)" \
		--window-pos 200 120 \
		--window-size 660 400 \
		--icon-size 128 \
		--icon "$(APP_NAME).app" 180 170 \
		--hide-extension "$(APP_NAME).app" \
		--icon "Applications" 480 170 \
		--no-internet-enable \
		"$(BUILD_DIR)/$(APP_NAME).dmg" \
		"$(BUILD_DIR)/dmg-staging"
	@rm -rf $(BUILD_DIR)/dmg-staging
	@echo "Created $(BUILD_DIR)/$(APP_NAME).dmg"

codesign-dmg: dmg
	codesign --force --sign "$(CODESIGN_IDENTITY)" "$(BUILD_DIR)/$(APP_NAME).dmg"

notarize:
	xcrun notarytool submit "$(BUILD_DIR)/$(APP_NAME).dmg" \
		--keychain-profile "$(NOTARIZE_PROFILE)" --wait
	xcrun stapler staple "$(BUILD_DIR)/$(APP_NAME).dmg"

clean:
	rm -rf $(BUILD_DIR) .build

# Wipes everything the installed app persists outside the repo: the /Applications
# bundle, user caches, downloaded WhisperKit + Gemma models, and the TCC grants
# (Microphone / Accessibility / Screen Recording). Prompts before deleting so an
# accidental invocation doesn't eat the model downloads (~2 GB).
clean-user-state:
	@echo "This will delete for bundle id '$(BUNDLE_ID)':"
	@echo "  /Applications/$(APP_NAME).app"
	@echo "  ~/Library/Caches/$(BUNDLE_ID)"
	@echo "  ~/Library/Application Support/$(APP_NAME)"
	@echo "  ~/Documents/huggingface/models/argmaxinc/whisperkit-coreml"
	@echo "  ~/Documents/huggingface/models/mlx-community/gemma-*"
	@echo "  ~/.cache/huggingface/hub/models--argmaxinc--whisperkit-coreml (legacy)"
	@echo "  ~/.cache/huggingface/hub/models--mlx-community--gemma-* (legacy)"
	@echo "  TCC grants: Microphone, Accessibility, ScreenCapture"
	@read -p "Continue? [y/N] " ans && [ "$$ans" = "y" ] || [ "$$ans" = "Y" ]
	-rm -rf "/Applications/$(APP_NAME).app"
	-rm -rf "$$HOME/Library/Caches/$(BUNDLE_ID)"
	-rm -rf "$$HOME/Library/Application Support/$(APP_NAME)"
	-rm -rf "$$HOME/Documents/huggingface/models/argmaxinc/whisperkit-coreml"
	-find "$$HOME/Documents/huggingface/models/mlx-community" -maxdepth 1 -type d -name 'gemma*' -exec rm -rf {} + 2>/dev/null || true
	-rm -rf "$$HOME/.cache/huggingface/hub/models--argmaxinc--whisperkit-coreml"
	-find "$$HOME/.cache/huggingface/hub" -maxdepth 1 -type d -name 'models--mlx-community--gemma*' -exec rm -rf {} + 2>/dev/null || true
	-tccutil reset Microphone $(BUNDLE_ID) 2>/dev/null || true
	-tccutil reset Accessibility $(BUNDLE_ID) 2>/dev/null || true
	-tccutil reset ScreenCapture $(BUNDLE_ID) 2>/dev/null || true
	@echo "Clean slate. Reinstall with: make && cp -R \"$(APP_BUNDLE)\" /Applications/"

run: all
	open "$(APP_BUNDLE)"
