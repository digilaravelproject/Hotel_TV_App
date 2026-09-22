/**
 * Flight Module - Offline-First Flight Board
 * Optimized for Smart TV WebViews & Low-End Hardware
 */

(function () {
    'use strict';

    const CACHE_KEY_DEP = 'flights_cache_departures';
    const CACHE_KEY_ARR = 'flights_cache_arrivals';
    const CACHE_TIMESTAMP_KEY = 'flights_cache_timestamp';
    const MAX_CACHE_AGE_MS = 6 * 60 * 60 * 1000; // 6 hours

    let currentMode = 'departures';
    let currentPage = 0;
    let flightData = [];
    let currentLangData = null;
    let cityTranslations = [];
    let airlineTranslations = [];
    const rowsPerPage = 7;
    const fixedMaxFlights = 70;

    const navMap = {
        'backBtn': { left: null, right: 'depBtn', up: null, down: 'depBtn' },
        'depBtn': { left: 'backBtn', right: 'arrBtn', up: null, down: 'prevBtn' },
        'arrBtn': { left: 'depBtn', right: null, up: null, down: 'nextBtn' },
        'prevBtn': { left: null, right: 'nextBtn', up: 'depBtn', down: null },
        'nextBtn': { left: 'prevBtn', right: 'refreshBtn', up: 'arrBtn', down: null },
        'refreshBtn': { left: 'nextBtn', right: null, up: 'arrBtn', down: null }
    };

    async function loadFlightTranslations() {
        try {
            const langFile = localStorage.getItem('selectedLangFile') || 'english.json';
            const langCode = langFile.split('.')[0] || 'english';

            const langPaths = [`../languages/${langFile}`, `/languages/${langFile}`, `languages/${langFile}`];
            for (let path of langPaths) {
                try {
                    const response = await fetch(`${path}?t=${Date.now()}`);
                    if (response.ok) {
                        currentLangData = await response.json();
                        applyStaticLabels();
                        break;
                    }
                } catch (e) { }
            }

            const cityPaths = [`cities/${langCode}_cities.json`, `./cities/${langCode}_cities.json`];
            for (let path of cityPaths) {
                try {
                    const cityRes = await fetch(`${path}?t=${Date.now()}`);
                    if (cityRes.ok) {
                        cityTranslations = await cityRes.json();
                        break;
                    }
                } catch (e) { }
            }

            const airPaths = [`airlines/${langCode}_airlines.json`, `./airlines/${langCode}_airlines.json`];
            for (let path of airPaths) {
                try {
                    const airRes = await fetch(`${path}?t=${Date.now()}`);
                    if (airRes.ok) {
                        airlineTranslations = await airRes.json();
                        break;
                    }
                } catch (e) { }
            }
            renderPage();
        } catch (e) {
            console.error("Lang Load Error:", e);
        }
    }

    function getLocalName(englishName, translationList) {
        if (!translationList || !Array.isArray(translationList) || translationList.length === 0 || !englishName) {
            return englishName || "";
        }
        const searchName = englishName.trim().toLowerCase();

        const match = translationList.find(item => {
            if (!item || !item.english_name) return false;
            const entry = item.english_name.toLowerCase();
            return entry === searchName || searchName.startsWith(entry) || searchName.includes(entry) || entry.includes(searchName);
        });

        return match ? match.local_name : englishName;
    }

    function applyStaticLabels() {
        if (!currentLangData) return;

        const isRTL = currentLangData.direction === 'rtl';
        document.body.style.direction = isRTL ? 'rtl' : 'ltr';

        const footer = document.querySelector('.footer-info');
        if (footer) {
            footer.style.direction = isRTL ? 'rtl' : 'ltr';
        }

        const setLabel = (id, text) => {
            const el = document.getElementById(id);
            if (el && text) el.innerText = text;
        };

        setLabel('depBtn', currentLangData.departures || "DEPARTURES");
        setLabel('arrBtn', currentLangData.arrivals || "ARRIVALS");
        setLabel('th-time', currentLangData.time || "TIME");
        setLabel('th-flight', currentLangData.flight || "FLIGHT");
        setLabel('th-terminal', currentLangData.terminal || "TERMINAL");
        setLabel('th-airline', currentLangData.airline || "AIRLINE");
        setLabel('th-status', currentLangData.status || "STATUS");
        setLabel('prevBtn', currentLangData.previous || "PREV");
        setLabel('nextBtn', currentLangData.next || "NEXT");
        setLabel('refreshBtn', currentLangData.refresh || "REFRESH");

        updateHeaderLabel();
    }

    function updateHeaderLabel() {
        const header = document.getElementById('headerLabel');
        if (!header) return;
        header.innerText = (currentMode === 'departures') ? (currentLangData?.destination || "DESTINATION") : (currentLangData?.origin || "ORIGIN");
    }

    function buildFlightDataPaths(filename) {
        const paths = [
            // 1. Relative — works best on local HTTP server (127.0.0.1)
            './' + filename,
            filename,
            // 2. Parent-relative — if page is nested deeper
            '../flights/' + filename,
            // 3. Root-relative — fallback for some server configs
            '/flights/' + filename,
            // 4. Root fallback — if JSON is also copied at template root
            '/' + filename
        ];

        // 5. Absolute URL based on current page location (last resort)
        try {
            const loc = window.location.href;
            const base = loc.substring(0, loc.lastIndexOf('/') + 1);
            paths.push(base + filename);
        } catch (e) { }

        // Deduplicate
        return paths.filter((v, i, a) => a.indexOf(v) === i);
    }

    async function loadTableData(isInitial = true, forceRefresh = false) {
        if (window.tvLog) tvLog(`loadTableData start (mode: ${currentMode})`);
        const cacheKey = currentMode === 'departures' ? CACHE_KEY_DEP : CACHE_KEY_ARR;
        const targetFilename = `data_${currentMode}.json`;
        const possiblePaths = buildFlightDataPaths(targetFilename);
        if (window.tvLog) tvLog(`Will try ${possiblePaths.length} paths: ${possiblePaths.slice(0, 2).join(' | ')}`);

        let fetchedSuccess = false;

        for (let path of possiblePaths) {
            try {
                if (window.tvLog) tvLog(`Fetching path: ${path}`);
                const response = await fetch(`${path}?v=${Date.now()}`);
                if (response && response.ok) {
                    if (window.tvLog) tvLog(`Fetch OK: ${path}`);
                    const fileLastModified = response.headers.get('Last-Modified');
                    const fileDate = fileLastModified ? new Date(fileLastModified) : new Date();
                    const now = new Date();

                    if (!forceRefresh && fileLastModified && Math.abs(now - fileDate) > MAX_CACHE_AGE_MS) {
                        triggerBackgroundSync();
                    }

                    let rawData = await response.json();
                    if (!Array.isArray(rawData)) rawData = [];
                    if (window.tvLog) tvLog(`Loaded ${rawData.length} raw flight records`);

                    const currentMinutes = now.getHours() * 60 + now.getMinutes();

                    let data = rawData.map((f, idx) => {
                        const offsetMinutes = (idx * 5) % 360;
                        const totalMins = (currentMinutes + offsetMinutes) % 1440;
                        const hours = String(Math.floor(totalMins / 60)).padStart(2, '0');
                        const mins = String(totalMins % 60).padStart(2, '0');
                        const flightTime = `${hours}:${mins}`;

                        let statusText = f.status || 'Scheduled';
                        if (offsetMinutes < 15) {
                            statusText = 'Boarding';
                        } else if (offsetMinutes > 40 && offsetMinutes < 90) {
                            const delayedMins = totalMins + 15;
                            const dH = String(Math.floor(delayedMins / 60) % 24).padStart(2, '0');
                            const dM = String(delayedMins % 60).padStart(2, '0');
                            statusText = `Estimated ${currentMode === 'departures' ? 'dep' : 'arr'} ${dH}:${dM}`;
                        }

                        return {
                            ...f,
                            time: flightTime,
                            status: statusText
                        };
                    });

                    flightData = data.filter(f => {
                        if (!f || !f.airline) return true;
                        const airline = String(f.airline).toLowerCase();
                        return !airline.includes("cargo") && !airline.includes("blue dart");
                    }).slice(0, fixedMaxFlights);

                    try {
                        localStorage.setItem(cacheKey, JSON.stringify(flightData));
                        localStorage.setItem(CACHE_TIMESTAMP_KEY, now.toISOString());
                    } catch (e) { }

                    if (isInitial) currentPage = 0;
                    renderPage();

                    const lastUpLabel = currentLangData?.last_updated || "Last Refreshed";
                    const lastUpdatedEl = document.getElementById('lastUpdated');
                    if (lastUpdatedEl) {
                        const timeStr = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: true }).toUpperCase();
                        lastUpdatedEl.innerHTML = `<i class="fa-solid fa-rotate-right"></i> ${lastUpLabel}: ${timeStr}`;
                    }

                    removeOfflineBanner();
                    fetchedSuccess = true;
                    if (window.tvLog) tvLog(`Successfully rendered ${flightData.length} flights`);
                    break;
                } else {
                    if (window.tvLog) tvLog(`Fetch NOT OK: ${path} → HTTP ${response ? response.status : 'no response'}`, 'warn');
                }
            } catch (e) {
                if (window.tvLog) tvLog(`Fetch ERROR: ${path} → ${e.message}`, 'error');
                console.warn(`Fetch failed for ${path}:`, e);
            }
        }

        if (fetchedSuccess) return;

        // Fallback to localStorage cache
        try {
            const cachedData = localStorage.getItem(cacheKey);
            const cacheTimestamp = localStorage.getItem(CACHE_TIMESTAMP_KEY);

            if (cachedData) {
                flightData = JSON.parse(cachedData);
                if (isInitial) currentPage = 0;
                renderPage();

                const now = new Date();
                const lastUpLabel = currentLangData?.last_updated || "Last Refreshed";
                const lastUpdatedEl = document.getElementById('lastUpdated');
                if (lastUpdatedEl) {
                    const timeStr = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: true }).toUpperCase();
                    lastUpdatedEl.innerHTML = `<i class="fa-solid fa-rotate-right"></i> ${lastUpLabel}: ${timeStr}`;
                }
                return;
            }
        } catch (e) {
            console.error("Cache parse error:", e);
        }

        // Default fallback array to prevent blank table on slow/offline TVs
        flightData = [
            { time: "18:58", flight: "AI2996", terminal: "T2", airline: "AIR INDIA", city: "NEW DELHI", destination: "NEW DELHI", status: "ON TIME" },
            { time: "19:03", flight: "AI2641", terminal: "T2", airline: "AIR INDIA", city: "BENGALURU", destination: "BENGALURU", status: "ON TIME" },
            { time: "19:08", flight: "6E5047", terminal: "T1", airline: "INDIGO", city: "BENGALURU", destination: "BENGALURU", status: "ON TIME" },
            { time: "19:13", flight: "6E5147", terminal: "T1", airline: "INDIGO", city: "NAGPUR", destination: "NAGPUR", status: "ON TIME" },
            { time: "19:25", flight: "UK985", terminal: "T2", airline: "VISTARA", city: "MUMBAI", destination: "MUMBAI", status: "ON TIME" },
            { time: "19:40", flight: "SG8169", terminal: "T1", airline: "SPICEJET", city: "GOA", destination: "GOA", status: "ON TIME" },
            { time: "19:55", flight: "QP1332", terminal: "T1", airline: "AKASA AIR", city: "HYDERABAD", destination: "HYDERABAD", status: "ON TIME" }
        ];
        if (isInitial) currentPage = 0;
        renderPage();
        showOfflineBanner(null);
    }

    function showOfflineBanner(cacheDate) {
        removeOfflineBanner();
        const banner = document.createElement('div');
        banner.id = 'offline-banner';
        banner.style.cssText = 'position:fixed;top:0;left:0;right:0;background:#ff8c00;color:#000;text-align:center;padding:6px;font-weight:bold;z-index:9999;font-size:1.1rem;';
        if (cacheDate) {
            banner.textContent = `⚠️ Offline Mode — Showing cached flight data`;
        } else {
            banner.textContent = '⚠️ Offline Mode — No cached flight data available';
        }
        document.body.insertBefore(banner, document.body.firstChild);
    }

    function removeOfflineBanner() {
        const existing = document.getElementById('offline-banner');
        if (existing) existing.remove();
    }

    function triggerBackgroundSync() {
        if (window.flutterBridge && typeof window.flutterBridge.syncFlights === 'function') {
            try { window.flutterBridge.syncFlights().catch(() => { }); } catch (e) { }
        }
    }

    function renderPage() {
        const tableBody = document.getElementById('flightBody');
        if (!tableBody) return;

        if (!Array.isArray(flightData) || flightData.length === 0) {
            tableBody.innerHTML = `<tr><td colspan="6" style="text-align:center; padding: 2rem; color: #a0aec0;">No flight data available</td></tr>`;
            return;
        }

        const start = currentPage * rowsPerPage;
        const pageData = flightData.slice(start, start + rowsPerPage);

        let html = "";
        pageData.forEach(f => {
            if (!f) return;
            let rawCity = f.city ? String(f.city).trim() : "Unknown";
            let searchCity = rawCity;
            const upperCity = rawCity.toUpperCase();

            if (upperCity.includes("NEWARK") || upperCity.includes("LIBERTY")) {
                searchCity = "Newark";
            } else if (upperCity.includes("KENNEDY") || upperCity.includes("JFK")) {
                searchCity = "New York";
            } else if (upperCity.includes("MALE") && upperCity.includes("VELANA")) {
                searchCity = "Male";
            } else if (upperCity.includes("DUBAI") && (upperCity.includes("WORLD") || upperCity.includes("CENTRAL"))) {
                searchCity = "Dubai";
            } else if (upperCity.includes("NAGPUR")) {
                searchCity = "Nagpur";
            } else if (upperCity.includes("HEATHROW")) {
                searchCity = "London Heathrow";
            } else if (upperCity.includes("GATWICK")) {
                searchCity = "London Gatwick";
            } else if (upperCity.includes("MANOHAR") || upperCity.includes("MOPA")) {
                searchCity = "Goa Mopa";
            } else if (upperCity.includes("DABOLIM")) {
                searchCity = "Goa Dabolim";
            } else {
                const dualCities = ["LONDON", "NEW YORK", "TOKYO", "DUBAI", "GOA", "MALE"];
                const isDual = dualCities.some(c => upperCity.includes(c));

                if (!isDual) {
                    searchCity = rawCity.split(/\s+(?:AIRPORT|INTL|INT'L|INTERNATIONAL|INDIRA|RAJIV|GANDHI|CHHATRAPATI|ZAYED|CHANGI|JOMO|HEYDAR|CHARLES|KING|BANDARANAIKE|BOLE|HAMAD|KEMPEGOWDA|NETAJI|SUBHAS|CHAUDHARY|DR\.|WUXU|TIANFU|WORLD|CENTRAL|SCHIPHOL|SIR|CHANDRA|BOSE|PRINCE|MOHAMMAD|CHOPIN|SEEWOOSAGUR|RAMGOOLAM)\b/i)[0].trim();
                }
            }

            let displayCity = getLocalName(searchCity, cityTranslations);

            const langFile = localStorage.getItem('selectedLangFile') || 'english.json';
            if (langFile === 'english.json') {
                if (upperCity.includes("KENNEDY") || upperCity.includes("JFK")) {
                    displayCity = "NEW YORK JFK";
                }
            }

            const airlineName = f.airline ? String(f.airline).split('(')[0].trim() : "Unknown";
            const displayAirline = getLocalName(airlineName, airlineTranslations);

            let statusText = (currentLangData?.on_time) || "On Time";
            let statusClass = "status-ontime";
            const timeMatch = f.status ? String(f.status).match(/(\d{2}:\d{2})/) : null;

            if (f.status && String(f.status).toLowerCase().includes("cancel")) {
                statusText = (currentLangData?.cancelled) || "Cancelled";
                statusClass = "status-cancelled";
            } else if (timeMatch && timeMatch[0] > (f.time || "")) {
                statusText = `${(currentLangData?.delayed) || "Delayed"} (${timeMatch[0]})`;
                statusClass = "status-delayed";
            }

            let term = f.terminal ? String(f.terminal).toUpperCase() : "-";
            if (term !== "-" && !term.startsWith("T")) term = "T" + term;

            const flightNo = f.flight ? String(f.flight).substring(0, 7) : "N/A";

            html += `<tr>
                <td style="color: #ffa500; font-weight: 800;">${f.time || '--:--'}</td>
                <td><b>${flightNo}</b></td>
                <td style="text-align:center;">${term}</td>
                <td>${displayAirline}</td>
                <td>${displayCity}</td>
                <td style="text-align:center;"><span class="status-badge ${statusClass}">${statusText}</span></td>
            </tr>`;
        });

        tableBody.innerHTML = html;
    }

    // Expose module API
    window.FlightModule = {
        loadTableData,
        loadFlightTranslations,
        renderPage,
        getCurrentMode: () => currentMode,
        setCurrentMode: (mode) => { currentMode = mode; },
        triggerBackgroundSync,
        getFlightData: () => flightData,
        getCurrentPage: () => currentPage,
        setCurrentPage: (page) => { currentPage = page; },
        navMap
    };

    window.loadFlightTranslations = loadFlightTranslations;
    window.navMap = navMap;

    window.currentMode = currentMode;
    try {
        Object.defineProperty(window, 'currentMode', {
            get: () => currentMode,
            set: (val) => { currentMode = val; }
        });
    } catch (e) { }

})();

