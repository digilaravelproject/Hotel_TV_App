"use strict";
const TVRemoteManager = {
  KEYMAP: {
    UP: [38, 19, 29460, 65362, 103],
    DOWN: [40, 20, 29461, 65364, 108],
    LEFT: [37, 21, 29462, 65361, 105],
    RIGHT: [39, 22, 29463, 65363, 106],
    ENTER: [13, 23, 66, 29443, 160, 108, 32],
    BACK: [8, 27, 4, 461, 10009, 10182, 220, 166, 65367],
    HOME: [36, 3, 172, 10071],
    MENU: [82, 18, 93, 448],
    EXIT: [10182, 27]
  },
  matches(e, action) {
    var _a;
    const code = e.keyCode || e.which;
    if ((_a = this.KEYMAP[action]) == null ? void 0 : _a.includes(code)) return true;
    const k = (e.key || "").toLowerCase();
    const c = (e.code || "").toLowerCase();
    switch (action) {
      case "UP":
        return k === "arrowup" || k === "up" || c === "arrowup";
      case "DOWN":
        return k === "arrowdown" || k === "down" || c === "arrowdown";
      case "LEFT":
        return k === "arrowleft" || k === "left" || c === "arrowleft";
      case "RIGHT":
        return k === "arrowright" || k === "right" || c === "arrowright";
      case "ENTER":
        return k === "enter" || k === "ok" || k === "select" || k === " " || c === "enter" || c === "space";
      case "BACK":
        return k === "backspace" || k === "escape" || k === "back" || k === "goback" || k === "browserback" || c === "escape" || c === "backspace";
      case "HOME":
        return k === "home" || k === "browserhome" || c === "home";
      case "EXIT":
        return k === "exit" || code === 10182;
      default:
        return false;
    }
  },
  getDigit(e) {
    const code = e.keyCode || e.which;
    if (e.key === "Tab" || e.key === "Backspace" || e.key === "Enter") return null;
    if (code >= 48 && code <= 57) return String(code - 48);
    if (code >= 96 && code <= 105) return String(code - 96);
    if (code >= 7 && code <= 16) return String(code - 7);
    return e.key && /^\d$/.test(e.key) ? e.key : null;
  },
  registerTizenPlatformKeys() {
    var _a, _b;
    try {
      if ((_b = (_a = window.tizen) == null ? void 0 : _a.tvinputdevice) == null ? void 0 : _b.registerKey) {
        ["Return", "Exit", "Menu", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"].forEach((k) => {
          try {
            window.tizen.tvinputdevice.registerKey(k);
          } catch (_) {
          }
        });
      }
    } catch (_) {
    }
  },
  lockCanvasGestures() {
    const block = (e) => {
      if (e.ctrlKey || e.metaKey) {
        const k = e.key;
        const c = e.code;
        if (k === "+" || k === "=" || k === "-" || k === "_" || k === "0" || c === "NumpadAdd" || c === "NumpadSubtract" || c === "Equal" || c === "Minus" || c === "Digit0") {
          e.preventDefault();
          e.stopPropagation();
        }
      }
    };
    window.addEventListener("keydown", block, { capture: true, passive: false });
    window.addEventListener("wheel", (e) => {
      if (e.ctrlKey || e.metaKey) {
        e.preventDefault();
        e.stopPropagation();
      }
    }, { capture: true, passive: false });
    document.addEventListener("gesturestart", (e) => e.preventDefault(), { passive: false });
    document.addEventListener("gesturechange", (e) => e.preventDefault(), { passive: false });
    document.addEventListener("gestureend", (e) => e.preventDefault(), { passive: false });
  },
  navigateSpatial(direction) {
    const selector = 'button, [tabindex="0"], a, input, select, textarea, .tv-focusable';
    const focusables = Array.from(document.querySelectorAll(selector)).filter((el) => {
      if (el.disabled || el.tabIndex === -1) return false;
      const s = window.getComputedStyle(el);
      if (s.display === "none" || s.visibility === "hidden" || s.opacity === "0") return false;
      const r = el.getBoundingClientRect();
      return r.width > 0 && r.height > 0;
    });
    if (!focusables.length) return;
    const active = document.activeElement;
    if (!active || active === document.body || !focusables.includes(active)) {
      focusables[0].focus();
      return;
    }
    const aR = active.getBoundingClientRect();
    const aC = { x: aR.left + aR.width / 2, y: aR.top + aR.height / 2 };
    let best = null, minDist = Infinity;
    for (const el of focusables) {
      if (el === active) continue;
      const r = el.getBoundingClientRect();
      const c = { x: r.left + r.width / 2, y: r.top + r.height / 2 };
      let valid = false, dS = 0, dO = 0;
      if (direction === "left" && c.x < aC.x) {
        valid = true;
        dS = aC.x - c.x;
        dO = Math.abs(aC.y - c.y);
      } else if (direction === "right" && c.x > aC.x) {
        valid = true;
        dS = c.x - aC.x;
        dO = Math.abs(aC.y - c.y);
      } else if (direction === "up" && c.y < aC.y) {
        valid = true;
        dS = aC.y - c.y;
        dO = Math.abs(aC.x - c.x);
      } else if (direction === "down" && c.y > aC.y) {
        valid = true;
        dS = c.y - aC.y;
        dO = Math.abs(aC.x - c.x);
      }
      if (valid) {
        const dist = dS + dO * 3;
        if (dist < minDist) {
          minDist = dist;
          best = el;
        }
      }
    }
    if (best) best.focus();
  }
};
window.TVRemoteManager = TVRemoteManager;
