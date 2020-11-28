#!/usr/bin/env bash

npm install pkg -g

cd gif-downloader
npm install
cd ..

pkg --targets node12-macos-x64 ./gif-downloader --output gif-downloader.bin
