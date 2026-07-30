const ANDROID_URL =
  "https://github.com/yasser-dev2024/mobail2026fixe/raw/refs/heads/fix-whatsapp-pdf-device-duplicates-20260728/android/releases/Maintenance-Assistant-v1.0.0-universal.apk";

function Icon({ name }) {
  const paths = {
    download: (
      <>
        <path d="M12 3v12m0 0 5-5m-5 5-5-5M5 20h14" />
      </>
    ),
    android: (
      <>
        <path d="m8 5-2-3m10 3 2-3M6.5 9h11M7 6h10a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2Zm1.5 12v3m7-3v3M5 9H3v6h2m14-6h2v6h-2" />
        <path d="M9 8h.01M15 8h.01" />
      </>
    ),
    repair: (
      <path d="m14.5 6.5 3-3a5 5 0 0 1-6.2 6.2l-7.1 7.1a2.1 2.1 0 0 0 3 3l7.1-7.1a5 5 0 0 0 6.2-6.2l-3 3-3-3Z" />
    ),
    shield: (
      <>
        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z" />
        <path d="m9 12 2 2 4-4" />
      </>
    ),
    document: (
      <>
        <path d="M6 2h8l4 4v16H6Z" />
        <path d="M14 2v5h5M9 13h6M9 17h6" />
      </>
    ),
    message: (
      <>
        <path d="M21 11.5a8.4 8.4 0 0 1-9 8.5 9.3 9.3 0 0 1-4-.9L3 21l1.7-4.4A8.5 8.5 0 1 1 21 11.5Z" />
        <path d="M8 12h.01M12 12h.01M16 12h.01" />
      </>
    ),
    check: <path d="m20 6-11 11-5-5" />,
  };

  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      {paths[name]}
    </svg>
  );
}

function DownloadButton({ compact = false }) {
  return (
    <div className={`download-actions${compact ? " compact" : ""}`}>
      <a
        className="download-button android-button"
        href={ANDROID_URL}
        aria-label="تحميل مساعد الصيانة لأجهزة Android"
      >
        <span className="button-symbol">
          <Icon name="android" />
        </span>
        <span>
          <small>تحميل مباشر • الإصدار 1.0.0</small>
          <strong>تحميل تطبيق Android</strong>
        </span>
        <Icon name="download" />
      </a>
    </div>
  );
}

const features = [
  {
    icon: "repair",
    title: "إدارة طلبات الصيانة",
    text: "سجّل الجهاز والعطل وتابع حالته من الاستلام حتى التسليم.",
  },
  {
    icon: "shield",
    title: "سجل الضمانات",
    text: "تابع مدة الضمان واستقبل الجهاز تحت الضمان بخطوات واضحة.",
  },
  {
    icon: "document",
    title: "فواتير PDF",
    text: "أنشئ فاتورة استلام مرتبة تشمل بيانات الجهاز والضمان.",
  },
  {
    icon: "message",
    title: "التواصل مع العميل",
    text: "شارك الفاتورة والتحديثات مع العميل مباشرة عبر واتساب.",
  },
];

