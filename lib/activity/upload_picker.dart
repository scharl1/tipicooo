export 'upload_stub.dart'
  if (dart.library.html) '../web/upload_web.dart'
  if (dart.library.io) 'upload_mobile.dart';