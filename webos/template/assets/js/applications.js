"use strict";
window.TVAppsController = {
  // Applications & OTT Apps State
  activeOttList: [],
  activeAppFocusIndex: 0,
  lastAppCardIndex: 0,
  toastMessage: "",
  toastTimer: null,
  getActiveOttList() {
    var _a, _b;
    if (Array.isArray(this.activeOttList) && this.activeOttList.length > 0) return this.activeOttList;
    const inst = window.tvAppInstance;
    if (inst && Array.isArray(inst.activeOttList) && inst.activeOttList.length > 0) return inst.activeOttList;
    if (inst && Array.isArray((_a = inst.hotelData) == null ? void 0 : _a.active_ott) && inst.hotelData.active_ott.length > 0) return inst.hotelData.active_ott;
    if (Array.isArray((_b = this.hotelData) == null ? void 0 : _b.active_ott) && this.hotelData.active_ott.length > 0) return this.hotelData.active_ott;
    return [];
  },
  async syncInstalledApps() {
    var _a, _b, _c;
    if (!((_b = (_a = window.flutterBridge) == null ? void 0 : _a.isAvailable) == null ? void 0 : _b.call(_a))) {
      return;
    }
    try {
      if (typeof window.flutterBridge.getInstalledApps === "function") {
        const installed = await window.flutterBridge.getInstalledApps();
        if (Array.isArray(installed) && installed.length > 0) {
          const installedPkgSet = /* @__PURE__ */ new Set();
          installed.forEach((item) => {
            if (typeof item === "string") {
              installedPkgSet.add(item.toLowerCase().trim());
            } else if (item && typeof item === "object") {
              const pkg = item.package_name || item.packageName || item.package || item.id;
              if (pkg) installedPkgSet.add(String(pkg).toLowerCase().trim());
            }
          });
          const inst = window.tvAppInstance || this;
          const baseList = Array.isArray((_c = inst.hotelData) == null ? void 0 : _c.active_ott) && inst.hotelData.active_ott.length > 0 ? inst.hotelData.active_ott : Array.isArray(this.activeOttList) ? this.activeOttList : [];
          const filtered = baseList.filter((app) => {
            const appPkg = (app.package_name || app.id || "").toLowerCase().trim();
            return installedPkgSet.has(appPkg);
          });
          if (filtered.length > 0) {
            this.activeOttList = filtered;
            if (window.tvAppInstance) {
              window.tvAppInstance.activeOttList = filtered;
            }
            console.log(`[TVApps] Synced with TV: ${filtered.length} of ${baseList.length} configured apps are installed`);
          }
        }
      }
    } catch (e) {
      console.warn("[TVApps] Error querying installed apps from bridge:", e);
    }
  },
  getAppIcon(app) {
    if (!app) return "";
    if (app.icon) return app.icon;
    const id = (app.id || "").toLowerCase();
    if (id.includes("netflix")) return "assets/images/apps/ic_netflix.png";
    if (id.includes("youtube")) return "assets/images/apps/ic_youtube.png";
    if (id.includes("hotstar")) return "assets/images/apps/ic_hotstar.png";
    if (id.includes("prime")) return "assets/images/apps/ic_primevideo.png";
    if (id.includes("zee5") || id.includes("zee")) return "assets/images/apps/ic_zee5.png";
    if (id.includes("playstore") || id.includes("cast")) return "assets/images/apps/ic_googlecast.png";
    return "";
  },
  getAppInitials(name) {
    if (!name) return "APP";
    const words = name.trim().split(/\s+/);
    if (words.length === 1) return words[0].substring(0, 3).toUpperCase();
    return words.slice(0, 2).map((w) => w[0]).join("").toUpperCase();
  },
  getAppBoxClass(app, isActive) {
    const id = (app.id || "").toLowerCase();
    let base = "bg-white/[0.06] border border-white/10 text-white";
    if (id.includes("playstore") || id.includes("vending")) {
      base = "bg-white border border-white/40 text-slate-900";
    } else if (id.includes("netflix")) {
      base = "bg-[#0f0000] border border-[#E50914]/40 text-[#E50914]";
    } else if (id.includes("hotstar")) {
      base = "bg-[#050b18] border border-[#1f80e0]/40 text-[#1f80e0]";
    } else if (id.includes("prime")) {
      base = "bg-[#00050d] border border-[#00a8e1]/40 text-[#00a8e1]";
    } else if (id.includes("zee5") || id.includes("zee")) {
      base = "bg-[#10031c] border border-[#8230c6]/40 text-[#a855f7]";
    } else if (id.includes("youtube")) {
      base = "bg-[#140000] border border-[#ff0000]/40 text-[#ff0000]";
    } else if (id.includes("sony")) {
      base = "bg-gradient-to-br from-[#003882] to-[#001433] border border-blue-400/40 text-white";
    } else if (id.includes("jio")) {
      base = "bg-gradient-to-br from-[#9c065f] to-[#3b0022] border border-pink-400/40 text-white";
    } else if (id.includes("aha")) {
      base = "bg-gradient-to-br from-[#ff3e00] to-[#7a1c00] border border-orange-400/40 text-white";
    } else if (id.includes("sun")) {
      base = "bg-gradient-to-br from-[#d32f2f] to-[#500000] border border-red-400/40 text-amber-300";
    } else if (id.includes("mx")) {
      base = "bg-gradient-to-br from-[#0052cc] to-[#071d49] border border-blue-400/40 text-white";
    } else if (id.includes("discovery")) {
      base = "bg-gradient-to-br from-[#00695c] to-[#002017] border border-emerald-400/40 text-emerald-300";
    } else if (id.includes("alt")) {
      base = "bg-gradient-to-br from-[#b71c1c] to-[#3a0000] border border-rose-400/40 text-white";
    } else if (id.includes("eros")) {
      base = "bg-gradient-to-br from-[#7b1fa2] to-[#250634] border border-fuchsia-400/40 text-white";
    } else if (id.includes("hungama")) {
      base = "bg-gradient-to-br from-[#e65100] to-[#451800] border border-orange-400/40 text-amber-300";
    } else if (id.includes("hoichoi")) {
      base = "bg-gradient-to-br from-[#c62828] to-[#400000] border border-red-400/40 text-white";
    } else if (id.includes("planet")) {
      base = "bg-gradient-to-br from-[#e65100] to-[#381200] border border-yellow-400/40 text-white";
    } else if (id.includes("chaupal")) {
      base = "bg-gradient-to-br from-[#d84315] to-[#450f00] border border-amber-400/40 text-white";
    } else if (id.includes("manorama")) {
      base = "bg-gradient-to-br from-[#1565c0] to-[#001c60] border border-blue-400/40 text-white";
    } else if (id.includes("voot")) {
      base = "bg-gradient-to-br from-[#4a148c] to-[#100050] border border-purple-400/40 text-white";
    }
    if (isActive) {
      return `${base} ring-2 ring-amber-400 shadow-[0_0_25px_rgba(255,215,0,0.6)]`;
    }
    return `${base} shadow-md`;
  },
  launchApp(app) {
    var _a, _b, _c;
    if (!app) return;
    const pkgName = app.package_name || app.id;
    console.log("[TV] Launching OTT App:", app.name, pkgName);
    if ((_a = window.flutterBridge) == null ? void 0 : _a.launchApp) {
      window.flutterBridge.launchApp(pkgName).catch((e) => console.warn("[TV] Flutter launchApp warning:", e));
    } else if ((_b = window.FlutterBridge) == null ? void 0 : _b.postMessage) {
      window.FlutterBridge.postMessage(JSON.stringify({ method: "launchApp", args: [pkgName], id: Date.now() }));
    } else if ((_c = window.AndroidBridge) == null ? void 0 : _c.launchApp) {
      window.AndroidBridge.launchApp(pkgName);
    }
    this.showToast(`Launching ${app.name}...`);
  },
  showToast(msg) {
    this.toastMessage = msg;
    if (this.toastTimer) clearTimeout(this.toastTimer);
    this.toastTimer = setTimeout(() => {
      this.toastMessage = "";
    }, 2500);
  },
  focusCurrentApp() {
    this.$nextTick(() => {
      if (typeof this.activeAppFocusIndex === "number") {
        const el = document.getElementById(`app_card_${this.activeAppFocusIndex}`);
        if (el) {
          el.focus();
          el.scrollIntoView({ behavior: "smooth", block: "nearest", inline: "nearest" });
        }
      }
    });
  },
  handleApplicationsGridNavigation(e) {
    var _a, _b, _c;
    const list = this.getActiveOttList();
    const total = list.length;
    const cols = 5;
    if (TVRemoteManager.matches(e, "LEFT")) {
      e.preventDefault();
      if (typeof this.activeAppFocusIndex === "number") {
        if (this.activeAppFocusIndex % cols > 0) {
          this.activeAppFocusIndex -= 1;
          this.focusCurrentApp();
        }
      }
      return true;
    }
    if (TVRemoteManager.matches(e, "RIGHT")) {
      e.preventDefault();
      if (typeof this.activeAppFocusIndex === "number") {
        if (this.activeAppFocusIndex % cols < cols - 1 && this.activeAppFocusIndex + 1 < total) {
          this.activeAppFocusIndex += 1;
          this.focusCurrentApp();
        }
      }
      return true;
    }
    if (TVRemoteManager.matches(e, "UP")) {
      e.preventDefault();
      if (typeof this.activeAppFocusIndex === "number") {
        if (Math.floor(this.activeAppFocusIndex / cols) > 0) {
          this.activeAppFocusIndex -= cols;
          this.focusCurrentApp();
        } else {
          this.lastAppCardIndex = this.activeAppFocusIndex;
          this.activeAppFocusIndex = "header_back";
          this.$nextTick(() => {
            var _a2;
            (_a2 = document.getElementById("tv-header-back-btn")) == null ? void 0 : _a2.focus();
          });
        }
      }
      return true;
    }
    if (TVRemoteManager.matches(e, "DOWN")) {
      e.preventDefault();
      if (this.activeAppFocusIndex === "header_back" || document.activeElement === document.getElementById("tv-header-back-btn")) {
        (_a = document.getElementById("tv-header-back-btn")) == null ? void 0 : _a.blur();
        this.activeAppFocusIndex = typeof this.lastAppCardIndex === "number" ? this.lastAppCardIndex : 0;
        this.focusCurrentApp();
        return true;
      }
      if (typeof this.activeAppFocusIndex === "number") {
        if (this.activeAppFocusIndex + cols < total) {
          this.activeAppFocusIndex += cols;
          this.focusCurrentApp();
        }
      }
      return true;
    }
    if (TVRemoteManager.matches(e, "ENTER")) {
      e.preventDefault();
      if (this.activeAppFocusIndex === "header_back" || document.activeElement === document.getElementById("tv-header-back-btn")) {
        this.goBack();
      } else if (typeof this.activeAppFocusIndex === "number") {
        const selected = list[this.activeAppFocusIndex];
        if (selected) this.launchApp(selected);
      } else {
        (_c = (_b = document.activeElement) == null ? void 0 : _b.click) == null ? void 0 : _c.call(_b);
      }
      return true;
    }
    return false;
  }
};
