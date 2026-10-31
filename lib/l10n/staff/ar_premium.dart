// lib/l10n/staff/ar_premium.dart
//
// Arabic for the Premium sheet, damage marking and condition compare screens - keys are the exact English text passed to tr(context, ...).
// Placeholders use {name}. To be reviewed by a native speaker before a store release.
const Map<String, String> arPremium = {
  // Premium star / sheet
  'Premium - not on your plan': 'ميزة مميزة - غير مشمولة في خطتك',
  'Premium feature': 'ميزة مميزة',
  'This feature': 'هذه الميزة',
  'Part of Premium': 'ضمن الباقة المميزة',
  'Upgrade from the web console.': 'قم بالترقية من لوحة التحكم على الويب.',
  'Upgrade from the web console - or start the free 14-day trial there.':
      'قم بالترقية من لوحة التحكم على الويب - أو ابدأ هناك التجربة المجانية لمدة 14 يومًا.',
  'Ask your company admin - they can upgrade from the web console.':
      'تواصل مع مسؤول شركتك - يمكنه الترقية من لوحة التحكم على الويب.',
  'Your plan: {plan}': 'خطتك: {plan}',
  'Open web console': 'فتح لوحة التحكم على الويب',
  'OK': 'حسنًا',

  // Damage marking card
  'Damage marking': 'تحديد الأضرار',
  'Up to 50 marks per car.': 'الحد الأقصى 50 علامة لكل سيارة.',
  '#{n} {type} (already saved)': '#{n} {type} (محفوظة مسبقًا)',
  '#{n} {type} - {note} (already saved)': '#{n} {type} - {note} (محفوظة مسبقًا)',
  'Damage marks saved': 'تم حفظ علامات الأضرار',
  '{saved} saved, {failed} could not be saved': 'تم حفظ {saved}، وتعذّر حفظ {failed}',
  '1 mark': 'علامة واحدة',
  '{n} marks': 'العلامات: {n}',
  'Mark existing scratches and dents on the car - part of Premium.':
      'حدّد الخدوش والانبعاجات الموجودة على السيارة - ضمن الباقة المميزة.',
  'Tap the car where there is existing damage. Front of the car is at the top.':
      'اضغط على موضع الضرر الموجود في السيارة. مقدمة السيارة في الأعلى.',
  'Saving...': 'جارٍ الحفظ...',
  'Save 1 mark': 'حفظ علامة واحدة',
  'Save {n} marks': 'حفظ العلامات ({n})',
  'Damage marks could not be loaded.': 'تعذّر تحميل علامات الأضرار.',
  'No damage was marked at check-in.': 'لم تُسجَّل أي أضرار عند الاستلام.',
  'not saved yet': 'لم تُحفظ بعد',
  'Mark #{n}': 'العلامة #{n}',
  'Mark #{n} - {part}': 'العلامة #{n} - {part}',
  'Note': 'ملاحظة',
  'e.g. Bonnet, 5 cm scratch near the badge': 'مثال: غطاء المحرك، خدش 5 سم بجانب الشعار',
  'Remove': 'إزالة',
  'Add mark': 'إضافة علامة',
  'Update': 'تحديث',

  // Damage types
  'Scratch': 'خدش',
  'Dent': 'انبعاج',
  'Crack': 'كسر',
  'Other': 'أخرى',

  // Car diagram - zone labels
  'FRONT': 'الأمام',
  'BONNET': 'غطاء المحرك',
  'WINDSCREEN': 'الزجاج الأمامي',
  'ROOF': 'السقف',
  'WINDOW': 'النافذة',
  'BUMPER': 'الصدام',
  'REAR': 'الخلف',

  // Car diagram - panels
  'Front bumper': 'الصدام الأمامي',
  'Front left wing': 'الرفرف الأمامي الأيسر',
  'Front left wheel': 'العجلة الأمامية اليسرى',
  'Front right wing': 'الرفرف الأمامي الأيمن',
  'Front right wheel': 'العجلة الأمامية اليمنى',
  'Bonnet': 'غطاء المحرك',
  'Left headlight': 'المصباح الأمامي الأيسر',
  'Right headlight': 'المصباح الأمامي الأيمن',
  'Windscreen': 'الزجاج الأمامي',
  'Front left door': 'الباب الأمامي الأيسر',
  'Front right door': 'الباب الأمامي الأيمن',
  'Roof': 'السقف',
  'Rear left door': 'الباب الخلفي الأيسر',
  'Rear right door': 'الباب الخلفي الأيمن',
  'Rear left wing': 'الرفرف الخلفي الأيسر',
  'Rear left wheel': 'العجلة الخلفية اليسرى',
  'Rear right wing': 'الرفرف الخلفي الأيمن',
  'Rear right wheel': 'العجلة الخلفية اليمنى',
  'Rear window': 'الزجاج الخلفي',
  'Boot': 'صندوق الأمتعة',
  'Boot (spare / kit)': 'صندوق الأمتعة (الإطار الاحتياطي / العُدّة)',
  'Rear bumper': 'الصدام الخلفي',

  // Condition compare
  'Compare condition': 'مقارنة حالة السيارة',
  // The check-in column sits on the right in Arabic (the row mirrors), hence "right" first.
  'Left: at check-in ({time}). Right: now - tap an empty slot to photograph that side.':
      'اليمين: عند الاستلام ({time}). اليسار: الآن - اضغط على خانة فارغة لتصوير ذلك الجانب.',
  'Left: at check-in. Right: now - tap an empty slot to photograph that side.':
      'اليمين: عند الاستلام. اليسار: الآن - اضغط على خانة فارغة لتصوير ذلك الجانب.',
  'CHECK-IN': 'عند الاستلام',
  'NOW': 'الآن',
  'Other photos': 'صور أخرى',
  'Damage marked at check-in': 'الأضرار المسجّلة عند الاستلام',
  'Front': 'الأمام',
  'Back': 'الخلف',
  'Left': 'الجانب الأيسر',
  'Right': 'الجانب الأيمن',
  'No check-in photo': 'لا توجد صورة عند الاستلام',
  'Take now': 'التقط الآن',
};