// Navigation handlers for Remote Control / Mouse
document.addEventListener('keydown', (e) => {
    const activeEl = document.activeElement;
    if (!activeEl) return;
    const id = activeEl.id;
    if (id === 'backBtn' && (e.key === "Enter" || e.keyCode === 13)) {
        window.location.href = '../index.html';
        return;
    }
    const nav = window.FlightModule ? window.FlightModule.navMap : null;
    if (!nav || !nav[id]) return;

    if (e.key && e.key.startsWith("Arrow")) {
        e.preventDefault();
        let dir = e.key.replace("Arrow", "").toLowerCase();

        const isRTL = document.body.style.direction === 'rtl';

        if (isRTL) {
            if (dir === "left") dir = "right";
            else if (dir === "right") dir = "left";
        }

        const targetId = nav[id][dir];
        if (targetId) {
            const el = document.getElementById(targetId);
            if (el) el.focus();
        }
    }

    if (e.key === "Enter" || e.keyCode === 13) {
        e.preventDefault();
        const flightData = window.FlightModule.getFlightData();
        const currentPage = window.FlightModule.getCurrentPage();
        const rowsPerPage = 7;

        if (id === "nextBtn") {
            const totalPages = Math.ceil(flightData.length / rowsPerPage);
            if (currentPage < (totalPages - 1)) {
                window.FlightModule.setCurrentPage(currentPage + 1);
                window.FlightModule.renderPage();
            }
        } else if (id === "prevBtn") {
            if (currentPage > 0) {
                window.FlightModule.setCurrentPage(currentPage - 1);
                window.FlightModule.renderPage();
            }
        } else if (id === "depBtn" || id === "arrBtn") {
            const newMode = (id === "depBtn") ? 'departures' : 'arrivals';
            document.getElementById('depBtn').classList.toggle('active', id === "depBtn");
            document.getElementById('arrBtn').classList.toggle('active', id === "arrBtn");
            window.FlightModule.setCurrentMode(newMode);
            window.FlightModule.loadTableData(true);
        } else if (id === "refreshBtn") {
            const rBtn = document.getElementById('refreshBtn');
            const icon = rBtn ? rBtn.querySelector('i') : null;
            if (icon) icon.classList.add('fa-spin');
            window.FlightModule.loadTableData(true, true);
            setTimeout(() => {
                if (icon) icon.classList.remove('fa-spin');
            }, 600);
        }
    }
});

