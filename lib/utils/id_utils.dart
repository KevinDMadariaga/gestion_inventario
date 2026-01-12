import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

class IdUtils {
  static String hexFromAnyId(dynamic raw) {
    if (raw == null) return '';
    if (raw is ObjectId) return raw.toHexString();
    if (raw is Map && raw[r'$oid'] is String) return raw[r'$oid'] as String;

    final s = raw.toString();
    final mHex = RegExp(r'^[0-9a-fA-F]{24}$').firstMatch(s);
    if (mHex != null) return mHex.group(0)!;

    final mObj = RegExp(r'ObjectId\("([0-9a-fA-F]{24})"\)').firstMatch(s);
    if (mObj != null) return mObj.group(1)!;

    final mAny = RegExp(r'([0-9a-fA-F]{24})').firstMatch(s);
    return mAny?.group(1) ?? '';
  }

  /// Genera un nuevo ID único usando ObjectId de MongoDB
  static String generarId() {
    return ObjectId().toHexString();
  }
}
