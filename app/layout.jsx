import "./globals.css";

export const metadata = {
  title: "مساعد الصيانة | تحميل تطبيق Android",
  description:
    "حمّل تطبيق مساعد الصيانة لأجهزة Android لإدارة الطلبات والعملاء والضمان وفواتير PDF.",
  icons: {
    icon: "/assets/app-icon.png",
    apple: "/assets/app-icon.png",
  },
  openGraph: {
    title: "مساعد الصيانة | تحميل Android",
    description: "تحميل مباشر لتطبيق إدارة طلبات الصيانة والضمان والفواتير.",
    images: [
      "https://raw.githubusercontent.com/yasser-dev2024/mobail2026fixe/fix-whatsapp-pdf-device-duplicates-20260728/android/assets/app-icon.png",
    ],
    locale: "ar_SA",
    type: "website",
  },
};

export default function RootLayout({ children }) {
  return (
    <html lang="ar" dir="rtl">
      <body>{children}</body>
    </html>
  );
}
