/// Arabic UI strings for the Clinic Admin dashboard.
abstract class S {
  // ── App ─────────────────────────────────────────────────────────────────────
  static const appTitle           = 'لوحة إدارة العيادة';
  static const clinicAdmin        = 'كلينيك كارد';

  // ── Auth ────────────────────────────────────────────────────────────────────
  static const signIn             = 'تسجيل الدخول';
  static const signOut            = 'تسجيل الخروج';
  static const email              = 'البريد الإلكتروني';
  static const password           = 'كلمة المرور';
  static const signInSubtitle     = 'تسجيل الدخول لإدارة المنظومة';
  static const invalidEmail       = 'أدخل بريدًا إلكترونيًا صحيحًا';
  static const passwordMin        = '6 أحرف على الأقل';
  static const adminHint          = 'أنشئ حسابك في Supabase Dashboard → Authentication → Users ثم طبّق سياسات SQL.';

  // ── Navigation ──────────────────────────────────────────────────────────────
  static const dashboard          = 'لوحة التحكم';
  static const doctors            = 'الأطباء';
  static const bookings           = 'الحجوزات';
  static const installments       = 'الأقساط';
  static const patients           = 'المرضى';
  static const loans              = 'القروض';
  static const notifications      = 'الإشعارات';
  static const categories         = 'التصنيفات';
  static const areas              = 'المناطق';

  // ── Common actions ──────────────────────────────────────────────────────────
  static const save               = 'حفظ';
  static const cancel             = 'إلغاء';
  static const delete             = 'حذف';
  static const edit               = 'تعديل';
  static const add                = 'إضافة';
  static const search             = 'بحث...';
  static const refresh            = 'تحديث';
  static const close              = 'إغلاق';
  static const confirm            = 'تأكيد';
  static const saving             = 'جارٍ الحفظ...';
  static const loading            = 'جاري التحميل...';
  static const noData             = 'لا توجد بيانات';
  static const actions            = 'الإجراءات';
  static const sending            = 'جارٍ الإرسال...';
  static const send               = 'إرسال';
  static const export             = 'تصدير';
  static const all                = 'الكل';
  static const active             = 'نشط';
  static const inactive           = 'غير نشط';
  static const required           = 'مطلوب';
  static const generating         = 'جارٍ الإنشاء...';

  // ── Statuses ────────────────────────────────────────────────────────────────
  static const approved           = 'مقبول';
  static const rejected           = 'مرفوض';
  static const submitted          = 'مقدّم';
  static const underReview        = 'قيد المراجعة';
  static const pending            = 'معلّق';
  static const confirmed          = 'مؤكد';
  static const completed          = 'مكتمل';
  static const cancelled          = 'ملغى';
  static const noShow             = 'لم يحضر';
  static const paid               = 'مدفوع';
  static const overdue            = 'متأخر';
  static const sent               = 'مُرسل';

  // ── Dashboard ───────────────────────────────────────────────────────────────
  static const dashboardTitle     = 'لوحة التحكم الرئيسية';
  static const lastRefreshed      = 'آخر تحديث';
  static const bookingsToday      = 'حجوزات اليوم';
  static const invoicesMtd        = 'فواتير الأقساط (الشهر)';
  static const registrationsToday = 'تسجيلات اليوم';
  static const totalPatients      = 'إجمالي المرضى';
  static const activeDoctors      = 'الأطباء النشطون';
  static const revenueMtd         = 'إيرادات المنصة (الشهر)';
  static const pendingLoans       = 'طلبات قروض معلقة';
  static const bookingsTrend      = 'اتجاه الحجوزات (30 يوم)';
  static const revenueBreakdown   = 'توزيع الإيرادات';
  static const registrationsByDay = 'تسجيلات الأسبوع الماضي';
  static const bookingCommission  = 'عمولة الحجوزات';
  static const installmentFees    = 'رسوم الأقساط';
  static const cardSales          = 'مبيعات الكارت';
  static const egp                = 'ج.م';
  static const count              = 'عدد';

