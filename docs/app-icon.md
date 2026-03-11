# App Icon

The app icon is defined in `Resources/AppIcon.icon/` (Apple's Icon Composer format).

## Editing

Open `Resources/AppIcon.icon` in Icon Composer (bundled with Xcode 26+).

## Compiling

After editing, recompile the `.icns` and `.car` assets:

```bash
mkdir -p /tmp/icon-output && xcrun actool \
  Resources/AppIcon.icon --app-icon AppIcon \
  --compile /tmp/icon-output \
  --output-format human-readable-text \
  --notices --warnings --errors \
  --output-partial-info-plist /dev/null \
  --include-all-app-icons \
  --enable-on-demand-resources NO \
  --development-region en \
  --target-device mac \
  --minimum-deployment-target 26.0 \
  --platform macosx

cp /tmp/icon-output/AppIcon.icns Resources/AppIcon.icns
cp /tmp/icon-output/Assets.car Resources/Assets.car
```

The compiled files must be committed because `actool` crashes on CI runners with macOS 26 deployment target.
