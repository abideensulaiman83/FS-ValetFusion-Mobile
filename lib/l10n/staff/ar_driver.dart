// lib/l10n/staff/ar_driver.dart
//
// Arabic for the driver screens - keys are the exact English text passed to tr(context, ...).
// Placeholders use {name}. To be reviewed by a native speaker before a store release.
const Map<String, String> arDriver = {
  // My Deliveries (driver_receive_page.dart)
  'My Deliveries': 'توصيلاتي',
  'Vehicle': 'المركبة',
  'Ticket': 'التذكرة',
  'Plate': 'اللوحة',
  'Key': 'المفتاح',
  'Bay {bay}': 'الموقف {bay}',
  'bay {bay}': 'الموقف {bay}',
  'Parking spot not recorded': 'لم يُسجَّل مكان الوقوف',
  'Guest expects the car now': 'الضيف ينتظر السيارة الآن',
  'Guest expects the car in {n} min': 'الضيف ينتظر السيارة خلال {n} دقيقة',
  'Update ETA': 'تحديث وقت الوصول',
  'Find car': 'العثور على السيارة',
  'Check key': 'التحقق من المفتاح',
  'Mark Arrived': 'تأكيد الوصول',
  'Hand Over': 'تسليم',
  'Arrival of ticket {no}': 'وصول التذكرة {no}',
  'Handover of ticket {no}': 'تسليم التذكرة {no}',
  'No signal - arrival saved on this phone and will be sent automatically.':
      'لا توجد إشارة - تم حفظ الوصول على هذا الهاتف وسيُرسَل تلقائيًا.',
  'No signal - handover saved on this phone and will be sent automatically.':
      'لا توجد إشارة - تم حفظ التسليم على هذا الهاتف وسيُرسَل تلقائيًا.',

  // Receive flow (driver_receive_page.dart)
  'Scan Ticket': 'مسح التذكرة',
  'Scan when taking the car from the guest - you will then be shown where to park it.':
      'امسح التذكرة عند استلام السيارة من الضيف - وسيظهر لك بعدها مكان صفّها.',
  'Scan or type the ticket number': 'امسح رقم التذكرة أو اكتبه',
  'Scan Barcode': 'مسح الباركود',
  'Check': 'تحقّق',
  'Enter or scan a ticket number first': 'أدخل رقم التذكرة أو امسحه أولًا',
  'Photograph the Vehicle': 'تصوير المركبة',
  'Plate, color, brand and model are filled in from the photo.':
      'تُملأ اللوحة واللون والعلامة التجارية والطراز تلقائيًا من الصورة.',
  'Reading the car...': 'جارٍ قراءة بيانات السيارة...',
  'Take Photo': 'التقاط صورة',
  'Retake Photo': 'إعادة التقاط الصورة',
  'No vehicle found in the photo - retake it, or type the details below.':
      'لم يتم العثور على مركبة في الصورة - أعد التقاطها أو اكتب البيانات أدناه.',
  'Plate not readable - please type it.': 'تعذّرت قراءة اللوحة - يرجى كتابتها.',
  'Vehicle Details': 'بيانات المركبة',
  'From photo - check': 'من الصورة - يرجى المراجعة',
  'Plate *': 'اللوحة *',
  'Color': 'اللون',
  'Brand': 'العلامة التجارية',
  'Model': 'الطراز',
  'Receive Vehicle': 'استلام المركبة',
  'Please enter the Plate Number (or take a photo first)': 'يرجى إدخال رقم اللوحة (أو التقاط صورة أولًا)',
  'Vehicle linked to ticket {no} - park it in the slot shown below.':
      'تم ربط المركبة بالتذكرة {no} - اصففها في الموقف المعروض أدناه.',
  'Park the Car': 'صفّ السيارة',
  'plate unknown': 'اللوحة غير معروفة',
  'Key Holder Number (optional)': 'رقم حامل المفتاح (اختياري)',
  "Scan the hook's key tag, or leave blank if you'll hand the key to a Key Controller":
      'امسح بطاقة مفتاح الخطّاف، أو اتركه فارغًا إذا كنت ستسلّم المفتاح إلى مسؤول المفاتيح',
  'Parked Here - Confirm': 'تم الصفّ هنا - تأكيد',
  'Pick a slot or type the bay where you parked': 'اختر موقفًا أو اكتب رقم الموقف الذي صففت فيه',
  'Parking location for ticket {no}': 'موقع الوقوف للتذكرة {no}',
  'No signal - parking saved on this phone and will be sent automatically.':
      'لا توجد إشارة - تم حفظ بيانات الصفّ على هذا الهاتف وستُرسَل تلقائيًا.',
  '{message}. Hand the key to the Key Controller.': '{message}. سلّم المفتاح إلى مسؤول المفاتيح.',
  '{message}, key holder {key}.': '{message}، حامل المفتاح {key}.',
  'Key holder {key} for ticket {no}': 'حامل المفتاح {key} للتذكرة {no}',
  'No signal - key holder {key} saved on this phone and will be sent automatically.':
      'لا توجد إشارة - تم حفظ حامل المفتاح {key} على هذا الهاتف وسيُرسَل تلقائيًا.',
  'Ticket {no}: key holder set to {key}': 'التذكرة {no}: تم تعيين حامل المفتاح إلى {key}',
  'Find my car': 'العثور على سيارتي',
  'Scan key tag': 'مسح بطاقة المفتاح',
  'Already parked': 'مصفوفة بالفعل',
  'Ticket {no} is parked at {place} (key: {key}).': 'التذكرة {no} مصفوفة في {place} (المفتاح: {key}).',
  'Ticket {no} is parked at {place}.': 'التذكرة {no} مصفوفة في {place}.',
  'Ticket status: {status}': 'حالة التذكرة: {status}',
  'This ticket has already moved past the parking step.': 'تجاوزت هذه التذكرة مرحلة الصفّ بالفعل.',

  // Shift card (driver_shift_card.dart)
  'End your shift?': 'إنهاء مناوبتك؟',
  'You still have 1 car on the way or at the lobby. The desk will see you as off duty.':
      'لا تزال لديك سيارة واحدة في الطريق أو عند المدخل. سيظهر للمكتب أنك خارج الدوام.',
  'You still have {n} cars on the way or at the lobby. The desk will see you as off duty.':
      'لا تزال لديك {n} سيارات في الطريق أو عند المدخل. سيظهر للمكتب أنك خارج الدوام.',
  'The desk will see you as off duty and stop suggesting you for pickups.':
      'سيظهر للمكتب أنك خارج الدوام ولن يتم اقتراحك لاستلام السيارات.',
  'End shift': 'إنهاء المناوبة',
  'Shift ended': 'انتهت المناوبة',
  '{h}h {m}m': '{h} س {m} د',
  '{m}m': '{m} د',
  '(breaks {d})': '(الاستراحات {d})',
  'Done': 'تم',
  'Shift status unavailable - retry': 'حالة المناوبة غير متاحة - إعادة المحاولة',
  'On duty': 'في الدوام',
  'On break': 'في استراحة',
  'Off duty': 'خارج الدوام',
  'since {time}': 'منذ {time}',
  'Last shift {start} - {end}: {received} received · {delivered} handed over':
      'آخر مناوبة {start} - {end}: استلام {received} · تسليم {delivered}',
  'Start shift': 'بدء المناوبة',
  'Back on duty': 'العودة إلى الدوام',
  'Break': 'استراحة',
  'Received': 'مستلمة',
  'Handed over': 'مسلّمة',
  'In hand': 'بحوزتك',

  // Find my car (find_my_car_page.dart)
  'Find car · {no}': 'العثور على السيارة · {no}',
  'Check-in photos': 'صور الاستلام',
  'Building': 'المبنى',
  'Floor': 'الطابق',
  'Zone': 'المنطقة',
  'SLOT': 'الموقف',
  'BAY': 'المكان',
  'Not recorded': 'غير مسجّل',
  'Key hook': 'خطّاف المفتاح',
  'Parked for': 'مدة الوقوف',

  // My Activity (driver_activity_page.dart)
  'My Activity': 'نشاطي',
  'Today': 'اليوم',
  'All Time': 'الإجمالي',
  'Avg. Turnaround': 'متوسط مدة التسليم',
  'Recent Deliveries': 'آخر التوصيلات',
  'No deliveries yet': 'لا توجد توصيلات بعد',

  // Condition photos (condition_photos.dart)
  'Condition photos': 'صور حالة السيارة',
  '{done} of {total}': '{done} من {total}',
  'Photograph each side now - shown again at handover if the guest asks about damage.':
      'صوّر كل جانب الآن - ستُعرض الصور مجددًا عند التسليم إذا سأل الضيف عن أي ضرر.',
  'Tap a photo to view it, long-press to retake.': 'اضغط على الصورة لعرضها، واضغط مطولًا لإعادة التقاطها.',
  'Photos could not be loaded.': 'تعذّر تحميل الصور.',
  'No photos were taken at check-in.': 'لم تُلتقط صور عند الاستلام.',
  'Condition at check-in': 'الحالة عند الاستلام',

  // Barcode scanner + guest QR sheet
  'Scan Ticket Barcode': 'مسح باركود التذكرة',
  'Point the camera at the ticket barcode': 'وجّه الكاميرا نحو باركود التذكرة',
  'Ask the guest to scan this to follow their car': 'اطلب من الضيف مسح هذا الرمز لمتابعة سيارته',
  'Link copied': 'تم نسخ الرابط',
  'Copy link': 'نسخ الرابط',
  // Delivery check-in (delivery_tracker)
  'Marked as arrived - the guest has been told.': 'تم تسجيل الوصول - تم إبلاغ الضيف.',
  'No signal - your update is saved and will be sent automatically.': 'لا توجد إشارة - تم حفظ التحديث وسيُرسل تلقائيًا.',
};
