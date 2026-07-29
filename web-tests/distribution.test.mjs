import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

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

test("the public page never links iPhone users to source archives or raw IPA files", async () => {
  const page = await readFile(
    new URL("../app/page.jsx", import.meta.url),
    "utf8",
  );

  assert.doesNotMatch(page, /Maintenance-Assistant-iPhone-Source/i);
  assert.doesNotMatch(page, /href\s*=\s*["'`][^"'`]*\.(?:zip|ipa|plist)/i);
  assert.doesNotMatch(page, /itms-services:/i);
});

test("download buttons keep immediate visual feedback on touch and click", async () => {
  const css = await readFile(
    new URL("../app/globals.css", import.meta.url),
    "utf8",
  );

  assert.match(css, /\.download-button:active\s*\{/);
  assert.match(css, /\.download-button:active::after\s*\{/);
  assert.match(css, /\.download-button:active \.button-symbol\s*\{/);
});
