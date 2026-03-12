#!/bin/bash

set -e

APP_NAME="lachispa"
BUILD_DIR="build/linux/x64/release/bundle"
APPDIR="AppDir"

echo "🔨 Compilando Flutter en release..."
flutter build linux --release

echo "📁 Preparando AppDir..."
rm -rf $APPDIR
mkdir -p $APPDIR/usr/bin
mkdir -p $APPDIR/usr/lib
mkdir -p $APPDIR/usr/share/icons/hicolor/256x256/apps
mkdir -p $APPDIR/usr/share/applications

cp -r $BUILD_DIR/* $APPDIR/usr/bin/
cp appimage/lachispa.png $APPDIR/usr/share/icons/hicolor/256x256/apps/lachispa.png
cp appimage/lachispa.png $APPDIR/lachispa.png

sed "s/APPNAME/$APP_NAME/g" appimage/LaChispa.desktop > $APPDIR/$APP_NAME.desktop
chmod +x $APPDIR/$APP_NAME.desktop

sed "s/APPNAME/$APP_NAME/g" appimage/AppRun > $APPDIR/AppRun
chmod +x $APPDIR/AppRun

echo "⚙️ Construyendo AppImage..."
appimagetool $APPDIR "${APP_NAME}.AppImage"

echo "✔ Listo → ${APP_NAME}.AppImage"
