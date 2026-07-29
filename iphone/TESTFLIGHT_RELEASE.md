# إصدار iPhone عبر TestFlight

مسار الإصدار الحقيقي موجود في:
[`../.github/workflows/ios-testflight-release.yml`](../.github/workflows/ios-testflight-release.yml).

يعمل يدويًا فقط، ولا يرفع أي ملف ما لم يتم اختيار `confirm_upload=true`. قبل
تشغيله أنشئ بيئة GitHub باسم `testflight` وأضف الأسرار الآتية داخلها:

- `APPLE_TEAM_ID`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY_BASE64`
- `IOS_DISTRIBUTION_CERTIFICATE_BASE64`
- `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`

حوّل ملفات `.p8` و`.p12` و`.mobileprovision` إلى Base64 محليًا، ثم ضع النص
الناتج في GitHub Secrets. لا ترفع هذه الملفات إلى المستودع، ولا ترسلها في
المحادثة.

المفتاح المطلوب لـ `altool` هو **Team API Key** من App Store Connect. يفضّل
منحه أقل دور يسمح برفع البناء. يجب أن يطابق ملف التزويد:

- Team ID الموجود في `APPLE_TEAM_ID`.
- Bundle ID: `com.proshop.mobileShopPro`.
- نوع التوزيع: App Store Connect، وليس Development أو Ad Hoc.

قبل الرفع يتحقق المسار من:

1. صلاحية الشهادة وملف التزويد وعدم انتهائهما.
2. تطابق Team ID وBundle ID.
3. نجاح اختبارات Flutter.
4. صحة توقيع IPA ومنع `get-task-allow`.
5. عدم السماح باتصالات HTTP غير المقيدة.
6. عدم وجود مفاتيح أو شهادات أو ملفات تعريف إعداد داخل IPA.
7. نجاح تحقق Apple من الحزمة قبل رفعها.

بعد معالجة البناء داخل App Store Connect:

1. افتح TestFlight وأضف البناء إلى مجموعة المختبرين.
2. أكمل مراجعة TestFlight لأول إصدار خارجي.
3. أنشئ الرابط العام الذي يبدأ بـ:
   `https://testflight.apple.com/join/`
4. ضع الرابط العام فقط في `NEXT_PUBLIC_IOS_INSTALL_URL` عند بناء موقع التنزيل.

لن يعمل زر iPhone كتثبيت حقيقي قبل الخطوة الرابعة، لأن رابط TestFlight لا يمكن
إنشاؤه محليًا أو استنتاجه من Bundle ID.