export default function Home() {
  return (
    <main className="page">
      <header className="topbar">
        <a className="brand" href="#top">
          <img src="/assets/app-icon.png" alt="" width="52" height="52" />
          <span>
            <strong>مساعد الصيانة</strong>
            <small>إدارة مراكز صيانة الجوالات</small>
          </span>
        </a>
        <a className="header-download" href="#download">
          تحميل التطبيق
        </a>
      </header>

      <section className="hero" id="top">
        <div className="hero-copy">
          <div className="hero-brand">
            <img
              src="/assets/app-icon.png"
              alt="شعار تطبيق مساعد الصيانة"
              width="118"
              height="118"
            />
            <span>
              <small>مصمم خصيصًا لأجهزة Android</small>
              <strong>مساعد الصيانة</strong>
            </span>
          </div>
          <div className="eyebrow">
            <span />
            Android بطابع مختلف
          </div>
          <h1>
            خلّ شغلك أسرع
            <br />
            <em>وكل صيانة أوضح.</em>
          </h1>
          <p>
            تطبيق Android عربي وحيوي يجمع طلبات الصيانة والضمان والفواتير
            والتواصل مع العميل في مكان واحد.
          </p>
          <DownloadButton />
          <div className="quick-points">
            <span>
              <Icon name="check" /> يعمل على Android
            </span>
            <span>
              <Icon name="check" /> تحميل مباشر
            </span>
            <span>
              <Icon name="check" /> يعمل دون اشتراك
            </span>
          </div>
        </div>

        <div className="hero-visual technician-visual">
          <div className="visual-label">
            <span />
            خبير الصيانة يوجّهك
          </div>
          <figure className="technician-stage">
            <img
              src="/assets/repair-technician-android-v1.png"
              alt="فني صيانة أنيميشن يحمل هاتفًا ومفكًا ويشير إلى زر تحميل تطبيق Android"
              width="931"
              height="1690"
              fetchPriority="high"
            />
          </figure>
          <div className="promo-chip">
            <span />
            <p>
              <small>اضغط هنا</small>
              <strong>وحَمّل التطبيق</strong>
            </p>
          </div>
        </div>
      </section>

      <section className="stats" aria-label="مواصفات مختصرة">
        <div>
          <strong>من الاستلام للتسليم</strong>
          <span>دورة صيانة كاملة</span>
        </div>
        <div>
          <strong>PDF</strong>
          <span>فواتير مرتبة</span>
        </div>
        <div>
          <strong>واتساب</strong>
          <span>تواصل أسرع</span>
        </div>
        <div>
          <strong>الضمان</strong>
          <span>متابعة وتنبيهات</span>
        </div>
      </section>

      <section className="features" aria-labelledby="features-title">
        <div className="section-heading">
          <span>مزايا التطبيق</span>
          <h2 id="features-title">أدوات ذكية. يوم أخف. عمل أوضح.</h2>
          <p>أدوات عملية مختصرة تساعدك على إنجاز العمل ومتابعة كل جهاز.</p>
        </div>
        <div className="feature-grid">
          {features.map((feature) => (
            <article key={feature.title}>
              <span className="feature-icon">
                <Icon name={feature.icon} />
              </span>
              <h3>{feature.title}</h3>
              <p>{feature.text}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="showcase" aria-labelledby="showcase-title">
        <div className="section-heading">
          <span>واجهات حقيقية</span>
          <h2 id="showcase-title">مصمم للعمل اليومي داخل مركز الصيانة</h2>
        </div>
        <div className="showcase-grid">
          <figure className="showcase-main">
            <div className="showcase-image">
              <img
                src="/assets/real-warranty.png"
                alt="واجهة استلام الجهاز تحت الضمان"
                width="1200"
                height="1920"
                loading="lazy"
              />
            </div>
            <figcaption>
              <strong>استلام الجهاز تحت الضمان</strong>
              <span>توثيق المشكلة وحالة الجهاز والصور قبل المعالجة.</span>
            </figcaption>
          </figure>
          <figure>
            <div className="showcase-image tracking-image">
              <img
                src="/assets/real-tracking.png"
                alt="واجهة متابعة حالة الصيانة"
                width="1200"
                height="1920"
                loading="lazy"
              />
            </div>
            <figcaption>
              <strong>متابعة حالة الصيانة</strong>
              <span>عرض واضح لمراحل الجهاز حتى اكتمال التسليم.</span>
            </figcaption>
          </figure>
        </div>
      </section>

      <section className="final-cta" id="download">
        <img
          src="/assets/app-icon.png"
          alt="شعار مساعد الصيانة"
          width="104"
          height="104"
          loading="lazy"
        />
        <div>
          <span>نسخة Android جاهزة الآن</span>
          <h2>حمّل مساعد الصيانة وابدأ العمل</h2>
        </div>
        <DownloadButton compact />
      </section>

      <footer>
        <div className="footer-brand">
          <img src="/assets/app-icon.png" alt="" width="38" height="38" />
          <p>
            <strong>مساعد الصيانة</strong>
            <span>الإصدار 1.0.0</span>
          </p>
        </div>
        <span>© 2026</span>
      </footer>
    </main>
  );
}
