/**
 * Advanced Configuration Page Logic
 * Built with comprehensive error handling and offline fallbacks.
 */

window.triggerOpenSettings = function () {
    try {
        console.log("[Bridge] Triggering Android Settings...");
        // 1. Standard Flutter Bridge API
        if (window.flutterBridge && typeof window.flutterBridge.openSettings === 'function') {
            try {
                window.flutterBridge.openSettings().catch(function (err) {
                    console.warn("flutterBridge.openSettings rejected, trying direct postMessage fallback:", err);
                    tryDirectPostMessage();
                });
                return;
            } catch (bridgeErr) {
                console.warn("flutterBridge.openSettings exception:", bridgeErr);
                tryDirectPostMessage();
                return;
            }
        }

        // 2. FlutterBridge direct postMessage channel
        if (tryDirectPostMessage()) {
            return;
        }

        // 3. Android Native WebView JavascriptInterface
        if (window.Android) {
            try {
                if (typeof window.Android.openAndroidSettings === 'function') {
                    window.Android.openAndroidSettings();
                    return;
                }
                if (typeof window.Android.openSettings === 'function') {
                    window.Android.openSettings();
                    return;
                }
            } catch (androidErr) {
                console.warn("window.Android.openAndroidSettings exception:", androidErr);
            }
        }

        // 4. PHP backend ADB fallback
        try {
            var ipEl = document.getElementById('v-ip');
            var ip = ipEl ? ipEl.innerText.trim() : '';
            if (ip && ip !== "..." && ip !== "") {
                var xhr = new XMLHttpRequest();
                xhr.open("GET", "admin/open_settings.php?ip=" + encodeURIComponent(ip) + "&t=" + Date.now(), true);
                xhr.send();
            }
        } catch (xhrErr) {
            console.warn("PHP open_settings fallback failed:", xhrErr);
        }
    } catch (globalErr) {
        console.error("Critical error in triggerOpenSettings:", globalErr);
    }
};

function tryDirectPostMessage() {
    try {
        if (window.FlutterBridge && typeof window.FlutterBridge.postMessage === 'function') {
            window.FlutterBridge.postMessage(JSON.stringify({ method: 'openSettings', args: [], id: Date.now() }));
            return true;
        }
    } catch (e) {
        console.warn("FlutterBridge direct postMessage exception:", e);
    }
    return false;
}

