// lib/l10n/app_strings.dart
//
// English / Arabic for the guest-facing screens (landing, guest sign-in, My Valet, history, live
// tracking). Keys are the English text itself, so an untranslated string simply shows in English
// instead of breaking. Placeholders use {name}. Arabic flips the layout right-to-left through
// flutter_localizations (see MaterialApp in main.dart).
//
// The Arabic below should be reviewed by a native speaker before a store release.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController {
  LocaleController._();
  static const String _key = 'vf_locale';

  /// null = follow the phone's language.
  static final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code == 'ar' || code == 'en') locale.value = Locale(code!);
  }

  static Future<void> set(String code) async {
    locale.value = Locale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }
}

bool isArabic(BuildContext context) => Localizations.localeOf(context).languageCode == 'ar';

String tr(BuildContext context, String en, [Map<String, Object?> args = const {}]) {
  var text = isArabic(context) ? (_ar[en] ?? en) : en;
  args.forEach((k, v) => text = text.replaceAll('{$k}', '${v ?? ''}'));
  return text;
}

/// "العربية" / "English" switch for app bars and headers.
class LanguageToggle extends StatelessWidget {
  final Color? color;
  const LanguageToggle({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final ar = isArabic(context);
    return TextButton(
      onPressed: () => LocaleController.set(ar ? 'en' : 'ar'),
      style: TextButton.styleFrom(foregroundColor: color),
      child: Text(ar ? 'English' : 'العربية', style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

const Map<String, String> _ar = {
  // Landing
  'Exit App?': 'الخروج من التطبيق؟',
  'Are you sure you want to close Valet Fusion?': 'هل تريد إغلاق Valet Fusion؟',
  'Exit': 'خروج',
  'Cancel': 'إلغاء',
  "Who's using the app right now?": 'من يستخدم التطبيق الآن؟',
  'Valet Team': 'فريق صف السيارات',
  'Drivers, key control & lobby desk': 'السائقون وإدارة المفاتيح ومكتب الاستقبال',
  'Customer': 'العميل',
  'Track & request my car': 'تتبّع سيارتي واطلبها',
  'Admin Console': 'لوحة الإدارة',
  'Insights, operations, reports & full management': 'التحليلات والعمليات والتقارير والإدارة الكاملة',
  'Report an issue': 'الإبلاغ عن مشكلة',
  'Privacy & Policy': 'الخصوصية والسياسة',

  // Guest sign-in / sign-up
  'Sign in to Valet Fusion': 'تسجيل الدخول إلى Valet Fusion',
  'Enable Face ID / Fingerprint?': 'تفعيل بصمة الوجه / الإصبع؟',
  'Sign in faster next time using your face or fingerprint instead of typing your password.':
      'سجّل الدخول بشكل أسرع في المرة القادمة باستخدام وجهك أو بصمتك بدلًا من كتابة كلمة المرور.',
  'Not now': 'ليس الآن',
  'Enable': 'تفعيل',
  'Confirm to enable Face ID / Fingerprint sign-in': 'أكّد لتفعيل تسجيل الدخول ببصمة الوجه / الإصبع',
  'Please select your property': 'يرجى اختيار الموقع',
  'Guest Sign Up': 'تسجيل ضيف جديد',
  'Guest Sign In': 'تسجيل دخول الضيف',
  'Create your guest account': 'أنشئ حساب الضيف',
  'Welcome back': 'مرحبًا بعودتك',
  'Your Name': 'الاسم',
  'Email (optional)': 'البريد الإلكتروني (اختياري)',
  'Lets you reset your password later': 'يتيح لك إعادة تعيين كلمة المرور لاحقًا',
  'Mobile Number *': 'رقم الجوال *',
  'Required': 'مطلوب',
  'Password *': 'كلمة المرور *',
  'Remember me': 'تذكّرني',
  'Sign Up': 'تسجيل',
  'Sign In': 'تسجيل الدخول',
  'Authenticating...': 'جارٍ التحقق...',
  'Sign in with Face ID / Fingerprint': 'تسجيل الدخول ببصمة الوجه / الإصبع',
  'Already have an account? Sign in': 'لديك حساب؟ سجّل الدخول',
  'New guest? Sign up': 'ضيف جديد؟ سجّل الآن',
  'Forgot Password?': 'نسيت كلمة المرور؟',
  'Could not load properties.': 'تعذّر تحميل المواقع.',
  'Retry': 'إعادة المحاولة',
  'Property *': 'الموقع *',

  // My Valet
  'My Valet': 'خدمتي',
  'My property': 'موقعي',
  'Scan Your Ticket': 'امسح تذكرتك',
  'Enter or scan your ticket number': 'أدخل رقم التذكرة أو امسحها',
  'How was your experience?': 'كيف كانت تجربتك؟',
  'Any comments? (optional)': 'أي ملاحظات؟ (اختياري)',
  'Skip': 'تخطٍّ',
  'Thanks for your feedback!': 'شكرًا على ملاحظاتك!',
  'Submit': 'إرسال',
  'Wash requested - the team has been notified.': 'تم طلب الغسيل - تم إبلاغ الفريق.',
  'Requesting...': 'جارٍ الطلب...',
  'Request a Wash': 'طلب غسيل',
  'Wash requested - waiting for a driver': 'تم طلب الغسيل - بانتظار سائق',
  'Your car is being washed': 'سيارتك قيد الغسيل',
  'Wash complete': 'اكتمل الغسيل',
  'Your car has been requested!': 'تم طلب سيارتك!',
  'Payment Method': 'طريقة الدفع',
  'Parking charge: AED {amount}': 'رسوم الصف: {amount} درهم',
  'How would you like to pay at the lobby desk?': 'كيف تفضّل الدفع عند مكتب الاستقبال؟',
  'Cash': 'نقدًا',
  'Card': 'بطاقة',
  'Log out?': 'تسجيل الخروج؟',
  "You'll need to sign in again to continue.": 'ستحتاج إلى تسجيل الدخول مرة أخرى للمتابعة.',
  'Log out': 'تسجيل الخروج',
  'Logout': 'تسجيل الخروج',
  'Delete your account?': 'حذف حسابك؟',
  'This permanently removes your name, mobile number and email from Valet Fusion and signs you out on this phone. You can register again later with the same number.':
      'سيؤدي هذا إلى حذف اسمك ورقم جوالك وبريدك الإلكتروني نهائيًا من Valet Fusion وتسجيل خروجك من هذا الهاتف. يمكنك التسجيل مرة أخرى لاحقًا بالرقم نفسه.',
  'Past ticket records stay with the property that parked your car, without your contact details.':
      'تبقى سجلات التذاكر السابقة لدى الموقع الذي صفّ سيارتك، دون بيانات التواصل الخاصة بك.',
  'Enter your password to confirm': 'أدخل كلمة المرور للتأكيد',
  'Enter your password': 'أدخل كلمة المرور',
  'Deleting...': 'جارٍ الحذف...',
  'Delete account': 'حذف الحساب',
  'Your account has been deleted.': 'تم حذف حسابك.',
  'Delete my account': 'حذف حسابي',
  'My Parking History': 'سجل الصف',
  'More': 'المزيد',
  'Track a different ticket': 'تتبّع تذكرة أخرى',
  'Track Your Vehicle': 'تتبّع سيارتك',
  'Enter or scan your ticket number to see live status.': 'أدخل رقم التذكرة أو امسحها لمعرفة الحالة المباشرة.',
  'Ticket Number': 'رقم التذكرة',
  'Scan': 'مسح',
  'Check Status': 'عرض الحالة',
  "This ticket hasn't been used yet": 'لم تُستخدم هذه التذكرة بعد',
  'No vehicle has been checked in against this ticket at {place} yet.': 'لم تُسجَّل أي سيارة بهذه التذكرة في {place} حتى الآن.',
  'this property': 'هذا الموقع',
  'Parked at {place}': 'مصفوفة في {place}',
  'Payment: {method}': 'الدفع: {method}',
  'Request My Car': 'اطلب سيارتي',
  'Which property are you at?': 'في أي موقع أنت؟',
  'Picking a property looks up tickets there instead of your home property.':
      'عند اختيار موقع، يتم البحث عن التذاكر فيه بدلًا من موقعك الأساسي.',
  'Detecting...': 'جارٍ التحديد...',
  'Detect automatically (GPS)': 'تحديد تلقائي (GPS)',
  'No properties available.': 'لا توجد مواقع متاحة.',
  'Your property': 'موقعك',

  // Status
  'Your vehicle is safely parked.': 'سيارتك مصفوفة بأمان.',
  "We've received your request - a valet is on the way to get your vehicle.": 'تم استلام طلبك - أحد موظفينا في طريقه لإحضار سيارتك.',
  'Your vehicle is on its way to you now.': 'سيارتك في الطريق إليك الآن.',
  'Your vehicle has arrived and is waiting for you.': 'وصلت سيارتك وهي بانتظارك.',
  'Your vehicle has been delivered. Thank you!': 'تم تسليم سيارتك. شكرًا لك!',
  'Status updated.': 'تم تحديث الحالة.',
  'Parked': 'مصفوفة',
  'Requested': 'تم الطلب',
  'On the way': 'في الطريق',
  'Arrived': 'وصلت',
  'Delivered': 'تم التسليم',

  // Live tracking card
  'Updated {n}s ago': 'تم التحديث قبل {n} ثانية',
  'Updated {n} min ago': 'تم التحديث قبل {n} دقيقة',
  'Arriving now': 'تصل الآن',
  '{n} min': '{n} دقيقة',
  'Your driver is bringing the car to you.': 'السائق يُحضر السيارة إليك.',
  "Based on your driver's live location": 'بناءً على الموقع المباشر للسائق',
  'Estimated arrival time': 'وقت الوصول المتوقع',
  ' · updated by your driver': ' · حدّثه السائق',
  'Estimated arrival': 'الوصول المتوقع',
  "The live map appears as soon as your driver's location comes through.": 'ستظهر الخريطة المباشرة فور وصول موقع السائق.',
  'Live location': 'الموقع المباشر',
  'LIVE': 'مباشر',
  'Last known position': 'آخر موقع معروف',
  'Updated {h} h {m} min ago': 'تم التحديث قبل {h} ساعة و{m} دقيقة',
  "This is taking longer than usual. If you're already at the lobby, please ask the valet desk for an update.":
      'يستغرق الأمر وقتًا أطول من المعتاد. إذا كنت عند المدخل، يرجى سؤال مكتب خدمة صف السيارات عن آخر المستجدات.',
  'Your driver may be in an underground car park or a low-signal area. The position updates as soon as their phone reconnects - your car is on its way.':
      'قد يكون السائق في موقف تحت الأرض أو في منطقة ضعيفة الإشارة. سيتحدّث الموقع فور عودة الاتصال - سيارتك في الطريق.',
  'Your driver added {n} min to the arrival time': 'أضاف السائق {n} دقيقة إلى وقت الوصول',
  'just now': 'الآن',
  '{n} min ago': 'قبل {n} دقيقة',

  // History
  'No parking history yet': 'لا يوجد سجل صف بعد',
  'All Visits': 'كل الزيارات',
  'Total Visits': 'إجمالي الزيارات',
  'This Month': 'هذا الشهر',
  'Avg Rating': 'متوسط التقييم',
  'Total Spent': 'إجمالي المدفوع',
  'AED {amount}': '{amount} درهم',
  'Ticket {no}': 'تذكرة {no}',
};
