const toast = document.querySelector("#toast");
const shareButton = document.querySelector("#shareButton");
const year = document.querySelector("#year");
let toastTimer;

function showToast(title, message) {
  if (!toast) return;
  toast.querySelector("strong").textContent = title;
  toast.querySelector("span").textContent = message;
  toast.classList.add("is-visible");
  window.clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => {
    toast.classList.remove("is-visible");
  }, 3400);
}

document.querySelectorAll("[data-download]").forEach((link) => {
  link.addEventListener("click", () => {
    const isIphone = link.dataset.download === "iphone";
    showToast(
      isIphone ? "بدأ تحميل مجلد iPhone" : "بدأ تحميل تطبيق Android",
      isIphone
        ? "هذا مجلد المشروع للمطور وليس ملف IPA قابلًا للتثبيت."
        : "ستجد ملف APK في مجلد التنزيلات."
    );
  });
});

shareButton?.addEventListener("click", async () => {
  const shareData = {
    title: "مساعد الصيانة",
    text: "صفحة تنزيل تطبيق مساعد الصيانة لأجهزة Android وiPhone.",
    url: window.location.href,
  };

  try {
    if (navigator.share) {
      await navigator.share(shareData);
      return;
    }
    await navigator.clipboard.writeText(window.location.href);
    showToast("تم نسخ الرابط", "يمكنك إرساله الآن إلى الجوال.");
  } catch (error) {
    if (error?.name !== "AbortError") {
      showToast("تعذّرت المشاركة", "انسخ رابط الصفحة من المتصفح.");
    }
  }
});

if (year) {
  year.textContent = new Date().getFullYear();
}
