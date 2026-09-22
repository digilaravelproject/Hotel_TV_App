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
        if (Array.isArray(list) && list.length > 0) {
          this.inputPorts = this.normalizePorts(list);
          this.inputLoading = false;
          return;
        }
      }
    } catch (e) {
      console.warn("[TVInput] Error fetching TV inputs from bridge:", e);
    }
    this.inputPorts = this.normalizePorts([
      {
        id: "HDMI_1",
        label: "HDMI 1",
        name: "HDMI 1",
        model: "HDMI_1",
        type: "HDMI",
        isConnected: true,
        badge: "4K HDR 60Hz",
        description: "Set-top Box / Cable TV"
      },
      {
        id: "HDMI_2",
        label: "HDMI 2 (eARC)",
        name: "HDMI 2",
        model: "HDMI_2",
        type: "HDMI",
        isConnected: true,
        badge: "eARC / ARC",
        description: "Gaming Console / Soundbar"
      },
      {
        id: "AV",
        label: "AV Input",
        name: "AV Input",
        model: "AV",
        type: "AV",
        isConnected: true,
        badge: "Analog RCA",
        description: "Composite Video / Audio"
      },
      {
        id: "TUNER",
        label: "Live TV (Tuner)",
        name: "Live TV (Tuner)",
        model: "TUNER",
        type: "TUNER",
        isConnected: true,
        badge: "DTV Antenna",
        description: "Over-The-Air Digital Channels"
      }
    ]);
    this.inputLoading = false;
  },
  normalizePorts(ports) {
    return (ports || []).map((port, idx) => {
      const rawId = port.id || port.model || port.name || `PORT_${idx + 1}`;
      const idUpper = String(rawId).toUpperCase();
      let type = port.type || "HDMI";
      if (idUpper.includes("AV") || idUpper.includes("COMPOSITE")) type = "AV";
      else if (idUpper.includes("TUNER") || idUpper.includes("DTV") || idUpper.includes("ANTENNA")) type = "TUNER";
      else if (idUpper.includes("HDMI")) type = "HDMI";
      let badge = port.badge;
      if (!badge) {
        if (idUpper.includes("EARC") || idUpper.includes("ARC") || type === "HDMI" && idx === 1) badge = "eARC / ARC";
        else if (type === "HDMI") badge = "4K HDR 60Hz";
        else if (type === "AV") badge = "Composite RCA";
        else if (type === "TUNER") badge = "DTV Antenna";
        else badge = "Connected";
      }
      let desc = port.description;
      if (!desc) {
        if (type === "HDMI" && (idUpper.includes("1") || idx === 0)) desc = "Set-top Box / Cable TV";
        else if (type === "HDMI" && (idUpper.includes("2") || idx === 1)) desc = "Gaming Console / Soundbar";
        else if (type === "HDMI" && (idUpper.includes("3") || idx === 2)) desc = "Media Player / Streaming Device";
        else if (type === "HDMI") desc = "High Definition Source";
        else if (type === "AV") desc = "Composite Video / Audio";
        else if (type === "TUNER") desc = "Over-The-Air Digital Channels";
        else desc = "Connected Hardware Port";
      }
      return {
        id: rawId,
        label: port.label || port.name || rawId,
        name: port.name || port.label || rawId,
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
      if (port.type === "TUNER" && ((_b = window.flutterBridge) == null ? void 0 : _b.launchLiveTv)) {
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
