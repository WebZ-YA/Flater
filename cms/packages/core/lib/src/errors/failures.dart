sealed class CmsFailure implements Exception {
  const CmsFailure(this.code, this.arabicMessage);
  final String code;
  final String arabicMessage;
}

class AuthFailure extends CmsFailure {
  const AuthFailure(super.code, super.arabicMessage);
}

class PermissionFailure extends CmsFailure {
  const PermissionFailure([
    super.code = 'PERMISSION_DENIED',
    super.arabicMessage = 'ليست لديك الصلاحية اللازمة لتنفيذ هذه العملية.',
  ]);
}

class ConflictFailure extends CmsFailure {
  const ConflictFailure(this.conflictId, super.arabicMessage) : super('SYNC_CONFLICT');
  final String conflictId;
}

class DuplicateRecordFailure extends CmsFailure {
  const DuplicateRecordFailure(super.code, super.arabicMessage);
}

class NetworkOfflineFailure extends CmsFailure {
  const NetworkOfflineFailure()
      : super('NETWORK_OFFLINE', 'لا يوجد اتصال بالإنترنت. تم حفظ العملية محلياً للمزامنة لاحقاً.');
}
