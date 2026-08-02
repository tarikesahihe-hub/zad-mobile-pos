/// Central place for the ZAD Platform backend URL.
///
/// TODO: بدّل هاد الرابط بعد ما يتم استضافة (hosting) الـ PostgreSQL backend.
/// حالياً مازال المشروع محلي فقط (حسب آخر حالة معروفة)، فـ التفعيل غايبقى
/// يفشل بلا نت حقيقي حتى تحط هنا الرابط النهائي (مثلاً:
/// https://api.zad.dz أو IP السيرفر ديالك).
class ApiConfig {
  static const String baseUrl = 'https://api.zad.dz';

  static const String licenseActivateEndpoint = '$baseUrl/api/licenses/activate';
  static const String licenseVerifyEndpoint = '$baseUrl/api/licenses/verify';
}
