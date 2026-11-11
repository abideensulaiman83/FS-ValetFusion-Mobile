// lib/l10n/staff/ar_shop.dart
//
// Arabic for the outlet (shop) login's screen - shop_home_page.dart - and the server's refusals an
// outlet login can get. Keys are the exact English text passed to tr(context, ...). Placeholders
// use {name}. To be reviewed by a native speaker before a store release.
const Map<String, String> arShop = {
  // Drawer / header
  'Validate tickets': 'اعتماد التذاكر',
  'Could not load your outlet. Try again.': 'تعذّر تحميل بيانات المتجر. حاول مرة أخرى.',
  'Mobile access is switched off for this outlet - please use the web console.':
      'الوصول عبر التطبيق مُعطَّل لهذا المتجر - يُرجى استخدام لوحة التحكم على الويب.',
  'Look up a ticket, then validate it for your shop.': 'ابحث عن التذكرة، ثم اعتمدها لمتجرك.',
  'Look up a ticket, then request the car for the guest.': 'ابحث عن التذكرة، ثم اطلب السيارة للضيف.',

  // Ticket
  'Ticket not found': 'التذكرة غير موجودة',
  'This ticket is not in use': 'هذه التذكرة غير مستخدمة',
  'Ticket is marked as in use but no parking record found': 'التذكرة مستخدمة ولكن لا يوجد لها سجل صف',
  'No parking record for this ticket - ask the valet desk.': 'لا يوجد سجل صف لهذه التذكرة - راجع مكتب صف السيارات.',
  'Shop validated': 'معتمدة',
  'Already validated by {shop}': 'تم اعتمادها من {shop}',
  'an outlet': 'أحد المتاجر',
  'Not validated': 'غير معتمدة',
  'Already requested': 'تم طلبها مسبقًا',
  'Already requested - the car is on the way': 'تم طلبها مسبقًا - السيارة في الطريق',
  'The car is at the lobby': 'السيارة في الردهة',
  'Only a parked car can be validated or requested.': 'يمكن اعتماد أو طلب السيارة المصفوفة فقط.',
  'Price that applies': 'السعر المطبَّق',
  'Guest pays at the valet desk': 'يدفع الضيف لدى مكتب صف السيارات',
  'After validation by {shop}': 'بعد الاعتماد من {shop}',
  'After validation by your shop': 'بعد الاعتماد من متجرك',

  // Actions
  'Remarks (optional)': 'ملاحظات (اختياري)',
  'Validate': 'اعتماد',
  'Validating...': 'جارٍ الاعتماد...',
  'Validate & request car': 'اعتماد وطلب السيارة',
  'Request car': 'طلب السيارة',
  'Guest pays AED {amount} at the valet desk.': 'يدفع الضيف {amount} درهم لدى مكتب صف السيارات.',
  'Requesting the car is done at the valet desk.': 'يتم طلب السيارة لدى مكتب صف السيارات.',
  'This ticket still has a charge with your shop - the guest pays and requests the car at the valet desk.':
      'لا تزال على هذه التذكرة رسوم مع متجرك - يدفع الضيف ويطلب السيارة لدى مكتب صف السيارات.',
  'The charge with your shop is not known yet - the car can be requested at the valet desk.':
      'الرسوم مع متجرك غير معروفة بعد - يمكن طلب السيارة لدى مكتب صف السيارات.',
  'Ticket {no} is validated for your shop.': 'تم اعتماد التذكرة {no} لمتجرك.',
  'The car for ticket {no} has been requested. The valet team is bringing it.':
      'تم طلب سيارة التذكرة {no}. فريق صف السيارات في طريقه لإحضارها.',

  // Results
  'Ticket {no} validated': 'تم اعتماد التذكرة {no}',
  'Car requested for ticket {no}': 'تم طلب السيارة للتذكرة {no}',
  'Validation failed': 'تعذّر الاعتماد',
  'The car could not be requested': 'تعذّر طلب السيارة',
  'This ticket was already validated or is no longer parked.': 'تم اعتماد هذه التذكرة مسبقًا أو لم تعد السيارة مصفوفة.',
  'This car was already requested, or it now has a charge - ask the valet desk.':
      'تم طلب هذه السيارة مسبقًا، أو أصبحت عليها رسوم - راجع مكتب صف السيارات.',
  'This car was already requested or is no longer parked - ask the valet desk.':
      'تم طلب هذه السيارة مسبقًا أو لم تعد مصفوفة - راجع مكتب صف السيارات.',
  'This car is no longer parked, or the ticket could not be re-read - ask the valet desk.':
      'لم تعد السيارة مصفوفة، أو تعذّرت إعادة قراءة التذكرة - راجع مكتب صف السيارات.',
  'This ticket has a charge with your shop - the guest pays and requests the car at the valet desk.':
      'على هذه التذكرة رسوم مع متجرك - يدفع الضيف ويطلب السيارة لدى مكتب صف السيارات.',

  // Server refusals for an outlet login
  'This outlet can only request cars - validation is switched off.': 'يمكن لهذا المتجر طلب السيارات فقط - الاعتماد مُعطَّل.',
  'Requesting the car is switched off for this outlet.': 'طلب السيارة مُعطَّل لهذا المتجر.',
  'This shop is not active': 'هذا المتجر غير نشط',
};