  // ── Bookings ────────────────────────────────────────────────────────────────
  static const bookingOpsTitle    = 'إدارة الحجوزات';
  static const bookingAnalytics   = 'تحليلات الحجوزات';
  static const statusBreakdown    = 'توزيع الحالات';
  static const topDoctors         = 'أفضل الأطباء';
  static const totalBookings      = 'إجمالي الحجوزات';
  static const dateRange          = 'نطاق التاريخ';
  static const specialty          = 'التخصص';
  static const doctorName         = 'اسم الطبيب';
  static const avgRating          = 'متوسط التقييم';
  static const invoicesSent       = 'الفواتير المرسلة';
  static const exportCsv          = 'تصدير CSV';
  static const last7Days          = 'آخر 7 أيام';
  static const last30Days         = 'آخر 30 يوم';
  static const last90Days         = 'آخر 90 يوم';

  // ── Installments ────────────────────────────────────────────────────────────
  static const installmentOpsTitle= 'إدارة الأقساط';
  static const invoicePipeline    = 'مسار الفواتير';
  static const pipelineSummary    = 'ملخص المسار';
  static const overdueAlerts      = 'تنبيهات المتأخرين';
  static const procedure          = 'الإجراء';
  static const daysOverdue        = 'أيام التأخير';
  static const amount             = 'المبلغ';
  static const doctor             = 'الطبيب';
  static const patient            = 'المريض';
  static const invoiceDate        = 'تاريخ الفاتورة';
  static const totalAmount        = 'إجمالي المبلغ';
  static const filterByStatus     = 'فلترة بالحالة';

  // ── Patients ────────────────────────────────────────────────────────────────
  static const patientMgmtTitle   = 'إدارة حسابات المرضى';
  static const patientProfile     = 'ملف المريض';
  static const bookingHistory     = 'سجل الحجوزات';
  static const installmentHistory = 'سجل الأقساط';
  static const activityLog        = 'سجل النشاط';
  static const segment            = 'الشريحة';
  static const memberSince        = 'عضو منذ';
  static const lastActive         = 'آخر نشاط';
  static const noPatients         = 'لم يتم العثور على مرضى.';
  static const noBookings         = 'لا توجد حجوزات.';
  static const noInvoices         = 'لا توجد فواتير.';
  static const allSegments        = 'كل الشرائح';
  static const highValue          = 'عميل مميز';
  static const dormant30          = 'خامل (30-90 يوم)';
  static const dormant90          = 'خامل (90+ يوم)';
  static const noActivity         = 'مسجّل بلا نشاط';

  // ── Loans ───────────────────────────────────────────────────────────────────
  static const loanRequestsTitle  = 'طلبات القروض';
  static const loanDetails        = 'تفاصيل طلب القرض';
  static const applicantProfile   = 'ملف المتقدم';
  static const walletHistory      = 'سجل معاملات المحفظة';
  static const docsAndImages      = 'الوثائق والصور';
  static const nidFront           = 'الهوية الوطنية (أمام)';
  static const nidBack            = 'الهوية الوطنية (خلف)';
  static const claimReport        = 'تقرير المطالبة';
  static const medicalReport      = 'التقرير الطبي';
  static const notUploaded        = 'لم يتم الرفع';
  static const requestId          = 'رقم الطلب';
  static const approvedAmount     = 'المبلغ المعتمد';
  static const lastUpdated        = 'آخر تحديث';
  static const approvedBy         = 'اعتمد بواسطة';
  static const fullName           = 'الاسم الكامل';
  static const phone              = 'الهاتف';
  static const city               = 'المدينة';
  static const noLoans            = 'لا توجد طلبات قروض.';
  static const noTransactions     = 'لا توجد معاملات بعد.';
  static const approveLoan        = 'الموافقة على القرض';
  static const rejectLoan         = 'رفض طلب القرض';
  static const amountToCredit     = 'المبلغ المراد إضافته (ج.م) *';
  static const approveAndCredit   = 'موافقة وإضافة للمحفظة';
  static const confirmApproval    = 'تأكيد الموافقة';
  static const processing         = 'جاري المعالجة...';
  static const loanApproved       = 'تمت الموافقة';
  static const loanRejected       = 'تم الرفض';
  static const status             = 'الحالة';
  static const noDocuments        = 'لم يتم رفع أي وثائق بعد';
  static const openInBrowser      = 'فتح في المتصفح';
  static const couldNotLoad       = 'تعذّر تحميل الصورة';
  static const shown              = 'معروض';

