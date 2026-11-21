"use strict";
window.TVInputController = {
  inputHtml: "",
  inputPorts: [],
  activeInputFocusIndex: 0,
  lastInputPortIndex: 0,
  inputLoading: false,
  isSwitchingInput: false,
  switchingPortName: "",
  currentActivePortId: localStorage.getItem("last_tv_input_port") || "HDMI_1",
  async openInputSources() {
    this.inputLoading = true;
    this.activeInputFocusIndex = 0;
    await this.fetchTvInputs();
    this.$nextTick(() => {
      this.focusCurrentInputPort();
    });
  },
  async fetchTvInputs() {
    var _a, _b;
    try {
      if ((_a = window.flutterBridge) == null ? void 0 : _a.getSelectedLiveTvPort) {
        const activeRes = await window.flutterBridge.getSelectedLiveTvPort();
        const activeId = (activeRes == null ? void 0 : activeRes.selectedPort) || (activeRes == null ? void 0 : activeRes.port);
        if (activeId) {
          this.currentActivePortId = activeId;
          localStorage.setItem("last_tv_input_port", activeId);
        }
      }
    } catch (_) {
    }
    try {
      if ((_b = window.flutterBridge) == null ? void 0 : _b.getTvInputs) {
        const list = await window.flutterBridge.getTvInputs();
        if (Array.isArray(list)) {
          this.inputPorts = this.normalizePorts(list);
          this.inputLoading = false;
          return;
        }
      }
    } catch (e) {
      console.warn("[TVInput] Error fetching TV inputs from bridge:", e);
    }
    this.inputPorts = [];
    this.inputLoading = false;
  },
  normalizePorts(ports) {
    const rawList = Array.isArray(ports) ? ports : [];
    const hdmiOnly = rawList.filter(port => {
      const raw = String(port.id || port.model || port.name || port.label || port.portName || port.deviceName || "").toUpperCase();
      const type = String(port.type || "").toUpperCase();
      return (raw.includes("HDMI") || type === "HDMI") &&
             !raw.includes("AV") &&
             !raw.includes("TUNER") &&
             !raw.includes("COMPOSITE") &&
             !raw.includes("TV (TUNER)");
    });
    if (hdmiOnly.length === 0) {
      return [];
    }

    return hdmiOnly.map((port, idx) => {
      const rawId = port.id || port.model || port.name || `HDMI_${idx + 1}`;
      const idUpper = String(rawId).toUpperCase();
      let type = "HDMI";
      let badge = port.badge;
      if (!badge) {
        if (idUpper.includes("EARC") || idUpper.includes("ARC") || idx === 1) badge = "eARC / ARC";
        else badge = "4K HDR 60Hz";
      }

      // 1. Port Name (Niche / Lower) e.g., HDMI 1, HDMI 2
      let portName = (port.portName || "").trim();
      if (!portName) {
        const matchHdmi = idUpper.match(/HDMI[-_\s]?([0-9]+)/i);
        if (matchHdmi) {
          portName = "HDMI " + matchHdmi[1];
        } else {
          const matchLabel = String(port.label || port.name || "").match(/HDMI[-_\s]?([0-9]+)/i);
          if (matchLabel) {
            portName = "HDMI " + matchLabel[1];
          } else {
            portName = `HDMI ${idx + 1}`;
          }
        }
      }

      // 2. Connected Device Name (Upper) e.g., Tata Play, Dish TV, PlayStation 5
      let deviceName = (port.deviceName || "").trim();
      const rawLabel = String(port.label || port.name || "").trim();
      const isGenericHdmi = /^HDMI[\s\-_0-9]*$/i.test(rawLabel);
      const isInternalId = rawLabel.includes(".") || rawLabel.includes("/") || rawLabel.toUpperCase().includes("HW");

      if (!deviceName && rawLabel && !isGenericHdmi && !isInternalId) {
        deviceName = rawLabel;
      }

      // Fallback contextual device name if no CEC broadcast
      if (!deviceName) {
        if (idUpper.includes("1") || portName.includes("1") || idx === 0) {
          deviceName = "Set-top Box / DTH";
        } else if (idUpper.includes("2") || portName.includes("2") || idx === 1) {
          deviceName = "Gaming Console / Media";
        } else if (idUpper.includes("3") || portName.includes("3") || idx === 2) {
          deviceName = "Streaming Player";
        } else {
          deviceName = "Connected Device";
        }
      }

      let desc = port.description || portName;

      return {
        id: rawId,
        label: deviceName,
        name: deviceName,
        deviceName: deviceName,
        portName: portName,
        model: port.model || rawId,
        type,
        badge,
        description: desc,
        isConnected: port.isConnected !== false && port.isConnected !== "false"
      };
    });
  },
  isPortActive(port) {
    if (!port) return false;
    return port.id === this.currentActivePortId || port.model === this.currentActivePortId;
  },
  getActivePortName() {
    if (this.switchingPortName) return this.switchingPortName;
    if (!this.currentActivePortId) return "HDMI 1";
    if (Array.isArray(this.inputPorts) && this.inputPorts.length > 0) {
      const found = this.inputPorts.find(
        (p) => p && (p.id === this.currentActivePortId || p.model === this.currentActivePortId || p.name === this.currentActivePortId || p.portName === this.currentActivePortId)
      );
      if (found) {
        if (found.deviceName && found.portName) {
          return `${found.deviceName} (${found.portName})`;
        }
        return found.portName || found.deviceName || found.label || found.name || "HDMI 1";
      }
    }
    const raw = String(this.currentActivePortId).trim();
    const matchHdmi = raw.match(/HDMI[-_\s]?([0-9]+)/i);
    if (matchHdmi) return "HDMI " + matchHdmi[1];
    if (raw.toUpperCase().includes("AV") || raw.toUpperCase().includes("COMPOSITE")) return "AV Input";
    if (raw.toUpperCase().includes("TUNER") || raw.toUpperCase().includes("DTV") || raw.toUpperCase().includes("ANTENNA")) return "Live TV";
    if (raw.toUpperCase() === "IPTV") return "IPTV";
    if (Array.isArray(this.inputPorts) && this.inputPorts.length > 0) {
      const first = this.inputPorts[0];
      if (first.deviceName && first.portName) {
        return `${first.deviceName} (${first.portName})`;
      }
      return first.portName || first.deviceName || first.label || first.name || "HDMI 1";
    }
    return "HDMI 1";
  },
  getGridCols() {
    const total = this.inputPorts ? this.inputPorts.length : 0;
    if (total <= 1) return 1;
    if (total === 2) return 2;
    if (total === 3) return 3;
    if (total === 4) return 4;
    if (total <= 6) return 3;
    return 4;
  },
  getGridContainerClass() {
    const total = (this.inputPorts || []).length;
    if (total <= 1) return "max-w-md mx-auto grid grid-cols-1 gap-6 justify-center";
    if (total === 2) return "max-w-3xl mx-auto grid grid-cols-2 gap-8 justify-center";
    if (total === 3) return "max-w-5xl mx-auto grid grid-cols-3 gap-6 justify-center";
    if (total === 4) return "max-w-6xl mx-auto grid grid-cols-4 gap-6 justify-center";
    if (total <= 6) return "max-w-5xl mx-auto grid grid-cols-3 gap-5 justify-center";
    return "max-w-6xl mx-auto grid grid-cols-4 gap-4 max-h-[500px] overflow-y-auto no-scrollbar p-1 justify-center";
  },
  isCompactLayout() {
    return (this.inputPorts || []).length > 4;
  },
  async selectInputPort(port) {
    var _a, _b, _c, _d;
    if (!port || this.isSwitchingInput) return;
    const portId = port.id || port.model || port.name || port.label;
    const portLabel = port.label || port.name || portId;
    console.log("[TVInput] Activating hardware port:", portId);
    this.currentActivePortId = portId;
    this.switchingPortName = portLabel;
    this.isSwitchingInput = true;
    localStorage.setItem("last_tv_input_port", portId);
    if ((_a = window.flutterBridge) == null ? void 0 : _a.savePortPreference) {
      window.flutterBridge.savePortPreference(portId).catch(() => {
      });
    }
    try {
      const webosDev = typeof window !== "undefined" && (window.WebOSDevice || window.parent && window.parent.WebOSDevice);
      if (port.type === "TUNER") {
        if (webosDev && typeof webosDev.launchLiveTv === "function") {
          webosDev.launchLiveTv(portId);
        } else if ((_b = window.flutterBridge) == null ? void 0 : _b.launchLiveTv) {
          await window.flutterBridge.launchLiveTv(portId);
        }
      } else {
        if (webosDev && typeof webosDev.switchInput === "function") {
          webosDev.switchInput(portId);
        } else if ((_c = window.flutterBridge) == null ? void 0 : _c.launchHdmi) {
          await window.flutterBridge.launchHdmi(portId);
        } else if ((_d = window.FlutterBridge) == null ? void 0 : _d.postMessage) {
          window.FlutterBridge.postMessage(JSON.stringify({ method: "launchHdmi", args: [portId], id: Date.now() }));
        }
      }
      if (false) {
        await window.flutterBridge.launchLiveTv(portId);
      } else if ((_c = window.flutterBridge) == null ? void 0 : _c.launchHdmi) {
        await window.flutterBridge.launchHdmi(portId);
      } else if ((_d = window.FlutterBridge) == null ? void 0 : _d.postMessage) {
        window.FlutterBridge.postMessage(JSON.stringify({ method: "launchHdmi", args: [portId], id: Date.now() }));
      }
    } catch (err) {
      console.warn("[TVInput] Bridge launch warning:", err);
    }
    setTimeout(() => {
      this.isSwitchingInput = false;
      if (typeof this.showToast === "function") {
        this.showToast(`Display switched to ${portLabel}`);
      }
    }, 1200);
  },
  focusCurrentInputPort() {
    this.$nextTick(() => {
      if (typeof this.activeInputFocusIndex === "number") {
        const el = document.getElementById(`input_port_${this.activeInputFocusIndex}`);
        if (el) {
          el.focus();
          el.scrollIntoView({ behavior: "smooth", block: "nearest", inline: "nearest" });
        }
      }
    });
  },
  handleInputGridNavigation(e) {
    var _a, _b, _c;
    if (this.isSwitchingInput) {
      e.preventDefault();
      return true;
    }
    const list = this.inputPorts || [];
    const total = list.length;
    if (total === 0) return false;
    const cols = this.getGridCols();
    if (TVRemoteManager.matches(e, "LEFT")) {
      e.preventDefault();
      if (typeof this.activeInputFocusIndex === "number") {
        if (this.activeInputFocusIndex > 0) {
          this.activeInputFocusIndex -= 1;
          this.focusCurrentInputPort();
        }
      }
      return true;
    }
    if (TVRemoteManager.matches(e, "RIGHT")) {
      e.preventDefault();
      if (typeof this.activeInputFocusIndex === "number") {
        if (this.activeInputFocusIndex < total - 1) {
          this.activeInputFocusIndex += 1;
          this.focusCurrentInputPort();
        }
      }
      return true;
    }
    if (TVRemoteManager.matches(e, "UP")) {
      e.preventDefault();
      if (typeof this.activeInputFocusIndex === "number") {
        if (this.activeInputFocusIndex >= cols) {
          this.activeInputFocusIndex -= cols;
          this.focusCurrentInputPort();
        } else {
          this.lastInputPortIndex = this.activeInputFocusIndex;
          this.activeInputFocusIndex = "header_back";
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
      if (this.activeInputFocusIndex === "header_back" || document.activeElement === document.getElementById("tv-header-back-btn")) {
        (_a = document.getElementById("tv-header-back-btn")) == null ? void 0 : _a.blur();
        this.activeInputFocusIndex = typeof this.lastInputPortIndex === "number" ? this.lastInputPortIndex : 0;
        this.focusCurrentInputPort();
        return true;
      }
      if (typeof this.activeInputFocusIndex === "number") {
        if (this.activeInputFocusIndex + cols < total) {
          this.activeInputFocusIndex += cols;
          this.focusCurrentInputPort();
        } else if (Math.floor(this.activeInputFocusIndex / cols) < Math.floor((total - 1) / cols)) {
          this.activeInputFocusIndex = total - 1;
          this.focusCurrentInputPort();
        }
      }
      return true;
    }
    if (TVRemoteManager.matches(e, "ENTER")) {
      e.preventDefault();
      if (this.activeInputFocusIndex === "header_back" || document.activeElement === document.getElementById("tv-header-back-btn")) {
        this.goBack();
      } else if (typeof this.activeInputFocusIndex === "number") {
        const selected = list[this.activeInputFocusIndex];
        if (selected) this.selectInputPort(selected);
      } else {
        (_c = (_b = document.activeElement) == null ? void 0 : _b.click) == null ? void 0 : _c.call(_b);
      }
      return true;
    }
    return false;
  }
};
