# Build Tools

## Windows Baseline

نسخة Windows هي النسخة الأساسية، وأي تطوير جديد يجب ألا يضر بها. بعد التعديلات الكبيرة شغّل:

```powershell
flutter analyze
flutter test
.\tools\build_editions.ps1 -Edition Windows
```

## Windows Edition

```powershell
.\tools\build_editions.ps1 -Edition Windows
```

## Mac Edition

يجب تشغيله من macOS:

```powershell
.\tools\build_editions.ps1 -Edition Mac
```

## Apple Business Suite

يبني Windows، وعلى macOS يكمل macOS و iPadOS:

```powershell
.\tools\build_editions.ps1 -Edition AppleBusinessSuite
```

## Tablet Edition APK

من Windows:

```powershell
.\tools\build_android_apk.ps1
```

أو من سكربت الإصدارات العام:

```powershell
.\tools\build_editions.ps1 -Edition Tablet
```

الناتج:

```text
Builds\Tablet_Edition\package\ProShop-Tablet-Android.apk
```

## Integrity Manifest

يمكن إنشاء ملف السلامة لأي حزمة:

```powershell
.\tools\generate_integrity_manifest.ps1 -PackagePath Builds\Windows_Edition\package
```

## iPadOS On Mac

من جهاز Mac:

```bash
./tools/build_ipados_on_mac.sh
open ios/Runner.xcworkspace
```