async function initFlightApp() {
    if (window.FlightModule) {
        window.FlightModule.loadFlightTranslations();
        window.FlightModule.setCurrentMode('departures');
    }

    const depBtn = document.getElementById('depBtn');
    const arrBtn = document.getElementById('arrBtn');
    const prevBtn = document.getElementById('prevBtn');
    const nextBtn = document.getElementById('nextBtn');
    const refreshBtn = document.getElementById('refreshBtn');

    if (depBtn) depBtn.classList.add('active');
    if (arrBtn) arrBtn.classList.remove('active');

    if (window.FlightModule) {
        await window.FlightModule.loadTableData(true);
    }

    if (depBtn) {
        depBtn.addEventListener('click', () => {
            depBtn.classList.add('active');
            if (arrBtn) arrBtn.classList.remove('active');
            if (window.FlightModule) {
                window.FlightModule.setCurrentMode('departures');
                window.FlightModule.loadTableData(true);
            }
        });
    }

    if (arrBtn) {
        arrBtn.addEventListener('click', () => {
            arrBtn.classList.add('active');
            if (depBtn) depBtn.classList.remove('active');
            if (window.FlightModule) {
                window.FlightModule.setCurrentMode('arrivals');
                window.FlightModule.loadTableData(true);
            }
        });
    }

    if (prevBtn) {
        prevBtn.addEventListener('click', () => {
            if (window.FlightModule) {
                const currentPage = window.FlightModule.getCurrentPage();
                if (currentPage > 0) {
                    window.FlightModule.setCurrentPage(currentPage - 1);
                    window.FlightModule.renderPage();
                }
            }
        });
    }

    if (nextBtn) {
        nextBtn.addEventListener('click', () => {
            if (window.FlightModule) {
                const flightData = window.FlightModule.getFlightData();
                const currentPage = window.FlightModule.getCurrentPage();
                const totalPages = Math.ceil(flightData.length / 7);
                if (currentPage < (totalPages - 1)) {
                    window.FlightModule.setCurrentPage(currentPage + 1);
                    window.FlightModule.renderPage();
                }
            }
        });
    }

    if (refreshBtn) {
        refreshBtn.addEventListener('click', () => {
            const icon = refreshBtn.querySelector('i');
            if (icon) icon.classList.add('fa-spin');
            if (window.FlightModule) {
                window.FlightModule.loadTableData(true, true);
            }
            setTimeout(() => {
                if (icon) icon.classList.remove('fa-spin');
            }, 600);
        });
    }

    if (window.TVCore && typeof window.TVCore.fetchHotelConfig === 'function') {
        window.TVCore.fetchHotelConfig().then(config => {
            if (!TVCore.checkPlanExpiredRedirect(config)) {
                TVCore.initBackgroundSlider(config);
            }
        }).catch(e => console.warn("Hotel config background load:", e));
    }

    if (depBtn) depBtn.focus();
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initFlightApp);
} else {
    initFlightApp();
}