  // ── Doctors ─────────────────────────────────────────────────────────────────
  static const doctorsTitle       = 'قائمة الأطباء / مزودي الخدمة';
  static const addDoctor          = 'إضافة طبيب';
  static const editDoctor         = 'تعديل طبيب';
  static const doctorCode         = 'كود الطبيب';
  static const specialty2         = 'التخصص';
  static const category           = 'التصنيف';
  static const noDoctors          = 'لا يوجد أطباء.';
  static const confirmDelete      = 'تأكيد الحذف';
  static const deleteConfirmMsg   = 'هل أنت متأكد من حذف هذا الطبيب؟';
  static const basicInfo          = 'المعلومات الأساسية';
  static const socialMedia        = 'وسائل التواصل الاجتماعي';
  static const locations          = 'المواقع';
  static const addLocation        = 'إضافة موقع';
  static const removeLocation     = 'حذف الموقع';
  static const address            = 'العنوان';
  static const latitude           = 'خط العرض';
  static const longitude          = 'خط الطول';
  static const bookingFee         = 'رسوم الحجز';
  static const workingHours       = 'ساعات العمل';
  static const addHour            = 'إضافة ساعة';
  static const doctorLoginAccount = 'حساب تسجيل الدخول';
  static const loginEmail         = 'بريد تسجيل الدخول *';
  static const loginPassword      = 'كلمة مرور الحساب *';
  static const generatePassword   = 'توليد كلمة مرور';
  static const showCredentials    = 'عرض بيانات الدخول';
  static const doctorCredentials  = 'بيانات دخول الطبيب';
  static const credentialsHint      = 'سلّم هذه البيانات للطبيب لاستخدام تطبيق العيادة.';
  static const noAccountYet       = 'لا يوجد حساب مسجّل لهذا الطبيب';
  static const copied             = 'تم النسخ';
  static const copy               = 'نسخ';
  static const accountCreated     = 'تم إنشاء حساب الطبيب بنجاح';
  static const authUserId         = 'معرّف المستخدم';

  // ── Notifications ───────────────────────────────────────────────────────────
  static const notificationsTitle = 'الإشعارات والإعدادات';
  static const sendPush           = 'إرسال إشعار فوري';
  static const targetAudience     = 'الجمهور المستهدف';
  static const allUsers           = 'كل المستخدمين';
  static const newUsers           = 'جدد (أقل من 7 أيام)';
  static const activeUsers        = 'مستخدمون نشطون';
  static const dormant30Users     = 'خاملون 30-90 يوم';
  static const dormant90Users     = 'خاملون 90+ يوم';
  static const notifTitle         = 'عنوان الإشعار *';
  static const notifTitleHint     = 'مثال: عرض خاص لك!';
  static const notifBody          = 'نص الرسالة *';
  static const notifBodyHint      = 'اكتب نص الإشعار هنا...';
  static const sendNotification   = 'إرسال الإشعار';
  static const procedureCategories= 'تصنيفات إجراءات الأقساط';
  static const reportsExports     = 'التقارير والتصدير';
  static const monthlyReport      = 'التقرير الشهري';
  static const bookingsCsv        = 'حجوزات CSV';
  static const invoicesCsv        = 'فواتير CSV';
  static const patientListCsv     = 'قائمة المرضى CSV';
  static const doctorListCsv      = 'قائمة الأطباء CSV';

  // ── Areas / Categories ──────────────────────────────────────────────────────
  static const areasTitle         = 'المناطق';
  static const addArea            = 'إضافة منطقة';
  static const editArea           = 'تعديل منطقة';
  static const deleteArea         = 'حذف المنطقة';
  static const deleteAreaMsg      = 'حذف هذه المنطقة؟ ستفقد المواقع المرتبطة بها تصنيفها.';
  static const noAreas            = 'لا توجد مناطق بعد.';
  static const categoriesTitle    = 'التصنيفات';
  static const addCategory        = 'إضافة تصنيف';
  static const editCategory       = 'تعديل تصنيف';
  static const deleteCategory     = 'حذف التصنيف';
  static const deleteCategoryMsg  = 'حذف هذا التصنيف؟ سيفقد الأطباء المرتبطون به التصنيف.';
  static const noCategories       = 'لا توجد تصنيفات بعد.';
  static const nameEn             = 'الاسم (إنجليزي) *';
  static const nameAr             = 'الاسم (عربي)';
  static const nameBase           = 'الاسم الأساسي (احتياطي)';
  static const idCol              = 'الرقم';
  static const nameEnCol          = 'الاسم (EN)';
  static const nameArCol          = 'الاسم (AR)';
  static const nameBaseCol        = 'الاسم الأساسي';
}
