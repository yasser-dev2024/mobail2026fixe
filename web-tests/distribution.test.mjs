import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import vm from "node:vm";

import {
  approvedIosInstallUrl,
  iosDistributionName,
} from "../app/distribution.js";

test("accepts only install pages hosted by Apple", () => {
  const appStoreUrl =
    "https://apps.apple.com/sa/app/maintenance-assistant/id1234567890";
  const testFlightUrl = "https://testflight.apple.com/join/AbC123xy";

  assert.equal(approvedIosInstallUrl(appStoreUrl), appStoreUrl);
  assert.equal(approvedIosInstallUrl(testFlightUrl), testFlightUrl);
  assert.equal(iosDistributionName(testFlightUrl), "TestFlight");
  assert.equal(iosDistributionName(appStoreUrl), "App Store");
});

test("rejects files, insecure links, lookalike hosts, and malformed Apple paths", () => {
  const rejected = [
    "",
    "http://apps.apple.com/sa/app/example/id1234567890",
    "https://apps.apple.com.example.com/sa/app/example/id1234567890",
    "https://testflight.apple.com.example.com/join/AbC123xy",
    "https://github.com/example/app.zip",
    "https://example.com/app.ipa",
    "itms-services://?action=download-manifest&url=https://example.com/app.plist",
    "https://apps.apple.com/app/source.zip",
    "https://testflight.apple.com/download/app.ipa",
    "https://user:password@apps.apple.com/app/example/id1234567890",
  ];

  for (const value of rejected) {
    assert.equal(approvedIosInstallUrl(value), null, value);
  }
});

test("the public page renders an Android-only download experience", async () => {
  const [page, androidRedirect, legacyDownloadScript] = await Promise.all([
    readFile(new URL("../app/page.jsx", import.meta.url), "utf8"),
    readFile(new URL("../android/index.html", import.meta.url), "utf8"),
    readFile(new URL("../android/script.js", import.meta.url), "utf8"),
  ]);

  assert.doesNotMatch(page, /Maintenance-Assistant-iPhone-Source/i);
  assert.doesNotMatch(page, /iphone-button|iphone-install|IPHONE_URL/i);
  assert.match(page, /className="download-button android-button"/);
  assert.match(
    page,
    /Maintenance-Assistant-v1\.0\.3-universal\.apk/,
  );
  assert.doesNotMatch(page, /Maintenance-Assistant-v1\.0\.[012]-universal\.apk/);
  assert.equal((page.match(/<DownloadButton\s*\/>/g) ?? []).length, 1);
  assert.doesNotMatch(page, /promo-chip|header-download|<DownloadButton compact/);
  assert.match(page, /تحميل مساعد الصيانة/);
  assert.match(page, /repair-technician-android-v1\.png/);
  assert.match(page, /فني صيانة أنيميشن/);
  assert.doesNotMatch(page, /href\s*=\s*["'`][^"'`]*\.(?:zip|ipa|plist)/i);
  assert.doesNotMatch(page, /itms-services:/i);
  assert.doesNotMatch(
    androidRedirect,
    /href\s*=\s*["'][^"']*\.(?:zip|ipa|plist)/i,
  );
  assert.match(legacyDownloadScript, /link\.removeAttribute\("download"\)/);
  assert.match(legacyDownloadScript, /event\.preventDefault\(\)/);
  assert.doesNotMatch(legacyDownloadScript, /بدأ تحميل مجلد iPhone/);
});

test("download buttons keep immediate visual feedback on touch and click", async () => {
  const [css, androidCss] = await Promise.all([
    readFile(new URL("../app/globals.css", import.meta.url), "utf8"),
    readFile(new URL("../android/style.css", import.meta.url), "utf8"),
  ]);

  assert.match(css, /\.download-button:active\s*\{/);
  assert.match(css, /\.download-button:active::after\s*\{/);
  assert.match(css, /\.download-button:active \.button-symbol\s*\{/);
  assert.match(
    androidCss,
    /\.primary-button:active,\s*\.secondary-button:active\s*\{/,
  );
});

async function runLegacyDownloadScript(href) {
  const source = await readFile(
    new URL("../android/script.js", import.meta.url),
    "utf8",
  );
  const attributes = new Map([
    ["href", href],
    ["download", "Maintenance-Assistant-iPhone-Source-v1.0.0.zip"],
  ]);
  const listeners = new Map();
  const link = {
    dataset: { download: "iphone" },
    getAttribute(name) {
      return attributes.get(name) ?? null;
    },
    removeAttribute(name) {
      attributes.delete(name);
    },
    setAttribute(name, value) {
      attributes.set(name, value);
    },
    addEventListener(name, listener) {
      listeners.set(name, listener);
    },
  };
  const context = {
    URL,
    navigator: {},
    window: {
      location: { href: "https://example.com/android/" },
      clearTimeout() {},
      setTimeout() {},
    },
    document: {
      querySelector() {
        return null;
      },
      querySelectorAll(selector) {
        return selector === "[data-download]" ? [link] : [];
      },
    },
  };

  vm.runInNewContext(source, context);

  return { attributes, link, listener: listeners.get("click") };
}

test("legacy iPhone button blocks source archives before Safari can download them", async () => {
  const { attributes, link, listener } = await runLegacyDownloadScript(
    "../iphone/Maintenance-Assistant-iPhone-Source-v1.0.0.zip",
  );
  let prevented = false;

  listener({
    preventDefault() {
      prevented = true;
    },
  });

  assert.equal(attributes.has("download"), false);
  assert.equal(link.href, "#iphone-details");
  assert.equal(link.dataset.iosDistribution, "unavailable");
  assert.equal(prevented, true);
});

test("legacy iPhone button allows only an official Apple install page", async () => {
  const testFlightUrl = "https://testflight.apple.com/join/AbC123xy";
  const { attributes, link, listener } =
    await runLegacyDownloadScript(testFlightUrl);
  let prevented = false;

  listener({
    preventDefault() {
      prevented = true;
    },
  });

  assert.equal(attributes.has("download"), false);
  assert.equal(link.href, testFlightUrl);
  assert.equal(link.target, "_blank");
  assert.equal(link.rel, "noopener noreferrer");
  assert.equal(link.dataset.iosDistribution, "approved");
  assert.equal(prevented, false);
});
