import "./globals.css";

export const metadata = {
  title: "مساعد الصيانة | تنزيل التطبيق",
  description:
    "صفحة تنزيل مساعد الصيانة لأجهزة Android، مع مجلد مشروع iPhone وتعليمات النشر الرسمية.",
  icons: {
    icon: "/assets/app-icon.png",
    apple: "/assets/app-icon.png",
  },
  openGraph: {
    title: "مساعد الصيانة | تنزيل التطبيق",
    description: "إدارة طلبات الصيانة والضمان والفواتير من مكان واحد.",
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
