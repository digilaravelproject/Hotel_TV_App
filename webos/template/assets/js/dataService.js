"use strict";
const TVDataService = {
  async loadConfig(forceApi = false) {
    var _a, _b, _c, _d;
    let config = null;
    let token = localStorage.getItem("authToken");
    if (((_a = window.tvLoginData) == null ? void 0 : _a.data) || window.tvLoginData) {
      config = window.tvLoginData.data || window.tvLoginData;
    } else if ((_b = window.parent) == null ? void 0 : _b.tvLoginData) {
      config = window.parent.tvLoginData.data || window.parent.tvLoginData;
    }
    if (!config) {
      try {
        const res = await fetch(`data.json?t=${Date.now()}`);
        if (res.ok) {
          const raw = await res.json();
          config = raw.data || raw;
          if ((_c = config.auth) == null ? void 0 : _c.token) {
            token = config.auth.token;
            localStorage.setItem("authToken", token);
          }
        }
      } catch (e) {
        console.warn("[DataService] Local data fetch notice:", e);
      }
    }
    if ((forceApi || !config) && navigator.onLine && token) {
      try {
        const apiRes = await fetch("https://tvapp.digiemperor.com/api/tv/template/check-version", {
          method: "GET",
          headers: { "Accept": "application/json", "Authorization": `Bearer ${token}` }
        });
        if (apiRes.ok) {
          const apiData = await apiRes.json();
          const fresh = apiData.data || apiData;
          if ((fresh == null ? void 0 : fresh.hotel) || (fresh == null ? void 0 : fresh.device)) {
            config = fresh;
            if (!config.auth) config.auth = { token };
            const fullPayload = { status: true, message: "TV data updated.", data: config };
            if ((_d = window.flutterBridge) == null ? void 0 : _d.saveDeviceConfig) {
              window.flutterBridge.saveDeviceConfig(fullPayload).catch(() => {
              });
            }
          }
        }
      } catch (apiErr) {
        console.warn("[DataService] Remote API fallback:", apiErr);
      }
    }
    if (config) {
      localStorage.setItem("cachedHotelData", JSON.stringify(config));
    } else {
      try {
        const cached = localStorage.getItem("cachedHotelData");
        if (cached) config = JSON.parse(cached);
      } catch (_) {
      }
    }
    return config;
  }
};
window.TVDataService = TVDataService;
