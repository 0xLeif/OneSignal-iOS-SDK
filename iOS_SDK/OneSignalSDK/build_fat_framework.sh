set -e

WORKING_DIR=$(pwd)

# TODO: For backwards compatible bitcode we need to build iphonesimulator + iphoneos with 3 versions behind the latest.
#       However variant=Mac Catalyst needs to be be Xcode 11.0
# /Users/YOUR_USER/Library/Developer/Xcode/DerivedData/OneSignal-cqsmyasivbcrdncesubsrmqmewqw/Build/Products/Debug-iphonesimulator/libOneSignal.a
xcodebuild -sdk "iphonesimulator" ARCHS="x86_64"  -project "OneSignal.xcodeproj" -scheme "OneSignal"

# /Users/YOUR_USER/Library/Developer/Xcode/DerivedData/OneSignal-cqsmyasivbcrdncesubsrmqmewqw/Build/Products/Debug-iphoneos/libOneSignal.a
xcodebuild -sdk "iphoneos" ARCHS="armv7 armv7s arm64" -project "OneSignal.xcodeproj" -scheme "OneSignal"

# /Users/YOUR_USER/Library/Developer/Xcode/DerivedData/OneSignal-cqsmyasivbcrdncesubsrmqmewqw/Build/Products/Debug-maccatalyst/libOneSignal.a
xcodebuild ARCHS="x86_64h" -destination 'platform=macOS,variant=Mac Catalyst' -project "OneSignal.xcodeproj" -scheme "OneSignal"

USER=$(id -un)
# TODO: This can return more than one folder, need to find if there is a better way to do this
DERIVED_DATA_ONESIGNAL_DIR=$(find /Users/${USER}/Library/Developer/Xcode/DerivedData -name "OneSignal-*" -type d ! -path "*/Build/*")

echo $DERIVED_DATA_ONESIGNAL_DIR

# Use Debug configuration to expose symbols
# TODO: Maybe detect 
CATALYST_DIR="${DERIVED_DATA_ONESIGNAL_DIR}/Build/Products/Debug-maccatalyst"
SIMULATOR_DIR="${DERIVED_DATA_ONESIGNAL_DIR}/Build/Products/Debug-iphonesimulator"
IPHONE_DIR="${DERIVED_DATA_ONESIGNAL_DIR}/Build/Products/Debug-iphoneos"

CATALYST_OUTPUT_DIR=${CATALYST_DIR}/OneSignal.framework
SIMULATOR_OUTPUT_DIR=${SIMULATOR_DIR}/OneSignal.framework
IPHONE_OUTPUT_DIR=${IPHONE_DIR}/OneSignal.framework

UNIVERSAL_DIR=${DERIVED_DATA_ONESIGNAL_DIR}/Build/Products/Debug-universal
FINAL_FRAMEWORK=${UNIVERSAL_DIR}/OneSignal.framework
EXECUTABLE_DESTINATION=${FINAL_FRAMEWORK}/OneSignal

rm -rf "${UNIVERSAL_DIR}"
mkdir "${UNIVERSAL_DIR}"

# TODO: Frmamework sturctor does not seem to be created when running from command line.
#       Need to find a way to build this up or what command needs to be run to do this for us
# cp -a "${IPHONE_DIR}/OneSignal.framework" "${FINAL_FRAMEWORK}"
mkdir "${FINAL_FRAMEWORK}"

#"${IPHONE_DIR}/libOneSignal.a" 

echo "Making Final OneSignal with all Architecture. iOS, iOS Simulator(x86_64), Mac Catalyst(x86_64h)"
echo "File location $EXECUTABLE_DESTINATION"
lipo -create -output "$EXECUTABLE_DESTINATION" "${IPHONE_DIR}/libOneSignal.a"  "${SIMULATOR_DIR}/libOneSignal.a" "${CATALYST_DIR}/libOneSignal.a"

cd $FINAL_FRAMEWORK

declare -a files=("Headers" "Modules" "OneSignal")

mkdir Versions
mkdir Versions/A
mkdir Versions/A/Resources

# Move the framework files/folders
for name in "${files[@]}"; do
   mv ${name} Versions/A/${name}
done

# Create symlinks at the root of the framework
for name in "${files[@]}"; do
   ln -s Versions/A/${name} ${name}
done

# move info.plist into Resources and create appropriate symlinks
mv Info.plist Versions/A/Resources/Info.plist
ln -s Versions/A/Resources Resources

# Create a symlink directory for 'Versions/A' called 'Current'
cd Versions
ln -s A Current

# Copy the built product to the final destination in {repo}/iOS_SDK/OneSignalSDK/Framework
rm -rf "${WORKING_DIR}/Framework/OneSignal.framework"
cp -a "${FINAL_FRAMEWORK}" "${WORKING_DIR}/Framework/OneSignal.framework"