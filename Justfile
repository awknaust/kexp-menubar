xcodebuild := "/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild"
project    := "kexp-menubar/kexp-menubar.xcodeproj"
scheme     := "kexp-menubar"
app_name   := "KEXP Menubar"
bundle_id  := "isaac.kexp-menubar"
build_dir  := "build"
repo       := "isaacd9/kexp-menubar"
min_os     := "14.0"

# App Intents (Shortcuts support) requires a signature with a real team ID, so
# the feature is compiled in only when an Apple Development identity exists;
# otherwise builds fall back to ad-hoc signing with the feature omitted.
sign_identity     := `security find-identity -v -p codesigning 2>/dev/null | grep -q "Apple Development" && echo "Apple Development" || echo "-"`
intent_conditions := if sign_identity == "-" { "" } else { "APP_INTENTS_ENABLED" }

build:
    {{xcodebuild}} \
        -project {{project}} \
        -scheme {{scheme}} \
        -configuration Debug \
        -derivedDataPath {{build_dir}}/derived \
        ENABLE_DEBUG_DYLIB=NO \
        SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG {{intent_conditions}}" \
        CONFIGURATION_BUILD_DIR={{justfile_directory()}}/{{build_dir}}/output/debug \
        MACOSX_DEPLOYMENT_TARGET={{min_os}} \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO
    if [ -z "{{intent_conditions}}" ]; then rm -rf "{{build_dir}}/output/debug/{{app_name}}.app/Contents/Resources/Metadata.appintents"; fi
    codesign --sign "{{sign_identity}}" --force --deep "{{build_dir}}/output/debug/{{app_name}}.app"

build-release:
    {{xcodebuild}} \
        -project {{project}} \
        -scheme {{scheme}} \
        -configuration Release \
        -derivedDataPath {{build_dir}}/derived \
        SWIFT_ACTIVE_COMPILATION_CONDITIONS="{{intent_conditions}}" \
        CONFIGURATION_BUILD_DIR={{justfile_directory()}}/{{build_dir}}/output/release \
        MACOSX_DEPLOYMENT_TARGET={{min_os}} \
        MARKETING_VERSION="$(tr -d '\n' < "{{justfile_directory()}}/VERSION")" \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO
    if [ -z "{{intent_conditions}}" ]; then rm -rf "{{build_dir}}/output/release/{{app_name}}.app/Contents/Resources/Metadata.appintents"; fi

run: build
    -osascript -e 'tell application id "{{bundle_id}}" to quit'
    -pkill -x "{{app_name}}"
    sleep 0.2
    open -n "{{justfile_directory()}}/{{build_dir}}/output/debug/{{app_name}}.app"

release: build-release
    codesign --sign "{{sign_identity}}" --force --deep "{{build_dir}}/output/release/{{app_name}}.app"
    ditto -c -k --keepParent "{{build_dir}}/output/release/{{app_name}}.app" "{{build_dir}}/{{app_name}}-$(tr -d '\n' < "{{justfile_directory()}}/VERSION").zip"
    gh release create "v$(tr -d '\n' < "{{justfile_directory()}}/VERSION")" \
        "{{build_dir}}/{{app_name}}-$(tr -d '\n' < "{{justfile_directory()}}/VERSION").zip" \
        --repo {{repo}} \
        --title "v$(tr -d '\n' < "{{justfile_directory()}}/VERSION")"

clean:
    rm -rf {{build_dir}}
