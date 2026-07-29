const APP_STORE_HOST = "apps.apple.com";
const TESTFLIGHT_HOST = "testflight.apple.com";

function hasSafeUrlShape(url) {
  return (
    url.protocol === "https:" &&
    url.username === "" &&
    url.password === "" &&
    url.port === ""
  );
}

function isAppStoreInstallPath(url) {
  return /\/app\/(?:[^/]+\/)?id\d+\/?$/i.test(url.pathname);
}

function isTestFlightInstallPath(url) {
  return /^\/join\/[a-z0-9]+\/?$/i.test(url.pathname);
}

export function approvedIosInstallUrl(value) {
  if (typeof value !== "string" || value.trim() === "") {
    return null;
  }

  try {
    const url = new URL(value.trim());
    const host = url.hostname.toLowerCase();

    if (!hasSafeUrlShape(url)) {
      return null;
    }

    if (host === APP_STORE_HOST && isAppStoreInstallPath(url)) {
      return url.toString();
    }

    if (host === TESTFLIGHT_HOST && isTestFlightInstallPath(url)) {
      return url.toString();
    }
  } catch {
    return null;
  }

  return null;
}

export function iosDistributionName(url) {
  return url?.startsWith(`https://${TESTFLIGHT_HOST}/`)
    ? "TestFlight"
    : "App Store";
}
