const ANDROID_URL =
  "https://github.com/yasser-dev2024/mobail2026fixe/raw/refs/heads/fix-whatsapp-pdf-device-duplicates-20260728/android/releases/Maintenance-Assistant-v1.0.0-universal.apk";

const IPHONE_SOURCE_URL =
  "https://github.com/yasser-dev2024/mobail2026fixe/raw/refs/heads/fix-whatsapp-pdf-device-duplicates-20260728/iphone/Maintenance-Assistant-iPhone-Source-v1.0.0.zip";

function DownloadIcon() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d="M12 3v12m0 0 5-5m-5 5-5-5M5 19h14" />
    </svg>
  );
}

function AndroidIcon() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d="m8 5-2-3m10 3 2-3M6.5 9h11M7 6h10a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2Zm1.5 12v3m7-3v3M5 9H3v6h2m14-6h2v6h-2" />
      <path d="M9 8h.01M15 8h.01" />
    </svg>
  );
}

function AppleIcon() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d="M16.7 13.2c0-2.8 2.3-4.1 2.4-4.2a5.1 5.1 0 0 0-4-2.2c-1.7-.2-3.3 1-4.1 1s-2.1-1-3.5-1c-1.8 0-3.5 1.1-4.5 2.7-1.9 3.3-.5 8.2 1.4 10.9.9 1.3 2 2.8 3.5 2.7 1.4-.1 1.9-.9 3.6-.9s2.2.9 3.6.9c1.5 0 2.5-1.3 3.4-2.7a11.8 11.8 0 0 0 1.5-3.1 4.7 4.7 0 0 1-3.3-4.1ZM14 5c.8-1 1.3-2.3 1.2-3.6-1.2.1-2.5.8-3.3 1.7-.7.8-1.4 2.2-1.2 3.5 1.3.1 2.5-.6 3.3-1.6Z" />
    </svg>
  );
}

function CheckIcon() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d="m20 6-11 11-5-5" />
    </svg>
  );
}

export default function Home() {
  return (
    <main className="page">
      <header className="topbar">
        <a className="brand" href="#top">
          <img src="/assets/app-icon.png" alt="" width="48" height="48" />
          <span>
            <strong>مساعد الصيانة</strong>
            <small>الصفحة الرسمية للتنزيل</small>
          </span>
        </a>
      </header>

      <section className="hero" id="top">
        <div className="status">
          <span />
          إصدار Android جاهز للتنزيل
        </div>
        <h1>
          اختر جهازك
          <br />
          <em>وحمّل النسخة المناسبة.</em>
        </h1>
        <p className="lead">
          تطبيق عربي لإدارة طلبات الصيانة والعملاء والضمان وفواتير PDF، من
          الاستلام حتى التسليم.
        </p>

        <div className="platforms" aria-label="خيارات تنزيل التطبيق">
          <article className="platform android">
            <div className="platform-head">
              <span className="platform-icon">
                <AndroidIcon />
              </span>
              <span className="availability ready">متاح الآن</span>
            </div>
            <h2>نسخة Android</h2>
            <p>ملف APK كامل وموقّع وجاهز للتثبيت على الجوال أو النقل بالفلاش.</p>
            <ul>
              <li>
                <CheckIcon /> الإصدار 1.0.0
              </li>
              <li>
                <CheckIcon /> حجم الملف 39.1 MB
              </li>
              <li>
                <CheckIcon /> Android 5.0 فأحدث
              </li>
            </ul>
            <a className="primary-button" href={ANDROID_URL}>
              <DownloadIcon />
              <span>
                <strong>تحميل Android</strong>
                <small>Maintenance-Assistant.apk</small>
              </span>
            </a>
          </article>

          <article className="platform iphone" id="iphone">
            <div className="platform-head">
              <span className="platform-icon">
                <AppleIcon />
              </span>
              <span className="availability source">مجلد المصدر</span>
            </div>
            <h2>نسخة iPhone</h2>
            <p>
              مجلد مشروع iPhone جاهز للتنزيل والتجهيز على جهاز Mac بواسطة Xcode.
            </p>
            <ul>
              <li>
                <CheckIcon /> اسم التطبيق: مساعد الصيانة
              </li>
              <li>
                <CheckIcon /> مشروع Flutter وXcode
              </li>
              <li>
                <CheckIcon /> يحتاج توقيع Apple قبل التثبيت
              </li>
            </ul>
            <a className="secondary-button" href={IPHONE_SOURCE_URL}>
              <DownloadIcon />
              <span>
                <strong>تحميل مجلد iPhone</strong>
                <small>ملف ZIP للمطور — ليس IPA</small>
              </span>
            </a>
          </article>
        </div>

        <p className="safety-note">
          زر Android يحمّل تطبيقًا قابلًا للتثبيت مباشرة. زر iPhone يحمّل مجلد
          المشروع؛ Apple لا تسمح بتثبيت ملف غير موقّع من رابط عادي.
        </p>
      </section>

      <section className="preview">
        <div className="preview-copy">
          <span className="section-label">ما الذي يديره التطبيق؟</span>
          <h2>كل خطوات الصيانة في شاشة واضحة</h2>
          <div className="feature-grid">
            <article>
              <strong>طلبات الصيانة</strong>
              <span>تسجيل الجهاز والعطل ومتابعة الحالة حتى التسليم.</span>
            </article>
            <article>
              <strong>الضمان والاستلام</strong>
              <span>سجل ضمان واضح واستلام الجهاز تحت الضمان بسهولة.</span>
            </article>
            <article>
              <strong>فاتورة PDF</strong>
              <span>فاتورة استلام تشمل بيانات العميل والجهاز والضمان.</span>
            </article>
            <article>
              <strong>إرسال واتساب</strong>
              <span>إرسال الفاتورة والتنبيهات للعميل عند التأكيد.</span>
            </article>
          </div>
        </div>
        <div className="phone" aria-label="صورة من داخل تطبيق مساعد الصيانة">
          <span className="speaker" />
          <img
            src="/assets/app-screen.png"
            alt="واجهة تطبيق مساعد الصيانة"
            width="1200"
            height="1920"
          />
        </div>
      </section>

      <section className="iphone-info" id="iphone-details">
        <span className="section-label">مهم لمستخدمي iPhone</span>
        <h2>لماذا لا يثبت التطبيق من الرابط مباشرة؟</h2>
        <p>
          لأن ملف Android بصيغة APK لا يعمل على iPhone. إصدار iPhone يجب بناؤه
          على macOS وتوقيعه بحساب Apple، ثم نشره عبر TestFlight أو App Store.
          المجلد الموجود هنا يحفظ مشروع iPhone كاملًا حتى يتم تنفيذ هذه الخطوة.
        </p>
        <a className="text-link" href="#iphone">
          العودة إلى زر iPhone
        </a>
      </section>

      <footer>
        <img src="/assets/app-icon.png" alt="" width="36" height="36" />
        <p>
          <strong>مساعد الصيانة</strong>
          <span>الإصدار 1.0.0</span>
        </p>
        <span className="copyright">© 2026</span>
      </footer>
    </main>
  );
}
