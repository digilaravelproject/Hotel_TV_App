"use strict";
function tvApp() {
  return {
    // --- REACTIVE STATE ---
    isLoaded: false,
    currentView: "home",
    isMenuFlipping: false,
    viewHistory: [],
    menuStack: [],
    // Ingested Component Templates
    headerHtml: "",
    greetingHtml: "",
    menuSliderHtml: "",
    infoPanelHtml: "",
    languagesHtml: "",
    applicationsHtml: "",
    screenCastHtml: "",
    weatherHtml: "",
    inputHtml: "",
    settingsHtml: "",
    flightsHtml: "",
    // 100% Offline Multilingual Engine
    currentLangTranslations: {},
    isRTL: false,
    selectedLangFile: localStorage.getItem("selectedLangFile") || "english.json",
    activeLangFocusIndex: 0,
    justSelectedLang: false,
    availableLanguages: window.AVAILABLE_LANGUAGES || [],
    // Shared Info Panel State
    infoSlideIndex: 0,
    infoSlideTimer: null,
    // Applications & OTT Apps Controller Module
    ...window.TVAppsController || {},
    // Screen Cast Controller Module
    ...window.TVScreenCastController || {},
    // Weather Controller Module
    ...window.TVWeatherController || {},
    // Input / HDMI Ports Controller Module
    ...window.TVInputController || {},
    // Settings / Admin Controller Module
    ...window.TVSettingsController || {},
    // Flights Controller Module
    ...window.TVFlightsController || {},
    // Hotel & Slideshow State
    hotelData: {},
    sliderImages: [],
    activeSlideIndex: 0,
    slideIntervalMs: 7e3,
    timerId: null,
    // Header & Live Status
    timeStr: "",
    dateStr: "",
    roomNo: "",
    hotelLogo: "",
    weatherStr: "",
    toastMessage: "",
    toastTimer: null,
    greetingStr: "Good Afternoon, Guest",
    // Adaptive Menu Carousel
    activeMenuIndex: 0,
    currentMenuTitle: "Main Menu",
    menuItems: [],
    currentMenuList: [],
    // D-Pad Throttling & Debounce
    lastNavTime: 0,
    lastActionTime: 0,
    navThrottleMs: 140,
    actionThrottleMs: 220,
    // --- LIFECYCLE INITIALIZER ---
    async init() {
      var _a, _b, _c;
      try {
        window.tvAppInstance = this;
        try {
          await this.loadLanguage(this.selectedLangFile);
        } catch (langErr) {
          console.warn("[TVApp] Error during initial loadLanguage:", langErr);
        }
        try {
          this.initMenuData();
        } catch (menuErr) {
          console.warn("[TVApp] Error during initMenuData:", menuErr);
        }
        try {
          TVRemoteManager.lockCanvasGestures();
          TVRemoteManager.registerTizenPlatformKeys();
        } catch (remoteErr) {
          console.warn("[TVApp] Error registering remote manager keys:", remoteErr);
        }
        this.updateClock();
        this.updateGreeting();
        this.updateWeatherStr();
        try {
          if (typeof this.initWeatherBackgroundSync === "function") {
            this.initWeatherBackgroundSync();
          }
        } catch (wErr) {
          console.warn("[TVApp] initWeatherBackgroundSync error:", wErr);
        }
        try {
          if (typeof this.initFlightsBackgroundSync === "function") {
            this.initFlightsBackgroundSync();
          }
        } catch (fErr) {
          console.warn("[TVApp] initFlightsBackgroundSync error:", fErr);
        }
        setInterval(() => {
          try {
            this.updateClock();
            this.updateGreeting();
          } catch (_) {
          }
        }, 1e3);
        try {
          const config = await TVDataService.loadConfig();
          if (config) this.applyHotelConfig(config);
        } catch (cfgErr) {
          console.warn("[TVApp] Failed loading hotel configuration:", cfgErr);
        }
        try {
          if (typeof this.syncInstalledApps === "function") {
            await this.syncInstalledApps();
          }
        } catch (syncErr) {
          console.warn("[TVApp] Failed syncing installed apps:", syncErr);
        }
        if (((_b = (_a = window.flutterBridge) == null ? void 0 : _a.isAvailable) == null ? void 0 : _b.call(_a)) && ((_c = window.flutterBridge) == null ? void 0 : _c.getSelectedLiveTvPort)) {
          try {
            const saved = await window.flutterBridge.getSelectedLiveTvPort();
            if (saved && (saved.selectedPort || saved.port)) {
              const nativePort = saved.selectedPort || saved.port;
              this.liveTvSelectedPort = nativePort;
              localStorage.setItem("last_tv_input_port", nativePort);
            }
          } catch (_) {
          }
        }
        this.startSlider();
      } catch (err) {
        console.error("[TVApp] Fatal error in init():", err);
      } finally {
        const nextTick = typeof this.$nextTick === "function" ? this.$nextTick.bind(this) : (fn) => setTimeout(fn, 0);
        nextTick(() => setTimeout(() => {
          this.isLoaded = true;
        }, 100));
      }
    },
    async loadComponent(name, setter) {
      try {
        const res = await fetch(`components/${name}.html?t=${Date.now()}`);
        if (res.ok) setter(await res.text());
      } catch (e) {
        console.warn(`[Component] Failed loading components/${name}.html:`, e);
      }
    },
    // --- CONFIG & BRANDING ---
    applyHotelConfig(config) {
      var _a, _b, _c, _d, _e;
      try {
        if (!config || typeof config !== "object") return;
        this.hotelData = config;
        if (Array.isArray(config.menus) && config.menus.length > 0) {
          this.initMenuData(config.menus);
        }
        if ((_a = config.device) == null ? void 0 : _a.room_no) this.roomNo = config.device.room_no;
        if ((_c = (_b = config.hotel) == null ? void 0 : _b.media) == null ? void 0 : _c.logo_image) this.hotelLogo = config.hotel.media.logo_image;
        if (Array.isArray(config.active_ott) && config.active_ott.length > 0) {
          this.activeOttList = config.active_ott;
        }
        const hotelMedia = ((_d = config.hotel) == null ? void 0 : _d.media) || {};
        if (Array.isArray(hotelMedia.slider_images) && hotelMedia.slider_images.length > 0) {
          this.sliderImages = hotelMedia.slider_images;
          this.activeSlideIndex = 0;
          this.sliderImages.forEach((src) => {
            try {
              if (src) {
                const img = new Image();
                img.decoding = "async";
                img.src = src;
              }
            } catch (_) {
            }
          });
          this.startSlider();
        } else if (hotelMedia.cover_image) {
          this.sliderImages = [hotelMedia.cover_image];
          this.activeSlideIndex = 0;
        }
        this.updateGreeting();
        this.updateWeatherStr();
        if (typeof this.initWeatherBackgroundSync === "function") {
          this.initWeatherBackgroundSync();
        }
        if (typeof this.initFlightsBackgroundSync === "function") {
          this.initFlightsBackgroundSync();
        }
      } catch (e) {
        console.warn("[TVApp] applyHotelConfig error:", e);
      }
    },
    // --- 100% OFFLINE TRANSLATION ENGINE ---
    t(key, fallback = "") {
      try {
        if (!key || !this.currentLangTranslations) return fallback || key;
        let curr = this.currentLangTranslations;
        for (const p of key.split(".")) {
          if (curr && typeof curr === "object" && p in curr) curr = curr[p];
          else return fallback || key;
        }
        return typeof curr === "string" || typeof curr === "number" ? String(curr) : fallback || key;
      } catch (e) {
        return fallback || key;
      }
    },
    async loadLanguage(file) {
      var _a;
      try {
        const langFile = file || this.selectedLangFile || "english.json";
        const rtlFiles = window.RTL_LANG_FILES || ["arabic.json", "urdu.json", "hebrew.json"];
        this.isRTL = rtlFiles.includes(langFile);
        try {
          const res = await fetch(`languages/${langFile}?t=${Date.now()}`);
          if (res.ok) {
            this.currentLangTranslations = await res.json();
          } else {
            const fallbackRes = await fetch(`languages/english.json?t=${Date.now()}`);
            if (fallbackRes.ok) this.currentLangTranslations = await fallbackRes.json();
          }
        } catch (fetchErr) {
          console.warn("[LanguageEngine] Error fetching language:", langFile, fetchErr);
        }
        try {
          const html = document.documentElement;
          if (html) {
            html.setAttribute("dir", this.isRTL ? "rtl" : "ltr");
            html.setAttribute("lang", ((_a = this.currentLangTranslations) == null ? void 0 : _a.lang_code) || (this.isRTL ? "ar" : "en"));
          }
          if (document.body) {
            document.body.classList.toggle("rtl", this.isRTL);
            document.body.classList.toggle("ltr", !this.isRTL);
          }
        } catch (domErr) {
          console.warn("[LanguageEngine] DOM attribute error:", domErr);
        }
        this.updateClock();
        this.updateGreeting();
        this.updateWeatherStr();
      } catch (err) {
        console.warn("[LanguageEngine] Error in loadLanguage:", err);
      }
    },
    updateGreeting() {
      var _a;
      try {
        const h = (/* @__PURE__ */ new Date()).getHours();
        const timeKey = h >= 4 && h < 12 ? "morning" : h >= 12 && h < 17 ? "afternoon" : h >= 17 && h < 22 ? "evening" : "night";
        const defaultGreeting = h >= 4 && h < 12 ? "Good Morning" : h >= 12 && h < 17 ? "Good Afternoon" : h >= 17 && h < 22 ? "Good Evening" : "Good Night";
        const timeGreeting = this.t(`greetings.${timeKey}`, defaultGreeting);
        let guestName = "Guest";
        if ((_a = this.hotelData) == null ? void 0 : _a.guest_info) {
          guestName = typeof this.hotelData.guest_info === "string" ? this.hotelData.guest_info.trim() : this.hotelData.guest_info.name || this.hotelData.guest_info.guest_name || "Guest";
        }
        this.greetingStr = `${timeGreeting}, ${guestName}`;
      } catch (e) {
        this.greetingStr = "Welcome, Guest";
      }
    },
    updateClock() {
      try {
        const now = /* @__PURE__ */ new Date();
        let hours = now.getHours();
        const minutes = String(now.getMinutes()).padStart(2, "0");
        const ampm = hours >= 12 ? "PM" : "AM";
        hours = hours % 12 || 12;
        this.timeStr = `${String(hours).padStart(2, "0")}:${minutes} ${ampm}`;
        const dayKeys = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
        const monthKeys = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];
        const defaultDays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        const defaultMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        const dKey = dayKeys[now.getDay()];
        const mKey = monthKeys[now.getMonth()];
        const dayStr = this.t(`days_short.${dKey}`, this.t(`days.${dKey}`, defaultDays[now.getDay()]));
        const monthStr = this.t(`months.${mKey}`, defaultMonths[now.getMonth()]);
        this.dateStr = `${dayStr}, ${monthStr} ${now.getDate()}`;
      } catch (e) {
        console.warn("[TVApp] updateClock error:", e);
      }
    },
    updateWeatherStr() {
      try {
        if (typeof this.updateWeatherHeaderStr === "function") {
          this.updateWeatherHeaderStr();
        } else {
          this.weatherStr = "";
        }
      } catch (e) {
        this.weatherStr = "";
      }
    },
    showToast(msg) {
      try {
        this.toastMessage = msg;
        if (this.toastTimer) clearTimeout(this.toastTimer);
        this.toastTimer = setTimeout(() => {
          try {
            this.toastMessage = "";
          } catch (_) {
          }
        }, 3e3);
      } catch (e) {
        console.warn("[TVApp] showToast error:", e);
      }
    },
    // --- MENU CONTROLLER ---
    initMenuData(sourceMenus = null) {
      var _a;
      try {
        let raw = sourceMenus;
        if (!raw && Array.isArray((_a = this.hotelData) == null ? void 0 : _a.menus) && this.hotelData.menus.length > 0) {
          raw = this.hotelData.menus;
        }
        if (!raw) {
          try {
            const cached = localStorage.getItem("cachedHotelData");
            if (cached) {
              const parsed = JSON.parse(cached);
              if (Array.isArray(parsed == null ? void 0 : parsed.menus) && parsed.menus.length > 0) {
                raw = parsed.menus;
              }
            }
          } catch (_) {
          }
        }
        if (!raw && Array.isArray(window.MENU_DATA)) {
          raw = window.MENU_DATA;
        }
        raw = Array.isArray(raw) ? raw : [];
        this.menuItems = this.filterActiveMenus(raw);
        if (this.menuStack.length === 0) {
          this.currentMenuList = this.menuItems;
          this.currentMenuTitle = "Main Menu";
        }
        if (this.activeMenuIndex >= this.currentMenuList.length) {
          this.activeMenuIndex = Math.max(0, this.currentMenuList.length - 1);
        }
        this.preloadMenuIcons(this.menuItems);
      } catch (e) {
        console.warn("[TVApp] initMenuData error:", e);
      }
    },
    preloadMenuIcons(items) {
      try {
        if (!Array.isArray(items)) return;
        items.forEach((item) => {
          try {
            const src = this.getMenuIcon(item);
            if (src) {
              const img = new Image();
              img.src = src;
            }
            if (Array.isArray(item.sub_menus) && item.sub_menus.length > 0) {
              this.preloadMenuIcons(item.sub_menus);
            }
          } catch (_) {
          }
        });
        ["sunny.png", "cloudy.png", "rainy.png", "rainy-day.png", "rainy-night.png", "storm.png"].forEach((f) => {
          try {
            const wImg = new Image();
            wImg.src = `assets/images/weather/${f}`;
          } catch (_) {
          }
        });
      } catch (e) {
        console.warn("[TVApp] preloadMenuIcons error:", e);
      }
    },
    getMenuTitle(item) {
      try {
        if (!item) return "";
        const idKey = (item.id || "").toLowerCase().replace(/[\s-]+/g, "_");
        const nameKey = (item.name || "").toLowerCase().replace(/[\s-]+/g, "_");
        const key = idKey === "apps" ? "applications" : idKey === "livetv" ? "live_tv" : idKey === "ourcity" ? "our_city" : idKey;
        const trKey = this.t(`icons.${key}`, "");
        if (trKey && trKey !== `icons.${key}`) return trKey;
        const trName = this.t(`icons.${nameKey}`, "");
        if (trName && trName !== `icons.${nameKey}`) return trName;
        return item.name || "";
      } catch (e) {
        return (item == null ? void 0 : item.name) || "";
      }
    },
    filterActiveMenus(items) {
      try {
        if (!Array.isArray(items)) return [];
        return items.filter((item) => {
          var _a;
          if (!item) return false;
          const s = String((_a = item.status) != null ? _a : "show").trim().toLowerCase();
          return s !== "hide" && s !== "false" && s !== "0" && item.status !== false;
        }).map((item) => {
          const cloned = { ...item };
          if (Array.isArray(cloned.sub_menus) && cloned.sub_menus.length > 0) {
            cloned.sub_menus = this.filterActiveMenus(cloned.sub_menus);
          }
          return cloned;
        });
      } catch (e) {
        console.warn("[TVApp] filterActiveMenus error:", e);
        return Array.isArray(items) ? items : [];
      }
    },
    getMenuIcon(item) {
      try {
        if (!item) return "";
        let icon = (item.icon || "").replace(/\\/g, "/").trim();
        if (icon) {
          if (icon.startsWith("http") || icon.startsWith("assets/") || icon.includes("/")) return icon;
          return `assets/images/icons/${icon.replace(/\.png$/i, "")}.png`;
        }
        if (item.id) {
          const idKey = (item.id || "").toLowerCase().replace(/[\s-]+/g, "_");
          const map = {
            hotel_menu: "hotelinfo",
            hotel_info: "hotelinfo",
            room_info: "amenities",
            amenities: "roomservice",
            interactive_services: "roomservice",
            apps: "apps",
            applications: "apps",
            language: "languages",
            languages: "languages",
            livetv: "livetv",
            live_tv: "livetv",
            flights: "flights",
            flight: "flights",
            weather: "weather",
            input: "input",
            inputs: "input",
            hdmi: "input",
            settings: "settings",
            admin: "settings",
            ourcity: "ourcity",
            our_city: "ourcity",
            screen_cast: "cast",
            cast: "cast"
          };
          const iconFile = map[idKey] || idKey;
          return `assets/images/icons/${iconFile}.png`;
        }
        return "";
      } catch (e) {
        return "";
      }
    },
    // --- ADAPTIVE TV CAROUSEL MATH ---
    getVisibleSlots() {
      try {
        const list = this.currentMenuList;
        if (!list || list.length === 0) return [];
        const len = list.length;
        let offsets = [];
        if (len === 1) offsets = [0];
        else if (len === 2) offsets = [0, 1];
        else if (len === 3) offsets = [-1, 0, 1];
        else if (len <= 5) offsets = [-2, -1, 0, 1, 2];
        else offsets = [-3, -2, -1, 0, 1, 2, 3];
        return offsets.map((offset, slotIdx) => {
          const normIndex = ((this.activeMenuIndex + offset) % len + len) % len;
          const item = list[normIndex];
          const dist = Math.abs(offset);
          const isCenter = offset === 0;
          let scaleClass = "scale-90 opacity-45 hover:opacity-75 z-0";
          if (isCenter) scaleClass = "scale-110 opacity-100 z-20";
          else if (dist === 1) scaleClass = "scale-100 opacity-80 hover:opacity-100 z-10";
          else if (dist === 2) scaleClass = "scale-95 opacity-65 hover:opacity-90 z-5";
          return {
            slotIdx,
            offset,
            dist,
            isCenter,
            index: normIndex,
            item,
            uniqueKey: `d${this.menuStack.length}-s${slotIdx}-off${offset}-id${(item == null ? void 0 : item.id) || normIndex}`,
            scaleClass,
            imgClass: isCenter ? "w-56 h-56 border-4 border-amber-400 shadow-[0_0_35px_rgba(255,215,0,0.9),0_0_15px_rgba(179,138,45,0.7)]" : "w-48 h-48 border-0",
            textClass: isCenter ? "text-2xl font-black text-amber-400 drop-shadow-[0_0_14px_rgba(255,215,0,0.9)]" : "text-xl font-bold text-slate-200 drop-shadow-[0_2px_8px_rgba(0,0,0,0.9)]"
          };
        });
      } catch (e) {
        console.warn("[TVApp] getVisibleSlots error:", e);
        return [];
      }
    },
    slideMenu(dir) {
      try {
        const len = this.currentMenuList.length;
        if (len > 0) this.activeMenuIndex = ((this.activeMenuIndex + dir) % len + len) % len;
      } catch (e) {
        console.warn("[TVApp] slideMenu error:", e);
      }
    },
    onSlotClick(slot) {
      try {
        if (!slot) return;
        if (slot.isCenter) this.selectMenuItem(slot.item);
        else this.slideMenu(slot.offset);
      } catch (e) {
        console.warn("[TVApp] onSlotClick error:", e);
      }
    },
    selectMenuItem(item) {
      try {
        if (!item) return;
        if (Array.isArray(item.sub_menus) && item.sub_menus.length > 0) {
          this.isMenuFlipping = true;
          setTimeout(() => {
            try {
              this.menuStack.push({ list: this.currentMenuList, index: this.activeMenuIndex, title: this.currentMenuTitle });
              this.currentMenuList = item.sub_menus;
              this.activeMenuIndex = 0;
              this.currentMenuTitle = item.name;
              setTimeout(() => {
                this.isMenuFlipping = false;
              }, 150);
            } catch (_) {
              this.isMenuFlipping = false;
            }
          }, 200);
          return;
        }
        if (["weather", "flights", "flight"].includes(item.id) && !navigator.onLine) {
          this.showToast("No Internet Connection. Please connect to internet.");
          return;
        }
        if (["livetv", "live_tv"].includes(item.id)) {
          this.launchDefaultLiveTv();
          return;
        }
        this.navigate(item.id);
      } catch (e) {
        console.warn("[TVApp] selectMenuItem error:", e);
      }
    },
    async launchDefaultLiveTv() {
      var _a, _b, _c, _d, _e, _f, _g, _h, _i, _j, _k, _l, _m;
      try {
        const defaultPort = localStorage.getItem("last_tv_input_port") || this.liveTvSelectedPort || "HDMI 1";
        console.log("[TVApp] Launching Live TV with default target:", defaultPort);
        const isBridge = Boolean((_b = (_a = window.flutterBridge) == null ? void 0 : _a.isAvailable) == null ? void 0 : _b.call(_a));
        const isApp = defaultPort.startsWith("APP:") || /^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+$/.test(defaultPort) || !defaultPort.toUpperCase().startsWith("HDMI") && defaultPort.toUpperCase() !== "IPTV";
        if (isApp) {
          const pkg = defaultPort.replace(/^APP:/i, "").trim();
          let appName = "Application";
          const found = (this.availableOttApps || []).find((a) => (a.package_name || a.id) === pkg) || (this.installedApps || []).find((a) => (a.package_name || a.id) === pkg) || (((_c = this.hotelData) == null ? void 0 : _c.active_ott) || []).find((a) => (a.package_name || a.id) === pkg);
          if (found && found.name) {
            appName = found.name;
          }
          this.showToast(`Launching ${appName}...`);
          if (isBridge && ((_d = window.flutterBridge) == null ? void 0 : _d.launchApp)) {
            try {
              await window.flutterBridge.launchApp(pkg);
            } catch (e) {
              console.warn("[TVApp] launchApp warning:", e);
            }
          } else if ((_e = window.FlutterBridge) == null ? void 0 : _e.postMessage) {
            window.FlutterBridge.postMessage(JSON.stringify({ method: "launchApp", args: [pkg], id: Date.now() }));
          } else if ((_f = window.AndroidBridge) == null ? void 0 : _f.launchApp) {
            window.AndroidBridge.launchApp(pkg);
          } else {
            console.log(`[TVApp] Browser preview: Launched App (${appName} - ${pkg})`);
          }
        } else if (defaultPort === "IPTV") {
          this.showToast("Launching IPTV Channels...");
          if (isBridge && ((_g = window.flutterBridge) == null ? void 0 : _g.launchIptv)) {
            try {
              await window.flutterBridge.launchIptv("iptv", "iptv/all.json");
            } catch (e) {
              console.warn("[TVApp] launchIptv warning:", e);
            }
          } else if (isBridge && ((_h = window.flutterBridge) == null ? void 0 : _h.launchLiveTv)) {
            try {
              await window.flutterBridge.launchLiveTv("IPTV");
            } catch (e) {
              console.warn("[TVApp] launchLiveTv IPTV warning:", e);
            }
          } else if ((_i = window.FlutterBridge) == null ? void 0 : _i.postMessage) {
            window.FlutterBridge.postMessage(JSON.stringify({ method: "launchIptv", args: ["iptv", "iptv/all.json"], id: Date.now() }));
          } else {
            console.log("[TVApp] Browser preview: Launched IPTV Stream");
          }
        } else {
          this.showToast(`Switching to ${defaultPort}...`);
          if (isBridge && ((_j = window.flutterBridge) == null ? void 0 : _j.launchHdmi)) {
            try {
              await window.flutterBridge.launchHdmi(defaultPort);
            } catch (_) {
              if ((_k = window.flutterBridge) == null ? void 0 : _k.launchLiveTv) {
                try {
                  await window.flutterBridge.launchLiveTv(defaultPort);
                } catch (e) {
                  console.warn("[TVApp] launchLiveTv warning:", e);
                }
              }
            }
          } else if (isBridge && ((_l = window.flutterBridge) == null ? void 0 : _l.launchLiveTv)) {
            try {
              await window.flutterBridge.launchLiveTv(defaultPort);
            } catch (e) {
              console.warn("[TVApp] launchLiveTv warning:", e);
            }
          } else if ((_m = window.FlutterBridge) == null ? void 0 : _m.postMessage) {
            window.FlutterBridge.postMessage(JSON.stringify({ method: "launchHdmi", args: [defaultPort], id: Date.now() }));
          } else {
            console.log(`[TVApp] Browser preview: Switched to ${defaultPort}`);
          }
        }
      } catch (err) {
        console.warn("[TVApp] launchDefaultLiveTv error:", err);
      }
    },
    navigate(viewId) {
      try {
        if (["weather", "flights", "flight"].includes(viewId) && !navigator.onLine) {
          this.showToast("No Internet Connection. Please connect to internet.");
          return;
        }
        if (["livetv", "live_tv"].includes(viewId)) {
          this.launchDefaultLiveTv();
          return;
        }
        const targetView = viewId === "ourcity" ? "our_city" : viewId;
        if (this.currentView !== targetView) {
          this.viewHistory.push(this.currentView);
          this.currentView = targetView;
          if (["hotel_info", "room_info", "amenities", "our_city"].includes(targetView)) {
            this.infoSlideIndex = 0;
            this.resetInfoScroll();
            this.startInfoAutoSlide();
          } else if (["language", "languages"].includes(targetView)) {
            const foundIdx = this.availableLanguages.findIndex((l) => l.file === this.selectedLangFile);
            this.activeLangFocusIndex = foundIdx >= 0 ? foundIdx : 0;
            this.focusCurrentLanguage();
          } else if (["apps", "applications"].includes(viewId)) {
            this.activeAppFocusIndex = 0;
            this.focusCurrentApp();
          } else if (["screen_cast", "cast"].includes(viewId)) {
            this.openScreenCast();
          } else if (viewId === "weather") {
            this.openWeather();
          } else if (["input", "inputs", "hdmi"].includes(viewId)) {
            this.openInputSources();
          } else if (["settings", "admin"].includes(viewId)) {
            this.openSettingsAuth();
          } else if (["flights", "flight"].includes(viewId)) {
            this.openFlights();
          }
        }
      } catch (e) {
        console.warn("[TVApp] navigate error:", e);
      }
    },
    // --- LANGUAGES MODAL CONTROLLER ---
    selectLanguage(file, idx) {
      try {
        this.selectedLangFile = file;
        this.justSelectedLang = true;
        if (typeof idx === "number") {
          this.activeLangFocusIndex = idx;
          this.focusCurrentLanguage();
        }
      } catch (e) {
        console.warn("[TVApp] selectLanguage error:", e);
      }
    },
    async applyLanguage() {
      var _a, _b;
      try {
        localStorage.setItem("selectedLangFile", this.selectedLangFile);
        await this.loadLanguage(this.selectedLangFile);
        if ((_a = window.flutterBridge) == null ? void 0 : _a.setLanguage) window.flutterBridge.setLanguage(this.selectedLangFile).catch(() => {
        });
        if ((_b = window.AndroidBridge) == null ? void 0 : _b.setLanguage) window.AndroidBridge.setLanguage(this.selectedLangFile);
        this.goBack();
      } catch (e) {
        console.warn("[TVApp] applyLanguage error:", e);
      }
    },
    focusCurrentLanguage() {
      try {
        const nextTick = typeof this.$nextTick === "function" ? this.$nextTick.bind(this) : (fn) => setTimeout(fn, 0);
        nextTick(() => {
          var _a, _b;
          try {
            if (typeof this.activeLangFocusIndex === "number") {
              const el = document.getElementById(`lang_item_${this.activeLangFocusIndex}`);
              if (el) {
                el.focus();
                el.scrollIntoView({ behavior: "smooth", block: "nearest" });
              }
            } else if (this.activeLangFocusIndex === "apply") {
              (_a = document.getElementById("lang-btn-apply")) == null ? void 0 : _a.focus();
            } else if (this.activeLangFocusIndex === "cancel") {
              (_b = document.getElementById("lang-btn-cancel")) == null ? void 0 : _b.focus();
            }
          } catch (_) {
          }
        });
      } catch (e) {
        console.warn("[TVApp] focusCurrentLanguage error:", e);
      }
    },
    goBack() {
      var _a;
      try {
        this.stopInfoAutoSlide();
        if (["settings", "admin"].includes(this.currentView)) {
          this.settingsStep = "auth";
          this.settingsPin = "";
          this.maskedPin = ["\u2022", "\u2022", "\u2022", "\u2022", "\u2022", "\u2022"];
          this.authStatus = "idle";
          this.authMessage = "";
        }
        if ((_a = document.activeElement) == null ? void 0 : _a.blur) document.activeElement.blur();
        if (this.currentView !== "home") {
          this.currentView = this.viewHistory.pop() || "home";
          return;
        }
        if (this.menuStack.length > 0) {
          this.isMenuFlipping = true;
          setTimeout(() => {
            try {
              const prev = this.menuStack.pop();
              this.currentMenuList = prev.list;
              this.activeMenuIndex = prev.index;
              this.currentMenuTitle = prev.title;
              setTimeout(() => {
                this.isMenuFlipping = false;
              }, 150);
            } catch (_) {
              this.isMenuFlipping = false;
            }
          }, 200);
        }
      } catch (e) {
        console.warn("[TVApp] goBack error:", e);
      }
    },
    // --- HEADER NAVIGATION HANDLERS ---
    onHeaderBackFocus() {
      try {
        const view = this.currentView;
        if (["apps", "applications"].includes(view)) {
          this.activeAppFocusIndex = "header_back";
        } else if (["language", "languages"].includes(view)) {
          this.activeLangFocusIndex = "header_back";
        } else if (["input", "inputs", "hdmi"].includes(view)) {
          this.activeInputFocusIndex = "header_back";
        } else if (["settings", "admin"].includes(view)) {
          if (this.settingsStep === "auth") {
            this.activeKeypadIndex = "header_back";
          } else {
            this.dashboardFocus = "header_back";
          }
        } else if (["flights", "flight"].includes(view)) {
          this.flightFocusZone = "header_back";
        }
      } catch (e) {
        console.warn("[TVApp] onHeaderBackFocus error:", e);
      }
    },
    onHeaderBackDown(e) {
      var _a, _b, _c, _d, _e;
      try {
        if (e && typeof e.preventDefault === "function") e.preventDefault();
        const view = this.currentView;
        if (["apps", "applications"].includes(view)) {
          this.activeAppFocusIndex = 0;
          if (typeof this.focusCurrentApp === "function") this.focusCurrentApp();
        } else if (["language", "languages"].includes(view)) {
          this.activeLangFocusIndex = 0;
          if (typeof this.focusCurrentLanguage === "function") this.focusCurrentLanguage();
        } else if (["input", "inputs", "hdmi"].includes(view)) {
          if (typeof this.focusCurrentInputPort === "function") this.focusCurrentInputPort();
        } else if (["settings", "admin"].includes(view)) {
          if (this.settingsStep === "auth") {
            this.activeKeypadIndex = 0;
            if (typeof this.focusCurrentKeypadBtn === "function") this.focusCurrentKeypadBtn();
          } else {
            const selIdx = this.availableTvPorts && this.liveTvSelectedPort ? this.availableTvPorts.indexOf(this.liveTvSelectedPort) : 0;
            this.dashboardFocus = "port_" + (selIdx >= 0 ? selIdx : 0);
            if (typeof this.focusCurrentDashboardElement === "function") {
              this.focusCurrentDashboardElement();
            } else {
              (_a = document.getElementById(`settings_port_${selIdx >= 0 ? selIdx : 0}`)) == null ? void 0 : _a.focus();
            }
          }
        } else if (view === "weather") {
          (_b = document.getElementById("tv-weather-refresh-btn")) == null ? void 0 : _b.focus();
        } else if (["flights", "flight"].includes(view)) {
          (_c = document.getElementById("tv-header-back-btn")) == null ? void 0 : _c.blur();
          this.flightFocusZone = "header";
          this.flightFocusIndex = this.secondaryAirportData ? 2 : 0;
        } else if (["hotel_info", "room_info", "amenities", "our_city", "ourcity"].includes(view)) {
          (_d = document.getElementById("tv-header-back-btn")) == null ? void 0 : _d.blur();
          this.scrollInfoPanel(150);
        } else {
          if ((_e = document.activeElement) == null ? void 0 : _e.blur) document.activeElement.blur();
          TVRemoteManager.navigateSpatial("down");
        }
      } catch (err) {
        console.warn("[TVApp] onHeaderBackDown error:", err);
      }
    },
    // --- INFO PANEL CONTROLLER ---
    getInfoPanelTitle() {
      try {
        if (this.currentView === "hotel_info") return this.t("icons.hotel_info", "HOTEL INFORMATION").toUpperCase();
        if (this.currentView === "room_info") return this.t("icons.room_info", "ROOM INFORMATION").toUpperCase();
        if (this.currentView === "amenities") return this.t("icons.amenities", "AMENITIES").toUpperCase();
        if (["our_city", "ourcity"].includes(this.currentView)) return this.t("icons.our_city", "OUR CITY").toUpperCase();
        return this.t("hotel_info", "INFORMATION").toUpperCase();
      } catch (e) {
        return "INFORMATION";
      }
    },
    getInfoList() {
      var _a, _b, _c, _d, _e;
      try {
        if (this.currentView === "hotel_info") {
          const list = Array.isArray((_a = this.hotelData) == null ? void 0 : _a.hotel_info) ? this.hotelData.hotel_info : [];
          if (list.length > 0) {
            return list.map((item) => ({
              title: item.title || "",
              description: item.description || "",
              image: item.image_url || item.url || item.image || "",
              features: Array.isArray(item.features) ? item.features : []
            }));
          }
          const h = ((_b = this.hotelData) == null ? void 0 : _b.hotel) || {};
          const media = h.media || {};
          const images = Array.isArray(media.hotel_images) && media.hotel_images.length > 0 ? media.hotel_images : Array.isArray(media.slider_images) && media.slider_images.length > 0 ? media.slider_images : media.cover_image ? [media.cover_image] : [];
          return images.map(
            (img) => typeof img === "object" && img !== null ? { title: img.title || h.hotel_name || "", description: img.description || h.description || "", image: img.image_url || img.url || "", features: Array.isArray(img.features) ? img.features : [] } : { title: h.hotel_name || "", description: h.description || "", image: img || "", features: [] }
          );
        }
        if (this.currentView === "room_info") {
          const list = Array.isArray((_c = this.hotelData) == null ? void 0 : _c.room_info) ? this.hotelData.room_info : [];
          return list.map((item) => ({
            title: item.title || "",
            description: item.description || "",
            image: item.image_url || item.url || item.image || "",
            specifications: Array.isArray(item.specifications) ? item.specifications : []
          }));
        }
        if (this.currentView === "amenities") {
          const list = Array.isArray((_d = this.hotelData) == null ? void 0 : _d.amenities) ? this.hotelData.amenities : [];
          return list.map((item) => ({ title: item.title || "", description: item.description || "", image: item.image_url || item.url || item.image || "" }));
        }
        if (["our_city", "ourcity"].includes(this.currentView)) {
          const list = Array.isArray((_e = this.hotelData) == null ? void 0 : _e.our_city) ? this.hotelData.our_city : [];
          return list.map((item) => ({
            title: item.title || item.name || "",
            description: item.description || "",
            image: item.image_url || item.url || item.image || "",
            attractions: Array.isArray(item.attractions) ? item.attractions : Array.isArray(item.features) ? item.features : []
          }));
        }
        return [];
      } catch (e) {
        console.warn("[TVApp] getInfoList error:", e);
        return [];
      }
    },
    getInfoImages() {
      try {
        return this.getInfoList().map((item) => item.image);
      } catch (e) {
        return [];
      }
    },
    getCurrentInfoItem() {
      try {
        const list = this.getInfoList();
        if (!list || list.length === 0) return { title: "", description: "", features: [], specifications: [], attractions: [] };
        return list[Math.min(this.infoSlideIndex, list.length - 1)] || list[0];
      } catch (e) {
        return { title: "", description: "", features: [], specifications: [], attractions: [] };
      }
    },
    changeInfoSlide(dir) {
      try {
        const total = this.getInfoImages().length;
        if (total <= 1) return;
        this.infoSlideIndex = (this.infoSlideIndex + dir + total) % total;
        this.resetInfoScroll();
        this.startInfoAutoSlide();
      } catch (e) {
        console.warn("[TVApp] changeInfoSlide error:", e);
      }
    },
    resetInfoScroll() {
      try {
        const nextTick = typeof this.$nextTick === "function" ? this.$nextTick.bind(this) : (fn) => setTimeout(fn, 0);
        nextTick(() => {
          var _a;
          try {
            (_a = document.getElementById("info-description-scroll")) == null ? void 0 : _a.scrollTo({ top: 0, behavior: "smooth" });
          } catch (_) {
          }
        });
      } catch (e) {
        console.warn("[TVApp] resetInfoScroll error:", e);
      }
    },
    scrollInfoPanel(delta) {
      var _a;
      try {
        (_a = document.getElementById("info-description-scroll")) == null ? void 0 : _a.scrollBy({ top: delta, behavior: "smooth" });
      } catch (e) {
        console.warn("[TVApp] scrollInfoPanel error:", e);
      }
    },
    startInfoAutoSlide() {
      try {
        this.stopInfoAutoSlide();
        this.infoSlideTimer = setInterval(() => {
          try {
            const total = this.getInfoImages().length;
            if (total > 1) {
              this.infoSlideIndex = (this.infoSlideIndex + 1) % total;
              this.resetInfoScroll();
            }
          } catch (_) {
          }
        }, 6e3);
      } catch (e) {
        console.warn("[TVApp] startInfoAutoSlide error:", e);
      }
    },
    stopInfoAutoSlide() {
      try {
        if (this.infoSlideTimer) {
          clearInterval(this.infoSlideTimer);
          this.infoSlideTimer = null;
        }
      } catch (e) {
        console.warn("[TVApp] stopInfoAutoSlide error:", e);
      }
    },
    // --- 2D GRID NAVIGATION (LANGUAGES MODAL) ---
    handleLanguagesGridNavigation(e) {
      var _a, _b, _c, _d;
      try {
        const total = this.availableLanguages.length;
        const cols = 3;
        if (TVRemoteManager.matches(e, "LEFT")) {
          e.preventDefault();
          this.justSelectedLang = false;
          if (typeof this.activeLangFocusIndex === "number") {
            if (this.activeLangFocusIndex % cols > 0) {
              this.activeLangFocusIndex -= 1;
              this.focusCurrentLanguage();
            }
          } else if (this.activeLangFocusIndex === "cancel") {
            this.activeLangFocusIndex = "apply";
            this.focusCurrentLanguage();
          }
          return true;
        }
        if (TVRemoteManager.matches(e, "RIGHT")) {
          e.preventDefault();
          this.justSelectedLang = false;
          if (typeof this.activeLangFocusIndex === "number") {
            if (this.activeLangFocusIndex % cols < cols - 1 && this.activeLangFocusIndex + 1 < total) {
              this.activeLangFocusIndex += 1;
              this.focusCurrentLanguage();
            }
          } else if (this.activeLangFocusIndex === "apply") {
            this.activeLangFocusIndex = "cancel";
            this.focusCurrentLanguage();
          }
          return true;
        }
        if (TVRemoteManager.matches(e, "UP")) {
          e.preventDefault();
          this.justSelectedLang = false;
          if (typeof this.activeLangFocusIndex === "number") {
            if (Math.floor(this.activeLangFocusIndex / cols) > 0) {
              this.activeLangFocusIndex -= cols;
              this.focusCurrentLanguage();
            } else {
              (_a = document.getElementById("tv-header-back-btn")) == null ? void 0 : _a.focus();
            }
          } else if (this.activeLangFocusIndex === "apply" || this.activeLangFocusIndex === "cancel") {
            const selIdx = this.availableLanguages.findIndex((l) => l.file === this.selectedLangFile);
            this.activeLangFocusIndex = selIdx >= 0 ? selIdx : total - 1;
            this.focusCurrentLanguage();
          }
          return true;
        }
        if (TVRemoteManager.matches(e, "DOWN")) {
          e.preventDefault();
          if (document.activeElement === document.getElementById("tv-header-back-btn")) {
            (_b = document.getElementById("tv-header-back-btn")) == null ? void 0 : _b.blur();
            this.activeLangFocusIndex = 0;
            this.focusCurrentLanguage();
            return true;
          }
          if (this.justSelectedLang) {
            this.justSelectedLang = false;
            this.activeLangFocusIndex = "apply";
            this.focusCurrentLanguage();
            return true;
          }
          if (typeof this.activeLangFocusIndex === "number") {
            if (this.activeLangFocusIndex + cols < total) this.activeLangFocusIndex += cols;
            else this.activeLangFocusIndex = "apply";
            this.focusCurrentLanguage();
          }
          return true;
        }
        if (TVRemoteManager.matches(e, "ENTER")) {
          e.preventDefault();
          if (typeof this.activeLangFocusIndex === "number") {
            this.selectedLangFile = this.availableLanguages[this.activeLangFocusIndex].file;
            this.justSelectedLang = true;
          } else if (this.activeLangFocusIndex === "apply") {
            this.applyLanguage();
          } else if (this.activeLangFocusIndex === "cancel") {
            this.goBack();
          } else {
            (_d = (_c = document.activeElement) == null ? void 0 : _c.click) == null ? void 0 : _d.call(_c);
          }
          return true;
        }
        return false;
      } catch (err) {
        console.warn("[TVApp] handleLanguagesGridNavigation error:", err);
        return false;
      }
    },
    // --- GLOBAL REMOTE EVENT DISPATCHER ---
    handleGlobalKeys(e) {
      var _a;
      try {
        const now = Date.now();
        const isDirection = TVRemoteManager.matches(e, "LEFT") || TVRemoteManager.matches(e, "RIGHT") || TVRemoteManager.matches(e, "UP") || TVRemoteManager.matches(e, "DOWN");
        const isAction = TVRemoteManager.matches(e, "ENTER") || TVRemoteManager.matches(e, "BACK") || TVRemoteManager.matches(e, "HOME") || TVRemoteManager.matches(e, "EXIT");
        if (isDirection) {
          if (now - this.lastNavTime < this.navThrottleMs) {
            e.preventDefault();
            return;
          }
          this.lastNavTime = now;
        }
        if (isAction) {
          if (now - this.lastActionTime < this.actionThrottleMs) {
            e.preventDefault();
            return;
          }
          this.lastActionTime = now;
        }
        if (["settings", "admin"].includes(this.currentView)) {
          if (this.handleSettingsKeyNavigation(e)) return;
        }
        if (["language", "languages"].includes(this.currentView)) {
          if (this.handleLanguagesGridNavigation(e)) return;
        }
        if (["apps", "applications"].includes(this.currentView)) {
          if (this.handleApplicationsGridNavigation(e)) return;
        }
        if (["input", "inputs", "hdmi"].includes(this.currentView)) {
          if (this.handleInputGridNavigation(e)) return;
        }
        if (["flights", "flight"].includes(this.currentView)) {
          if (typeof this.handleFlightKeyNavigation === "function" && this.handleFlightKeyNavigation(e)) return;
        }
        if (TVRemoteManager.matches(e, "BACK")) {
          e.preventDefault();
          this.goBack();
          return;
        }
        if (TVRemoteManager.matches(e, "HOME")) {
          e.preventDefault();
          this.stopInfoAutoSlide();
          if ((_a = document.activeElement) == null ? void 0 : _a.blur) document.activeElement.blur();
          this.currentView = "home";
          this.menuStack = [];
          this.currentMenuList = this.menuItems;
          this.activeMenuIndex = 0;
          return;
        }
        if (TVRemoteManager.matches(e, "LEFT")) {
          e.preventDefault();
          if (this.currentView === "home") this.slideMenu(-1);
          else if (["hotel_info", "room_info", "amenities", "our_city", "ourcity"].includes(this.currentView)) this.changeInfoSlide(-1);
          else TVRemoteManager.navigateSpatial("left");
          return;
        }
        if (TVRemoteManager.matches(e, "RIGHT")) {
          e.preventDefault();
          if (this.currentView === "home") this.slideMenu(1);
          else if (["hotel_info", "room_info", "amenities", "our_city", "ourcity"].includes(this.currentView)) this.changeInfoSlide(1);
          else TVRemoteManager.navigateSpatial("right");
          return;
        }
        if (TVRemoteManager.matches(e, "UP")) {
          e.preventDefault();
          if (this.currentView === "home") {
            const cur = this.currentMenuList[this.activeMenuIndex];
            if (cur) this.selectMenuItem(cur);
          } else if (["hotel_info", "room_info", "amenities", "our_city", "ourcity"].includes(this.currentView)) {
            const el = document.getElementById("info-description-scroll");
            const backBtn = document.getElementById("tv-header-back-btn");
            if (el && el.scrollTop > 20) this.scrollInfoPanel(-150);
            else if (backBtn) backBtn.focus();
          } else {
            TVRemoteManager.navigateSpatial("up");
          }
          return;
        }
        if (TVRemoteManager.matches(e, "DOWN")) {
          e.preventDefault();
          if (this.currentView === "home") {
            if (this.menuStack.length > 0) this.goBack();
          } else if (["hotel_info", "room_info", "amenities", "our_city", "ourcity"].includes(this.currentView)) {
            const backBtn = document.getElementById("tv-header-back-btn");
            if (document.activeElement === backBtn) backBtn.blur();
            this.scrollInfoPanel(150);
          } else {
            TVRemoteManager.navigateSpatial("down");
          }
          return;
        }
        if (TVRemoteManager.matches(e, "ENTER")) {
          e.preventDefault();
          if (this.currentView === "home") {
            const cur = this.currentMenuList[this.activeMenuIndex];
            if (cur) this.selectMenuItem(cur);
          } else {
            const el = document.activeElement;
            if (el && el !== document.body && typeof el.click === "function") el.click();
          }
          return;
        }
        const digit = TVRemoteManager.getDigit(e);
        if (digit !== null && typeof window.onTVNumericInput === "function") window.onTVNumericInput(digit);
      } catch (err) {
        console.warn("[TVApp] handleGlobalKeys error:", err);
      }
    },
    // --- BACKGROUND SLIDESHOW ---
    startSlider() {
      try {
        if (this.timerId) clearInterval(this.timerId);
        if (this.sliderImages.length > 1) {
          this.timerId = setInterval(() => {
            try {
              this.activeSlideIndex = (this.activeSlideIndex + 1) % this.sliderImages.length;
            } catch (_) {
            }
          }, this.slideIntervalMs);
        }
      } catch (e) {
        console.warn("[TVApp] startSlider error:", e);
      }
    }
  };
}
window.triggerTVBack = () => {
  var _a, _b;
  try {
    (_b = (_a = window.tvAppInstance) == null ? void 0 : _a.goBack) == null ? void 0 : _b.call(_a);
  } catch (e) {
    console.warn("[Global] triggerTVBack error:", e);
  }
};
window.triggerTVHome = () => {
  try {
    if (window.tvAppInstance) {
      window.tvAppInstance.currentView = "home";
      window.tvAppInstance.menuStack = [];
      window.tvAppInstance.currentMenuList = window.tvAppInstance.menuItems;
      window.tvAppInstance.activeMenuIndex = 0;
    }
  } catch (e) {
    console.warn("[Global] triggerTVHome error:", e);
  }
};
