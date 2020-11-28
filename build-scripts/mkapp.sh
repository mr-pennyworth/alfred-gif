#!/usr/bin/env bash


if [ -e "/Applications/Xcode_11.7.app" ]; then
    sudo xcode-select -switch /Applications/Xcode_11.7.app
fi

xcodebuild \
  -project './alfred-gif-browser/AlfredGifBrowser.xcodeproj' \
  -configuration Release \
  -scheme 'AlfredGifBrowser' \
  -derivedDataPath DerivedData \
  build

cp -r 'DerivedData/Build/Products/Release/AlfredGifBrowser.app' ./
