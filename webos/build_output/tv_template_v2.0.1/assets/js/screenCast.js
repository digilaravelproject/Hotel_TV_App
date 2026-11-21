"use strict";
window.TVScreenCastController = {
  screenCastHtml: "",
  castDeviceName: "",
  async openScreenCast() {
    var _a, _b;
    try {
      await this.fetchCastDeviceInfo();
      if ((_a = window.flutterBridge) == null ? void 0 : _a.launchCast) {
        window.flutterBridge.launchCast().catch((e) => console.warn("[ScreenCast] Flutter launchCast notice:", e));
      } else if ((_b = window.FlutterBridge) == null ? void 0 : _b.postMessage) {
        try {
          window.FlutterBridge.postMessage(JSON.stringify({ method: "launchCast", args: [], id: Date.now() }));
        } catch (postErr) {
          console.warn("[ScreenCast] FlutterBridge postMessage error:", postErr);
        }
      }
    } catch (err) {
      console.error("[ScreenCast] Error in openScreenCast:", err);
    } finally {
      this.$nextTick(() => {
        var _a2;
        try {
          (_a2 = document.getElementById("tv-header-back-btn")) == null ? void 0 : _a2.focus();
        } catch (_) {
        }
      });
    }
  },
  async fetchCastDeviceInfo() {
    var _a, _b, _c, _d, _e, _f, _g, _h, _i, _j;
    try {
      const tvDisplayName = ((_b = (_a = this.hotelData) == null ? void 0 : _a.device) == null ? void 0 : _b.tv_display_name) || ((_d = (_c = this.hotelData) == null ? void 0 : _c.device) == null ? void 0 : _d.tvDisplayName) || ((_f = (_e = this.hotelData) == null ? void 0 : _e.device) == null ? void 0 : _f.tv_name);
      if (tvDisplayName) {
        this.castDeviceName = String(tvDisplayName).trim();
        return;
      }
      const room = this.roomNo || ((_h = (_g = this.hotelData) == null ? void 0 : _g.device) == null ? void 0 : _h.room_no);
      if (room) {
        this.castDeviceName = `Room ${room}`;
        return;
      }
      if ((_i = window.flutterBridge) == null ? void 0 : _i.identifyDevice) {
        try {
          let info = await window.flutterBridge.identifyDevice();
          if (typeof info === "string") {
            try {
              info = JSON.parse(info);
            } catch (_) {
            }
          }
          const data = info && (info.data || info.device || info) || {};
          const name = data.device_name || data.deviceName || data.name;
          if (name) {
            this.castDeviceName = String(name).trim();
            return;
          }
        } catch (bridgeErr) {
          console.warn("[ScreenCast] Bridge identifyDevice notice:", bridgeErr);
        }
      }
      const dev = ((_j = this.hotelData) == null ? void 0 : _j.device) || {};
      if (dev.brand && dev.model) {
        this.castDeviceName = `${dev.brand} ${dev.model}`.trim();
      } else {
        this.castDeviceName = "Hotel TV";
      }
    } catch (err) {
      console.error("[ScreenCast] Error in fetchCastDeviceInfo:", err);
      this.castDeviceName = this.roomNo ? `Room ${this.roomNo}` : "Hotel TV";
    }
  },
  getCastDeviceName() {
    var _a, _b, _c, _d, _e, _f, _g, _h;
    try {
      const tvDisplayName = ((_b = (_a = this.hotelData) == null ? void 0 : _a.device) == null ? void 0 : _b.tv_display_name) || ((_d = (_c = this.hotelData) == null ? void 0 : _c.device) == null ? void 0 : _d.tvDisplayName) || ((_f = (_e = this.hotelData) == null ? void 0 : _e.device) == null ? void 0 : _f.tv_name);
      if (tvDisplayName) return String(tvDisplayName).trim();
      if (this.castDeviceName) return this.castDeviceName;
      const room = this.roomNo || ((_h = (_g = this.hotelData) == null ? void 0 : _g.device) == null ? void 0 : _h.room_no);
      if (room) return `Room ${room}`;
      return "Hotel TV";
    } catch (err) {
      console.error("[ScreenCast] Error in getCastDeviceName:", err);
      return this.castDeviceName || (this.roomNo ? `Room ${this.roomNo}` : "Hotel TV");
    }
  }
};
