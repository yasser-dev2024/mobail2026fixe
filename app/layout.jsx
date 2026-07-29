import "./globals.css";

export const metadata = {
  title: "مساعد الصيانة | تثبيت آمن للتطبيق",
  description:
    "ثبّت تطبيق مساعد الصيانة من قناة التوزيع المعتمدة لكل جهاز لإدارة الطلبات والعملاء والضمان وفواتير PDF.",
  icons: {
    icon: "/assets/app-icon.png",
    apple: "/assets/app-icon.png",
  },
  openGraph: {
    title: "مساعد الصيانة | تنزيل التطبيق",
    description: "إدارة أسرع لطلبات الصيانة والضمان والفواتير من مكان واحد.",
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
