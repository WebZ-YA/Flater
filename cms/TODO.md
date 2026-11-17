# TODO — المهام المتبقية (تتطلب Flutter/Dart SDK وFirebase Project فعلي)

1. تثبيت Flutter SDK `3.24+` وDart SDK `3.5+` على بيئة التطوير المستهدفة.
2. توليد كود Drift في الخادم المحلي عبر: `cd cms/apps/local_server && dart pub get && dart run build_runner build`.
3. استكمال شاشات التقويم التفصيلية للمواعيد وتفاصيل طباعة PDF الكاملة للوصفات والفواتير.
4. ربط `Cloud Functions` بمشروع Firebase فعلي وتفعيل `App Check` ومراجعة المنطقة الجغرافية السحابية (`firestoreRegion`) وفق المتطلبات القانونية.
5. تشغيل `flutter test` واختبارات `Firebase Emulator Suite` للتحقق من قواعد `firestore.rules` و`storage.rules`.
