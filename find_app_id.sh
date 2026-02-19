#!/bin/bash

# Find APP_ID for Enclosure app in iOS Simulator

echo "🔍 Finding APP_ID for Enclosure app..."
echo ""

# Find all simulators
SIMULATORS=$(xcrun simctl list devices | grep "Booted" | head -1)

if [ -z "$SIMULATORS" ]; then
    echo "❌ No booted simulator found. Please start a simulator first."
    exit 1
fi

echo "📱 Found booted simulator"
echo ""

# Find the app container
APP_PATH=$(find ~/Library/Developer/CoreSimulator/Devices -name "Enclosure.app" -type d 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Enclosure app not found. Make sure the app is installed in simulator."
    exit 1
fi

# Extract device ID and app ID from path
# Path format: ~/Library/Developer/CoreSimulator/Devices/[DEVICE_ID]/data/Containers/Bundle/Application/[APP_ID]/Enclosure.app

DEVICE_ID=$(echo "$APP_PATH" | sed -n 's|.*/Devices/\([^/]*\)/.*|\1|p')
APP_ID=$(echo "$APP_PATH" | sed -n 's|.*/Application/\([^/]*\)/.*|\1|p')

echo "✅ Found Enclosure App"
echo ""
echo "📱 DEVICE_ID: $DEVICE_ID"
echo "📱 APP_ID: $APP_ID"
echo ""
echo "📁 Images Directory Path:"
echo "~/Library/Developer/CoreSimulator/Devices/$DEVICE_ID/data/Containers/Data/Application/$APP_ID/Documents/Enclosure/Media/Images"
echo ""
echo "💡 Copy the path above and paste in Finder (Cmd+Shift+G)"

