# Clinic Management System (CMS)

نظام إدارة العيادات الطبية المتكامل المبني وفق وثيقة المتطلبات **SRS v1.1** بمعمارية **Hybrid Local + Cloud**:
- **Flutter Multi-Platform App** (`cms/apps/clinic_app`): واجهات عربية RTL بـ Material Design 3، Riverpod، وGoRouter.
- **Dart Local Clinic Server** (`cms/apps/local_server`): خادم LAN باستخدام Shelf + WebSocket + SQLite/Drift + محرك مزامنة ثنائي الاتجاه (Outbox/Inbox).
- **Firebase Cloud Backend** (`cms/firebase`): قواعد أمان متعددة العيادات (`firestore.rules`, `storage.rules`) وCloud Functions (TypeScript).
- **Documentation & Tests** (`cms/docs/`, `cms/test/`).

راجع `cms/docs/architecture.md` و`cms/docs/deployment.md` لتفاصيل التشغيل والنشر.