document.addEventListener('DOMContentLoaded', function () {
    try {
        // Load config and init slider
        if (window.TVCore && typeof window.TVCore.fetchHotelConfig === 'function') {
            TVCore.fetchHotelConfig().then(config => {
                try {
                    if (config && !TVCore.checkPlanExpiredRedirect(config)) {
                        TVCore.initBackgroundSlider(config);
                    }
                } catch (sliderErr) {
                    console.warn("Background slider init error:", sliderErr);
                }
            }).catch(err => {
                console.warn("fetchHotelConfig failed in advanced.js:", err);
            });
        }
    } catch (initErr) {
        console.warn("Init background slider error:", initErr);
    }

    var room = document.getElementById('roomNum');
    var currentSrc = "";
    var currentPkg = "";
    var isSaving = false;

    function cleanPortName(rawName) {
        try {
            if (!rawName) return "";
            var str = String(rawName).trim();
            // Remove existing Setup Box (...) wrapper if present
            str = str.replace(/^Setup Box\s*\((.*)\)$/i, '$1').trim();
            // Replace underscore with space if like HDMI_1 -> HDMI 1
            if (/^HDMI_\d+$/i.test(str)) {
                str = str.replace('_', ' ');
            }
            return str;
        } catch (e) {
            return String(rawName || "");
        }
    }

    function formatSetupBoxLabel(rawName) {
        try {
            if (!rawName) return "Setup Box (HDMI 1)";
            var clean = cleanPortName(rawName);
            return "Setup Box (" + clean + ")";
        } catch (e) {
            return "Setup Box (HDMI 1)";
        }
    }

    function updateLiveTvButtonLabel(label) {
        try {
            var btn = document.getElementById('btn-livetv-popup');
            if (btn) {
                btn.innerHTML = (label || "LIVE TV") + ' <span class="tick">✔</span>';
                btn.classList.add('selected');
            }
        } catch (e) {
            console.warn("Error updating Live TV button label:", e);
        }
    }

    // Initialize Live TV input button label on page load
    try {
        var initialSavedPort = localStorage.getItem('selectedLiveTvPort') || '';
        if (initialSavedPort) {
            currentPkg = initialSavedPort;
            currentSrc = formatSetupBoxLabel(initialSavedPort);
            updateLiveTvButtonLabel(currentSrc);
        }

        if (window.flutterBridge && typeof window.flutterBridge.getSelectedLiveTvPort === 'function') {
            window.flutterBridge.getSelectedLiveTvPort().then(function (res) {
                try {
                    if (res && (res.selectedPort || res.port)) {
                        var p = res.selectedPort || res.port;
                        currentPkg = p;
                        currentSrc = formatSetupBoxLabel(p);
                        updateLiveTvButtonLabel(currentSrc);
                    }
                } catch (parseErr) {
                    console.warn("Error parsing getSelectedLiveTvPort result:", parseErr);
                }
            }).catch(function (err) {
                console.info("getSelectedLiveTvPort fallback:", err);
            });
        }
    } catch (storageErr) {
        console.warn("Error reading initial TV port from storage:", storageErr);
    }

    // Make functions globally available for inline onClick handlers
    window.openLiveTvInputsPopup = function () {
        try {
            var box = document.getElementById('packageBox');
            var header = document.getElementById('pkgHeader');
            if (header) header.textContent = "SELECT TV INPUT SOURCE";
            if (box) box.querySelectorAll('.package-item').forEach(el => el.remove());

            const defaultInputs = [
                { "name": "HDMI 1", "id": "HDMI_1" },
                { "name": "HDMI 2", "id": "HDMI_2" },
                { "name": "HDMI 3", "id": "HDMI_3" },
                { "name": "AV Input", "id": "AV" },
                { "name": "IPTV Stream", "id": "IPTV" }
            ];

            function renderInputs(inputsList, selectedPort) {
                try {
                    if (!box) return;
                    box.querySelectorAll('.package-item').forEach(el => el.remove());
                    if (!inputsList || !Array.isArray(inputsList) || inputsList.length === 0) {
                        inputsList = defaultInputs;
                    }

                    var cleanSelected = cleanPortName(selectedPort || currentPkg || 'HDMI 1');

                    inputsList.forEach(item => {
                        try {
                            var itemPortId = item.id || item.package || item.file || item.name || item.model || item.value || (typeof item === 'string' ? item : 'HDMI_1');
                            var baseName = cleanPortName(item.name || item.label || item.model || itemPortId);
                            var isSelected = Boolean(cleanSelected && (cleanPortName(itemPortId).toLowerCase() === cleanSelected.toLowerCase() || baseName.toLowerCase() === cleanSelected.toLowerCase()));

                            var itemLabel = isSelected ? ("Setup Box (" + baseName + ")") : baseName;

                            var div = document.createElement('div');
                            div.className = 'package-item' + (isSelected ? ' selected' : '');
                            div.tabIndex = 0;
                            div.setAttribute('data-port-id', itemPortId);

                            var textSpan = document.createElement('span');
                            textSpan.innerText = itemLabel;
                            div.appendChild(textSpan);

                            var tickSpan = document.createElement('span');
                            tickSpan.className = 'tick';
                            tickSpan.innerText = '✔';
                            div.appendChild(tickSpan);

                            div.onclick = () => {
                                try {
                                    var selectedId = itemPortId;
                                    currentPkg = selectedId;
                                    currentSrc = "Setup Box (" + baseName + ")";
                                    try {
                                        localStorage.setItem('selectedLiveTvPort', selectedId);
                                        localStorage.setItem('selectedLiveTvLabel', currentSrc);
                                    } catch (lsErr) { }

                                    if (window.flutterBridge && typeof window.flutterBridge.savePortPreference === 'function') {
                                        try { window.flutterBridge.savePortPreference(selectedId); } catch (e) { }
                                    }
                                    var overlay = document.getElementById('packageOverlay');
                                    if (overlay) overlay.style.display = 'none';
                                    updateLiveTvButtonLabel(currentSrc);
                                    updateUI('btn-livetv-popup');
                                } catch (clickErr) {
                                    console.error("Error in port selection click:", clickErr);
                                }
                            };
                            div.onkeydown = (e) => {
                                if (e.key === 'Enter' || e.keyCode === 13) div.click();
                            };
                            box.appendChild(div);
                        } catch (itemRenderErr) {
                            console.warn("Error rendering port item:", itemRenderErr);
                        }
                    });

                    var overlay = document.getElementById('packageOverlay');
                    if (overlay) overlay.style.display = 'flex';
                    if (window.TVNavigation && typeof window.TVNavigation.markDirty === 'function') {
                        window.TVNavigation.markDirty();
                    }
                    setTimeout(() => {
                        try {
                            var targetToFocus = box.querySelector('.package-item.selected') || box.querySelector('.package-item');
                            if (targetToFocus) targetToFocus.focus();
                        } catch (focusErr) { }
                    }, 100);
                } catch (renderErr) {
                    console.error("Error in renderInputs:", renderErr);
                }
            }

            var savedPortPref = '';
            try {
                savedPortPref = localStorage.getItem('selectedLiveTvPort') || currentPkg || '';
            } catch (e) { }

            // Query Flutter Bridge for live connected TV ports & fallback to TV inputs
            if (window.flutterBridge && typeof window.flutterBridge.getLiveTvInputs === 'function') {
                Promise.all([
                    window.flutterBridge.getLiveTvInputs().catch(() => []),
                    (window.flutterBridge.getSelectedLiveTvPort ? window.flutterBridge.getSelectedLiveTvPort().catch(() => ({ selectedPort: savedPortPref })) : Promise.resolve({ selectedPort: savedPortPref })),
                    (window.flutterBridge.getTvInputs ? window.flutterBridge.getTvInputs().catch(() => []) : Promise.resolve([]))
                ]).then(function (results) {
                    try {
                        var livePorts = Array.isArray(results[0]) ? results[0] : [];
                        var savedRes = results[1] || {};
                        var allTvInputs = Array.isArray(results[2]) ? results[2] : [];

                        var ports = (livePorts.length > 0) ? livePorts : ((allTvInputs.length > 0) ? allTvInputs : defaultInputs);
                        var savedPort = savedRes.selectedPort || savedRes.port || savedPortPref;

                        if (!savedPort && ports.length > 0) {
                            savedPort = ports[0].id || ports[0].model || ports[0].name || ports[0].label;
                        }

                        renderInputs(ports, savedPort);
                    } catch (promiseErr) {
                        console.warn("Error processing bridge TV input results:", promiseErr);
                        renderInputs(defaultInputs, savedPortPref);
                    }
                }).catch(function (err) {
                    console.warn("Failed to query TV input ports via bridge, using defaults:", err);
                    renderInputs(defaultInputs, savedPortPref);
                });
                return;
            }

            renderInputs(defaultInputs, savedPortPref);
        } catch (popupErr) {
            console.error("Critical error in openLiveTvInputsPopup:", popupErr);
        }
    };

    window.openIptvMenu = function () {
        try {
            var box = document.getElementById('packageBox');
            if (box) box.querySelectorAll('.package-item').forEach(el => el.remove());

            function renderPackages(packages) {
                try {
                    if (!box) return;
                    box.querySelectorAll('.package-item').forEach(el => el.remove());
                    packages.forEach(pkg => {
                        try {
                            var div = document.createElement('div');
                            div.className = 'package-item';
                            div.tabIndex = 0;
                            div.innerText = pkg.name || "IPTV Package";
                            div.onclick = () => {
                                try {
                                    currentPkg = pkg.file || "";
                                    currentSrc = "IPTV";
                                    var overlay = document.getElementById('packageOverlay');
                                    if (overlay) overlay.style.display = 'none';
                                    updateUI('btn-iptv');
                                } catch (e) { }
                            };
                            div.onkeydown = (e) => {
                                if (e.key === 'Enter' || e.keyCode === 13) div.click();
                            };
                            box.appendChild(div);
                        } catch (e) { }
                    });
                    var overlay = document.getElementById('packageOverlay');
                    if (overlay) overlay.style.display = 'flex';
                    if (window.TVNavigation && typeof window.TVNavigation.markDirty === 'function') {
                        window.TVNavigation.markDirty();
                    }
                    setTimeout(() => {
                        try {
                            var first = box.querySelector('.package-item');
                            if (first) first.focus();
                        } catch (e) { }
                    }, 100);
                } catch (e) {
                    console.error("Error in renderPackages:", e);
                }
            }

            var fallbackPackages = [
                { "name": "IPTV All Channels", "file": "iptv/all.json" },
                { "name": "IPTV Sports Package", "file": "iptv/sports.json" },
                { "name": "IPTV News & Movies", "file": "iptv/news_movies.json" }
            ];

            var xhr = new XMLHttpRequest();
            xhr.open("GET", "admin/iptv_packages.json?t=" + Date.now(), true);
            xhr.onreadystatechange = function () {
                try {
                    if (xhr.readyState == 4) {
                        if (xhr.status == 200) {
                            try {
                                var data = JSON.parse(xhr.responseText);
                                if (data && data.available_packages && data.available_packages.length > 0) {
                                    renderPackages(data.available_packages);
                                    return;
                                }
                            } catch (e) { }
                        }
                        renderPackages(fallbackPackages);
                    }
                } catch (e) {
                    renderPackages(fallbackPackages);
                }
            };
            xhr.onerror = function () {
                renderPackages(fallbackPackages);
            };
            xhr.send();
        } catch (iptvErr) {
            console.error("Error in openIptvMenu:", iptvErr);
        }
    };

    window.openAppMenu = function () {
        try {
            var box = document.getElementById('appBox');
            if (box) box.querySelectorAll('.package-item').forEach(el => el.remove());

            function renderApps(apps) {
                try {
                    if (!box) return;
                    box.querySelectorAll('.package-item').forEach(el => el.remove());
                    apps.forEach(app => {
                        try {
                            var div = document.createElement('div');
                            div.className = 'package-item';
                            div.tabIndex = 0;
                            div.innerText = app.name || "App";
                            div.onclick = () => {
                                try {
                                    currentPkg = app.process || app.package || app.id;
                                    currentSrc = "TV APP";
                                    var overlay = document.getElementById('appOverlay');
                                    if (overlay) overlay.style.display = 'none';
                                    updateUI('btn-tvapp');
                                } catch (e) { }
                            };
                            div.onkeydown = (e) => {
                                if (e.key === 'Enter' || e.keyCode === 13) div.click();
                            };
                            box.appendChild(div);
                        } catch (e) { }
                    });
                    var overlay = document.getElementById('appOverlay');
                    if (overlay) overlay.style.display = 'flex';
                    if (window.TVNavigation && typeof window.TVNavigation.markDirty === 'function') {
                        window.TVNavigation.markDirty();
                    }
                    setTimeout(() => {
                        try {
                            var first = box.querySelector('.package-item');
                            if (first) first.focus();
                        } catch (e) { }
                    }, 100);
                } catch (e) {
                    console.error("Error in renderApps:", e);
                }
            }

            var fallbackApps = [
                { "name": "YouTube", "process": "com.google.android.youtube.tv" },
                { "name": "Netflix", "process": "com.netflix.ninja" },
                { "name": "Prime Video", "process": "com.amazon.amazonvideo.livingroom" },
                { "name": "Live TV App", "process": "com.google.android.tv" }
            ];

            var xhr = new XMLHttpRequest();
            xhr.open("GET", "admin/tv_apps.json?t=" + Date.now(), true);
            xhr.onreadystatechange = function () {
                try {
                    if (xhr.readyState == 4) {
                        if (xhr.status == 200) {
                            try {
                                var data = JSON.parse(xhr.responseText);
                                if (data && data.available_tv_apps && data.available_tv_apps.length > 0) {
                                    renderApps(data.available_tv_apps);
                                    return;
                                }
                            } catch (e) { }
                        }
                        renderApps(fallbackApps);
                    }
                } catch (e) {
                    renderApps(fallbackApps);
                }
            };
            xhr.onerror = function () {
                renderApps(fallbackApps);
            };
            xhr.send();
        } catch (appErr) {
            console.error("Error in openAppMenu:", appErr);
        }
    };

    window.openHdmiPort = function () {
        try {
            var box = document.getElementById('hdmiBox');
            var overlay = document.getElementById('hdmiOverlay');
            if (!box || !overlay) return;
            box.innerHTML = '<div style="color:#888; text-align:center; padding:15px;">Scanning TV Ports...</div>';

            var bridge = window.flutterBridge;
            var fetchPromise = (bridge && typeof bridge.getTvInputs === 'function')
                ? bridge.getTvInputs()
                : Promise.resolve([
                    { id: 'HDMI_1', label: 'HDMI 1', name: 'HDMI 1' },
                    { id: 'HDMI_2', label: 'HDMI 2', name: 'HDMI 2' },
                    { id: 'AV', label: 'AV Input', name: 'AV Input' }
                ]);

            fetchPromise.then(function (ports) {
                renderHardwareHdmiList(ports);
            }).catch(function () {
                renderHardwareHdmiList([
                    { id: 'HDMI_1', label: 'HDMI 1', name: 'HDMI 1' },
                    { id: 'HDMI_2', label: 'HDMI 2', name: 'HDMI 2' },
                    { id: 'AV', label: 'AV Input', name: 'AV Input' }
                ]);
            });

            function renderHardwareHdmiList(portsList) {
                box.innerHTML = '';
                if (!portsList || portsList.length === 0) {
                    box.innerHTML = '<div style="color:#888; text-align:center; padding:15px;">No TV ports detected</div>';
                    return;
                }

                portsList.forEach(function (port) {
                    var portId = port.id || port.model || port.name || port.label || 'HDMI_1';
                    var portLabel = port.label || port.name || port.id || 'HDMI';

                    let row = document.createElement('div');
                    row.className = 'hdmi-list-row';
                    row.tabIndex = 0;

                    row.innerHTML = `
                        <div class="model-name-text" tabindex="0">${portLabel}</div>
                        <button class="test-btn-inline" tabindex="0">TEST</button>
                    `;

                    const modelLabel = row.querySelector('.model-name-text');
                    const testBtn = row.querySelector('.test-btn-inline');

                    if (modelLabel) {
                        modelLabel.onclick = (e) => {
                            e.stopPropagation();
                            confirmSelection(portId);
                        };
                    }

                    if (testBtn) {
                        testBtn.onclick = (e) => {
                            e.stopPropagation();
                            if (window.flutterBridge && typeof window.flutterBridge.launchHdmi === 'function') {
                                window.flutterBridge.launchHdmi(portId).catch(function (err) {
                                    console.error("Test HDMI launch failed:", err);
                                });
                            }
                        };
                    }

                    row.onkeydown = (e) => {
                        if (e.keyCode === 39 && testBtn) testBtn.focus();
                        if (e.keyCode === 37 && modelLabel) modelLabel.focus();
                        if (e.keyCode === 13) {
                            if (document.activeElement === testBtn) testBtn.click();
                            else confirmSelection(portId);
                        }
                    };

                    box.appendChild(row);
                });

                overlay.style.display = 'flex';
                if (window.TVNavigation && typeof window.TVNavigation.markDirty === 'function') {
                    window.TVNavigation.markDirty();
                }
                setTimeout(() => {
                    try {
                        let firstTestBtn = box.querySelector('.model-name-text') || box.querySelector('.test-btn-inline');
                        if (firstTestBtn) firstTestBtn.focus();
                    } catch (e) { }
                }, 100);
            }
        } catch (hdmiErr) {
            console.error("Error in openHdmiPort:", hdmiErr);
        }
    };

    function confirmSelection(pkg) {
        try {
            currentPkg = pkg;
            currentSrc = "HDMI";
            try {
                localStorage.setItem('selectedLiveTvPort', pkg);
            } catch (e) { }

            if (window.flutterBridge && typeof window.flutterBridge.savePortPreference === 'function') {
                try { window.flutterBridge.savePortPreference(pkg); } catch (e) { }
            }
            var overlay = document.getElementById('hdmiOverlay');
            if (overlay) overlay.style.display = 'none';
            updateUI('btn-hdmi');
        } catch (e) {
            console.warn("confirmSelection error:", e);
        }
    }

    function updateUI(activeId) {
        try {
            document.querySelectorAll('.list-item').forEach(el => el.classList.remove('selected'));
            const activeEl = document.getElementById(activeId);
            if (activeEl) activeEl.classList.add('selected');

            const saveBtn = document.getElementById('saveBtn');
            if (saveBtn) {
                saveBtn.blur();
                setTimeout(() => {
                    try { saveBtn.focus(); } catch (e) { }
                }, 50);
            }
        } catch (e) {
            console.warn("updateUI error:", e);
        }
    }

    window.loadHW = function () {
        try {
            // Query Flutter Bridge if available in Android TV environment
            if (window.flutterBridge && typeof window.flutterBridge.isAvailable === 'function' && window.flutterBridge.isAvailable() && typeof window.flutterBridge.identifyDevice === 'function') {
                window.flutterBridge.identifyDevice().then(function (info) {
                    try {
                        var d = (info && info.data) || (info && info.device) || info || {};
                        var hwData = {
                            serial: d.serial || d.device_id || d.deviceId || "UNKNOWN",
                            ip: d.ip || d.ip_address || d.ipAddress || "...",
                            gateway: d.gateway || d.gway || "...",
                            mac: d.mac || d.mac_address || d.macAddress || "...",
                            subnet: d.subnet || d.subnet_mask || d.subnetMask || "...",
                            dns: d.dns || d.DNS || "...",
                            model: d.model || "...",
                            android: d.android || d.os_version || d.osVersion || "11",
                            room: d.room || d.room_no || "",
                            version: d.version || d.template_version || d.latest_version || ""
                        };
                        if (!hwData.version && window.TVCore && typeof window.TVCore.getFastConfig === 'function') {
                            var fastCfg = TVCore.getFastConfig();
                            if (fastCfg && fastCfg.template && fastCfg.template.latest_version) {
                                hwData.version = fastCfg.template.latest_version;
                            }
                        }
                        displayHWData(hwData);
                    } catch (parseErr) {
                        console.warn("Error processing bridge device info:", parseErr);
                        loadHWFromConfig();
                    }
                }).catch(function (err) {
                    console.info("FlutterBridge identifyDevice fallback:", (err && err.message) ? err.message : err);
                    loadHWFromConfig();
                });
                return;
            }
        } catch (e) {
            console.warn("FlutterBridge loadHW exception:", e);
        }

        loadHWFromConfig();
    };

    function loadHWFromConfig() {
        try {
            if (window.TVCore && typeof window.TVCore.fetchHotelConfig === 'function') {
                TVCore.fetchHotelConfig().then(function (config) {
                    try {
                        if (config && config.device) {
                            var d = {
                                serial: config.device.device_id || "UNKNOWN",
                                ip: config.device.ip_address || "...",
                                gateway: config.device.gateway || "...",
                                mac: config.device.mac_address || "...",
                                subnet: config.device.subnet_mask || "...",
                                dns: config.device.dns || "...",
                                model: config.device.model || "...",
                                android: config.device.android_version || config.device.os_version || "11",
                                room: config.device.room_no || ""
                            };
                            if (config.template && config.template.latest_version) {
                                d.version = config.template.latest_version;
                            }
                            displayHWData(d);
                        }
                    } catch (e) {
                        console.warn("Error parsing config hardware details:", e);
                    }
                }).catch(function (err) {
                    console.warn("fetchHotelConfig failed in loadHWFromConfig:", err);
                });
            }
        } catch (e) {
            console.warn("loadHWFromConfig exception:", e);
        }
    }

    function displayHWData(d) {
        try {
            d = d || {};
            var safeSet = function (id, val) {
                var el = document.getElementById(id);
                if (el) el.innerText = val || "...";
            };

            safeSet('v-serial', d.serial || "UNKNOWN");
            safeSet('v-ip', d.ip || "...");
            safeSet('v-gateway', d.gateway || "...");
            safeSet('v-mac', d.mac || "...");
            safeSet('v-subnet', d.subnet || "...");
            safeSet('v-dns', d.dns || d.DNS || "...");
            safeSet('v-model', d.model || "...");
            safeSet('v-android', d.android || d.Andrd || "11");
            safeSet('v-version', d.version || "...");

            if (d.room && d.room !== "---" && room) {
                room.value = d.room;
            }

            setTimeout(() => {
                try {
                    let k1 = document.getElementById('key1');
                    if (k1) k1.focus();
                } catch (e) { }
            }, 300);
        } catch (e) {
            console.warn("Error displaying hardware details:", e);
        }
    }

    function press(v) {
        try {
            if (!room) return;
            if (!isNaN(v) && room.value.length < 3) {
                room.value += v;
                if (room.value.length == 3) {
                    setTimeout(function () {
                        try {
                            var iptvBtn = document.getElementById('btn-iptv');
                            if (iptvBtn) iptvBtn.focus();
                        } catch (e) { }
                    }, 200);
                }
            } else if (v == 'DEL') {
                room.value = room.value.slice(0, -1);
            }
        } catch (e) {
            console.warn("Keypad press error:", e);
        }
    }

    try {
        document.querySelectorAll('.key-btn').forEach(function (b) {
            if (b.dataset.val) {
                b.onclick = function (e) {
                    e.preventDefault();
                    press(b.dataset.val);
                };
            }
            b.addEventListener('focus', function () {
                try {
                    document.querySelectorAll('.active-focus').forEach(el => el.classList.remove('active-focus'));
                    this.classList.add('active-focus');
                } catch (e) { }
            });
            b.addEventListener('blur', function () {
                try {
                    this.classList.remove('active-focus');
                } catch (e) { }
            });
        });
    } catch (btnErr) {
        console.warn("Keypad button attachment error:", btnErr);
    }

    // Custom KeyDown Logic mapped into TVNavigation
    window.onTVNumberKey = function (key) {
        try { press(key); } catch (e) { }
    };

    window.onTVBack = function () {
        try {
            const overlays = ['.overlay-container', '.overlay-fullscreen'];
            let closedOverlay = false;
            overlays.forEach(selector => {
                document.querySelectorAll(selector).forEach(overlay => {
                    if (window.getComputedStyle(overlay).display !== 'none') {
                        overlay.style.display = 'none';
                        closedOverlay = true;
                    }
                });
            });
            if (closedOverlay) return true;
        } catch (e) { }
        return false;
    };

    window.onTVKeyDown = function (e) {
        try {
            var code = e.keyCode || e.which;
            var active = document.activeElement;

            if (code == 8) { press('DEL'); return true; }

            if (code == 13 && active && (
                active.classList.contains('list-item') ||
                active.classList.contains('package-item') ||
                active.classList.contains('hdmi-list-row') ||
                active.classList.contains('model-name-text') ||
                active.classList.contains('test-btn-inline') ||
                active.classList.contains('side-btn') ||
                active.classList.contains('btn-act') ||
                active.tagName === 'BUTTON'
            )) {
                e.preventDefault();
                e.stopImmediatePropagation();
                e.stopPropagation();
                active.click();
                return true;
            }
        } catch (err) {
            console.warn("onTVKeyDown error:", err);
        }
        return false;
    };

    // Advanced overrides for directional nav
    window.onTVNavigate = function (direction, active) {
        try {
            if (active.id === 'androidBtn') {
                if (direction === 'down') { document.getElementById('refreshBtn').focus(); return true; }
                if (direction === 'left') { document.getElementById('key1').focus(); return true; }
            } else if (active.id === 'refreshBtn') {
                if (direction === 'up') { document.getElementById('androidBtn').focus(); return true; }
                if (direction === 'left') { document.getElementById('key1').focus(); return true; }
                if (direction === 'down') { document.getElementById('saveBtn').focus(); return true; }
            }
        } catch (e) { }
        return false; // let default tv-navigation handle it
    };

    var saveBtn = document.getElementById('saveBtn');
    if (saveBtn) {
        saveBtn.onclick = function () {
            try {
                if (isSaving || (room && room.value.length < 3)) return;
                isSaving = true;
                var selectedPortId = currentPkg || currentSrc || "HDMI";
                var getSafeVal = function (id) {
                    var el = document.getElementById(id);
                    return el ? el.innerText.trim() : '';
                };

                var payload = {
                    room: room ? room.value : '',
                    serial: getSafeVal('v-serial'),
                    ip: getSafeVal('v-ip'),
                    mac: getSafeVal('v-mac'),
                    model: getSafeVal('v-model'),
                    tv_source: currentSrc || "HDMI",
                    package: currentPkg
                };

                try {
                    localStorage.setItem('selectedLiveTvPort', selectedPortId);
                    localStorage.setItem('roomNo', payload.room);
                } catch (lsErr) { }

                if (window.flutterBridge && typeof window.flutterBridge.savePortPreference === 'function') {
                    try { window.flutterBridge.savePortPreference(selectedPortId); } catch (e) { }
                }

                if (window.flutterBridge && typeof window.flutterBridge.saveDeviceConfig === 'function') {
                    window.flutterBridge.saveDeviceConfig(payload).then(function () {
                        window.location.href = 'index.html';
                    }).catch(function () {
                        window.location.href = 'index.html';
                    });
                    return;
                }

                var xhr = new XMLHttpRequest();
                xhr.open("POST", "admin/save_configuration.php", true);
                xhr.setRequestHeader("Content-Type", "application/json");

                xhr.onreadystatechange = function () {
                    try {
                        if (xhr.readyState === 4 && xhr.status === 200) {
                            try {
                                localStorage.setItem('deviceSerial', payload.serial);
                                localStorage.setItem('deviceIp', payload.ip);
                            } catch (e) { }
                            window.location.href = 'index.html';
                        }
                    } catch (e) {
                        window.location.href = 'index.html';
                    }
                };

                xhr.onerror = function () {
                    window.location.href = 'index.html';
                };

                xhr.send(JSON.stringify(payload));
            } catch (saveErr) {
                console.error("Error saving configuration:", saveErr);
                window.location.href = 'index.html';
            }
        };
    }

    var androidBtn = document.getElementById('androidBtn');
    if (androidBtn) {
        androidBtn.onclick = function (e) {
            try {
                if (e) e.preventDefault();
                window.triggerOpenSettings();
            } catch (err) {
                console.warn("androidBtn click error:", err);
            }
        };
    }

    var refreshBtn = document.getElementById('refreshBtn');
    if (refreshBtn) {
        refreshBtn.onclick = function () {
            try { window.loadHW(); } catch (e) { }
        };
    }

    var exitBtn = document.getElementById('exitBtn');
    if (exitBtn) exitBtn.onclick = () => { try { TVNavigation.goBack(); } catch (e) { window.history.back(); } };

    var escBtn = document.getElementById('btn-esc');
    if (escBtn) escBtn.onclick = () => { try { TVNavigation.goBack(); } catch (e) { window.history.back(); } };

    try {
        window.loadHW();
    } catch (e) {
        console.warn("Initial loadHW error:", e);
    }
});