// Temporary On-Screen TV Debugger (Hidden — change display to 'block' to show)
(function setupTVDebugger() {
    if (document.getElementById('tv-debug-console')) return;
    const debugBox = document.createElement('div');
    debugBox.id = 'tv-debug-console';
    debugBox.style.cssText = 'display:none;position:fixed;bottom:10px;left:10px;right:10px;max-height:160px;overflow-y:auto;background:rgba(0,0,0,0.85);color:#00ff66;font-family:monospace;font-size:11px;padding:8px;border:1px solid #00ff66;border-radius:6px;z-index:99999;pointer-events:none;box-shadow:0 0 10px rgba(0,0,0,0.8);';
    debugBox.innerHTML = '<div style="font-weight:bold;color:#ffcc00;border-bottom:1px solid #555;padding-bottom:2px;margin-bottom:4px;">🔍 TV DEBUG LOGS (Temporary)</div>';

    function appendLog(msg, type = 'info') {
        const line = document.createElement('div');
        const color = type === 'error' ? '#ff4444' : type === 'warn' ? '#ffbb00' : '#00ff66';
        const time = new Date().toLocaleTimeString();
        line.style.color = color;
        line.innerHTML = `[${time}] ${msg}`;
        debugBox.appendChild(line);
        debugBox.scrollTop = debugBox.scrollHeight;
    }

    window.tvLog = appendLog;
    document.addEventListener('DOMContentLoaded', () => {
        document.body.appendChild(debugBox);
        tvLog('TV Debugger Mounted Ready');
    });
    if (document.body) {
        document.body.appendChild(debugBox);
        tvLog('TV Debugger Mounted Ready');
    }

    window.addEventListener('error', (e) => {
        appendLog(`JS CRASH: ${e.message} @ line ${e.lineno}:${e.colno}`, 'error');
    });

    window.addEventListener('unhandledrejection', (e) => {
        appendLog(`PROMISE FAIL: ${e.reason}`, 'error');
    });
})();

window.onTVBack = function () { window.location.href = '../index.html'; return true; };
