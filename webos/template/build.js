/**
 * Unified Automated Build & Package Script for TV Template v2.0.1
 * 
 * Features:
 * 1. Syncs & inlines components into index.html (100% offline, zero-latency).
 * 2. Transpiles JS files to ES2018 (Chrome 65 / TV-safe, zero ?. or ?? syntax errors).
 * 3. Compiles static Tailwind CSS (tailwind.min.css).
 * 4. Exports clean production build to ../build_output/tv_template_v2.0.1/
 * 5. Generates ready-to-upload ZIP file at ../build_output/tv_template_v2.0.1.zip
 * 6. Automatically opens the build_output folder in Windows Explorer!
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const rootDir = __dirname;
const parentDir = path.resolve(rootDir, '..');
const outDir = path.join(parentDir, 'build_output');
const outTemplateDir = path.join(outDir, 'tv_template_v2.0.1');
const zipFilePath = path.join(outDir, 'tv_template_v2.0.1.zip');

const compDir = path.join(rootDir, 'components');
const jsDir = path.join(rootDir, 'assets/js');
const cssDir = path.join(rootDir, 'assets/css');

console.log('===============================================================');
console.log('  Hotel TV Template v2.0.1 - Automated Build & Packager');
console.log('===============================================================\n');

// -------------------------------------------------------------
// STEP 1: Sync & Embed Components into index.html
// -------------------------------------------------------------
if (fs.existsSync(compDir)) {
    console.log('📦 Step 1: Syncing and embedding components into index.html...');
    const readComp = (name) => {
        const filePath = path.join(compDir, name);
        if (!fs.existsSync(filePath)) return '';
        let content = fs.readFileSync(filePath, 'utf8').trim();
        // Clean optional chaining inside HTML expressions
        content = content.replace(/document\.getElementById\('tv-header-back-btn'\)\?\.blur\(\)/g, "(document.getElementById('tv-header-back-btn') && document.getElementById('tv-header-back-btn').blur())");
        content = content.replace(/document\.getElementById\('tv-header-back-btn'\)\?\.focus\(\)/g, "(document.getElementById('tv-header-back-btn') && document.getElementById('tv-header-back-btn').focus())");
        content = content.replace(/weatherData\.daily\[0\]\?\.sunrise/g, "(weatherData.daily && weatherData.daily[0] ? weatherData.daily[0].sunrise : '')");
        content = content.replace(/weatherData\.daily\[0\]\?\.sunset/g, "(weatherData.daily && weatherData.daily[0] ? weatherData.daily[0].sunset : '')");
        content = content.replace(/roomNo \|\| hotelData\?\.device\?\.room_no/g, "roomNo || (hotelData && hotelData.device ? hotelData.device.room_no : '')");
        content = content.replace(/hotelData\?\.device\?\.ip_address/g, '(hotelData && hotelData.device && hotelData.device.ip_address)');
        content = content.replace(/hotelData\.device\?\.device_id/g, "(hotelData.device ? hotelData.device.device_id : '')");
        content = content.replace(/hotelData\.hotel\?\.hotel_location/g, "(hotelData.hotel ? hotelData.hotel.hotel_location : '')");
        content = content.replace(/primaryAirportData\?\.iata_code/g, "(primaryAirportData ? primaryAirportData.iata_code : '')");
        content = content.replace(/secondaryAirportData\?\.iata_code/g, "(secondaryAirportData ? secondaryAirportData.iata_code : '')");
        return content;
    };

    function addCloak(html) {
        if (!html || html.includes('x-cloak')) return html;
        return html.replace(/<([a-zA-Z0-9\-]+)(\s)/, '<$1 x-cloak$2');
    }

    const headerContent = readComp('header.html');
    const greetingContent = readComp('greeting.html');
    const infoPanelContent = readComp('info_panel.html');
    const languagesContent = readComp('languages.html');
    const applicationsContent = readComp('applications.html');
    const screenCastContent = readComp('screen_cast.html');
    const weatherContent = readComp('weather.html');
    const inputContent = readComp('input.html');
    const settingsContent = readComp('settings.html');
    const flightsContent = readComp('flights.html');
    const menuSliderContent = readComp('menu_slider.html');

    const newIndexHtml = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=1920, initial-scale=1.0, minimum-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>TV Template v2.0.1</title>

    <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><rect width='100' height='100' rx='20' fill='%23eab308'/><text y='.75em' x='50%' font-size='60' text-anchor='middle'>📺</text></svg>">

    <link rel="stylesheet" href="assets/css/tailwind.min.css">
    <link rel="stylesheet" href="assets/css/custom.css">
    <script src="assets/js/webOSTV.js"></script>
    <script src="assets/js/webos-device.js"></script>
    <script src="assets/js/bridge.js"></script>
    <script src="assets/js/remote.js"></script>
    <script src="assets/js/dataService.js"></script>
    <script src="assets/js/languagesData.js"></script>
    <script src="assets/js/menuData.js"></script>
    <script src="assets/js/applications.js"></script>
    <script src="assets/js/screenCast.js"></script>
    <script src="assets/js/weather.js"></script>
    <script src="assets/js/inputController.js"></script>
    <script src="assets/js/settingsController.js"></script>
    <script src="assets/js/flights.js"></script>
    <script src="assets/js/app.js"></script>
    <script defer src="assets/js/alpine.min.js"></script>

    <script>
        // Strict TV Kiosk Canvas Lock: Block all browser zoom keyboard shortcuts & mouse gestures
        (function() {
            function blockBrowserZoom(e) {
                if (e.ctrlKey || e.metaKey) {
                    var k = e.key;
                    var c = e.code;
                    if (
                        k === '+' || k === '=' || k === '-' || k === '_' || k === '0' ||
                        c === 'NumpadAdd' || c === 'NumpadSubtract' || c === 'Equal' || c === 'Minus' || c === 'Digit0'
                    ) {
                        e.preventDefault();
                        e.stopPropagation();
                        e.stopImmediatePropagation();
                        return false;
                    }
                }
            }
            window.addEventListener('keydown', blockBrowserZoom, { capture: true, passive: false });
            window.addEventListener('wheel', function(e) {
                if (e.ctrlKey || e.metaKey) {
                    e.preventDefault();
                    e.stopPropagation();
                    e.stopImmediatePropagation();
                    return false;
                }
            }, { capture: true, passive: false });
            document.addEventListener('gesturestart', function(e) { e.preventDefault(); }, { passive: false });
            document.addEventListener('gesturechange', function(e) { e.preventDefault(); }, { passive: false });
            document.addEventListener('gestureend', function(e) { e.preventDefault(); }, { passive: false });
        })();

        function scaleCanvas() {
            var canvas = document.getElementById('tv-canvas');
            if (!canvas) return;
            var targetW = 1920;
            var targetH = 1080;
            var scale = Math.min(window.innerWidth / targetW, window.innerHeight / targetH);
            canvas.style.transform = 'translate(-50%, -50%) scale(' + scale + ')';
        }
        window.addEventListener('resize', scaleCanvas);
        window.addEventListener('orientationchange', scaleCanvas);
        window.addEventListener('fullscreenchange', scaleCanvas);
        window.addEventListener('DOMContentLoaded', scaleCanvas);
    </script>
</head>

<body class="bg-black select-none overflow-hidden m-0 p-0 font-sans" x-data="tvApp()" x-init="init()">

    <div id="tv-canvas" class="relative text-white font-sans overflow-hidden bg-black flex flex-col justify-between"
         @keydown.window="handleGlobalKeys($event)">

        <div class="absolute inset-0 bg-black z-50 pointer-events-none transition-opacity duration-1000 ease-out"
             :class="isLoaded ? 'opacity-0' : 'opacity-100'"
             style="will-change: opacity;">
        </div>

        <div class="absolute inset-0 z-0 overflow-hidden pointer-events-none">
            <template x-for="(img, index) in sliderImages" :key="index">
                <div class="absolute inset-0 bg-cover bg-center transition-all duration-1000 ease-in-out"
                     :style="{ backgroundImage: 'url(' + img + ')' }"
                     :class="activeSlideIndex === index ? 'opacity-100 scale-100' : 'opacity-0 scale-105'"
                     style="will-change: opacity, transform;">
                </div>
            </template>
            <div class="absolute inset-0 bg-gradient-to-b from-black/40 via-transparent to-black/60"></div>
        </div>

        <!-- Top Header Component -->
        <div class="w-full relative z-30">
${headerContent}
        </div>

        <!-- Home Greeting Component -->
        <div x-show="currentView === 'home'" 
             x-cloak
             x-transition:enter="transition ease-out duration-300"
             x-transition:enter-start="opacity-0"
             x-transition:enter-end="opacity-100"
             class="w-full relative z-20">
${greetingContent}
        </div>

        <!-- Shared Info Panel Component (Hotel Info, Room Info, Amenities, Our City) -->
${addCloak(infoPanelContent)}

        <!-- Languages Component -->
${addCloak(languagesContent)}

        <!-- Applications / OTT Apps Screen -->
${addCloak(applicationsContent)}

        <!-- Screen Cast Screen -->
        <div x-show="['screen_cast', 'cast'].includes(currentView)"
             x-cloak
             class="w-full flex-1 flex flex-col items-center justify-center">
${screenCastContent}
        </div>

        <!-- Weather Screen -->
        <div x-show="['weather'].includes(currentView)"
             x-cloak
             class="w-full flex-1 flex flex-col items-center justify-center">
${weatherContent}
        </div>

        <!-- TV Input / HDMI Ports Screen -->
        <div x-show="['input', 'inputs', 'hdmi'].includes(currentView)"
             x-cloak
             class="w-full flex-1 flex flex-col items-center justify-start px-12 pt-4 pb-6">
${inputContent}
        </div>

        <!-- Settings / Admin Screen -->
        <div x-show="['settings', 'admin'].includes(currentView)"
             x-cloak
             class="w-full flex-1 flex flex-col items-center justify-center px-12 pt-2 pb-4">
${settingsContent}
        </div>

        <!-- Real-Time Airport Flights Screen -->
        <div x-show="['flights', 'flight'].includes(currentView)"
             x-cloak
             class="w-full flex-1 flex flex-col items-center justify-start px-12 pt-2 pb-4">
${flightsContent}
        </div>

        <!-- Dynamic Middle Viewport (Fallback When opening undefined detail screens) -->
        <div x-show="currentView !== 'home' && !['hotel_info', 'room_info', 'amenities', 'our_city', 'ourcity', 'language', 'languages', 'apps', 'applications', 'screen_cast', 'cast', 'weather', 'input', 'inputs', 'hdmi', 'settings', 'admin', 'flights', 'flight'].includes(currentView)"
             x-cloak
             x-transition:enter="transition ease-out duration-300"
             x-transition:enter-start="opacity-0 scale-95"
             x-transition:enter-end="opacity-100 scale-100"
             class="relative z-10 flex-1 flex flex-col justify-center items-center px-16 w-full">
            
            <div class="glass-card px-12 py-8 rounded-3xl text-center space-y-4 shadow-2xl border border-white/10 max-w-2xl">
                <div class="inline-flex items-center space-x-2 px-4 py-1.5 rounded-full bg-amber-500/20 text-amber-400 text-xs font-bold uppercase tracking-wider">
                    <span>Screen Active</span>
                </div>
                <h1 class="text-4xl font-extrabold text-white uppercase tracking-wide" x-text="currentView ? currentView.replace(/_/g, ' ') : ''"></h1>
                <p class="text-slate-300 text-lg">Screen details will be rendered here.</p>
                <button @click="goBack()" class="px-6 py-2 rounded-full bg-black border-2 border-[#caa44d] text-white font-extrabold hover:bg-[#ffc700] hover:text-black transition cursor-pointer">
                    ← BACK
                </button>
            </div>
        </div>

        <div x-show="currentView === 'home'" x-cloak class="flex-1"></div>

        <!-- Bottom Menu Slider (Flips seamlessly in place on Home Page) -->
        <div x-show="currentView === 'home'" 
             x-cloak
             x-transition:enter="transition ease-out duration-300"
             x-transition:enter-start="opacity-0 translate-y-4"
             x-transition:enter-end="opacity-100 translate-y-0"
             class="w-full relative z-30">
${menuSliderContent}
        </div>

        <!-- Global TV Toast Feedback Notification -->
        <div x-show="toastMessage"
             x-cloak
             x-transition:enter="transition ease-out duration-300 transform"
             x-transition:enter-start="opacity-0 translate-y-8 scale-95"
             x-transition:enter-end="opacity-100 translate-y-0 scale-100"
             x-transition:leave="transition ease-in duration-200 transform"
             x-transition:leave-start="opacity-100 translate-y-0 scale-100"
             x-transition:leave-end="opacity-0 translate-y-8 scale-95"
             class="fixed bottom-12 left-1/2 -translate-x-1/2 z-50 pointer-events-none">
            <div class="px-8 py-3.5 rounded-2xl bg-black/95 border-2 border-[#ffc700] text-amber-300 font-black text-lg shadow-[0_10px_35px_rgba(0,0,0,0.9),0_0_25px_rgba(255,199,0,0.4)] flex items-center gap-3 backdrop-blur-xl">
                <span class="text-2xl">⚠️</span>
                <span x-text="toastMessage"></span>
            </div>
        </div>

    </div>

    
    <!-- Comprehensive TV Back Key Handler (LG webOS: 461, Tizen: 10009, Escape: 27, Backspace: 8, webOSBack event & postMessage) -->
    <script>
        (function() {
            function triggerAppBack() {
                console.log('[Template] Remote Back action triggered');
                try {
                    if (window.tvAppInstance && typeof window.tvAppInstance.goBack === 'function') {
                        window.tvAppInstance.goBack();
                        return true;
                    }
                } catch (e) {
                    console.warn('[Template] Error executing goBack:', e);
                }
                return false;
            }

            // 1. Direct Keydown Listener (Capture phase to run before any other script)
            window.addEventListener('keydown', function(event) {
                var code = event.keyCode || event.which;
                if (code === 461 || code === 10009 || code === 27 || code === 8) {
                    if (code === 8 && (document.activeElement.tagName === 'INPUT' || document.activeElement.tagName === 'TEXTAREA')) {
                        return;
                    }
                    event.preventDefault();
                    event.stopPropagation();
                    event.stopImmediatePropagation();
                    console.log('[Template] Back key intercepted (' + code + ')');
                    triggerAppBack();
                    return false;
                }
            }, true);

            // 2. PostMessage Listener from parent webOS wrapper
            window.addEventListener('message', function(event) {
                if (event && event.data && event.data.type === 'TV_BACK_KEY') {
                    console.log('[Template] TV_BACK_KEY received via postMessage');
                    triggerAppBack();
                }
            });

            // 3. LG webOS platform back events
            window.addEventListener('webOSBack', function(e) {
                console.log('[Template] webOSBack event on window');
                if (e && e.preventDefault) e.preventDefault();
                triggerAppBack();
            });

            document.addEventListener('webOSBack', function(e) {
                console.log('[Template] webOSBack event on document');
                if (e && e.preventDefault) e.preventDefault();
                triggerAppBack();
            });
        })();
    </script>

    <!-- Prevent browser zoom via keyboard or mouse wheel -->
    <script>
        document.addEventListener('keydown', function(event) {
            if (event.ctrlKey && (event.key === '=' || event.key === '-' || event.key === '+' || event.key === '0')) {
                event.preventDefault();
            }
        });
        document.addEventListener('wheel', function(event) {
            if (event.ctrlKey) {
                event.preventDefault();
            }
        }, { passive: false });
    </script>
</body>
</html>`;

    fs.writeFileSync(path.join(rootDir, 'index.html'), newIndexHtml, 'utf8');
    console.log('   ✓ Embedded 11 components into index.html cleanly.');
}

// -------------------------------------------------------------
// STEP 2: Transpile JS to ES2018 (Chrome 65 / TV-safe)
// -------------------------------------------------------------
console.log('\n⚙️  Step 2: Transpiling JS files to TV-safe ES6 standard (target=es2018)...');
const jsFiles = [
    'bridge.js', 'remote.js', 'dataService.js', 'languagesData.js',
    'menuData.js', 'applications.js', 'screenCast.js', 'weather.js',
    'inputController.js', 'settingsController.js', 'flights.js', 'app.js'
];

for (const file of jsFiles) {
    const fPath = path.join(jsDir, file);
    if (fs.existsSync(fPath)) {
        try {
            execSync(`& 'C:\\Program Files\\nodejs\\npx.cmd' -y esbuild "${fPath}" --target=es2018 --outfile="${fPath}" --allow-overwrite`, { shell: 'powershell.exe', stdio: 'pipe' });
            console.log(`   ✓ Transpiled ${file}`);
        } catch (err) {
            console.error(`   ✗ Error transpiling ${file}:`, err.message);
        }
    }
}

// -------------------------------------------------------------
// STEP 3: Rebuild Static Tailwind CSS
// -------------------------------------------------------------
console.log('\n🎨 Step 3: Compiling static Tailwind CSS (tailwind.min.css)...');
const tempConfig = path.join(rootDir, 'tailwind.config.js');
const tempInput = path.join(cssDir, 'input.css');

fs.writeFileSync(tempConfig, `module.exports = {
  content: ["./index.html", "./assets/js/**/*.js"],
  theme: {
    screens: { 'sm': '480px', 'md': '640px', 'lg': '800px', 'xl': '1024px', '2xl': '1280px' },
    extend: { fontFamily: { sans: ['Poppins', 'sans-serif'] } }
  },
  plugins: []
};`, 'utf8');

fs.writeFileSync(tempInput, `@tailwind base;\n@tailwind components;\n@tailwind utilities;\n`, 'utf8');

try {
    execSync(`& 'C:\\Program Files\\nodejs\\npx.cmd' -y tailwindcss@3.4.17 -i "${tempInput}" -o "${path.join(cssDir, 'tailwind.min.css')}" --minify -c "${tempConfig}"`, { shell: 'powershell.exe', stdio: 'pipe' });
    console.log('   ✓ Generated assets/css/tailwind.min.css successfully.');
} catch (err) {
    console.error('   ✗ Error building Tailwind CSS:', err.message);
} finally {
    try { fs.unlinkSync(tempConfig); } catch (_) {}
    try { fs.unlinkSync(tempInput); } catch (_) {}
}

// -------------------------------------------------------------
// STEP 4: Export to Production Folder & Create ZIP
// -------------------------------------------------------------
console.log('\n📦 Step 4: Exporting clean production build and creating ZIP package...');

// Ensure output directories exist
if (!fs.existsSync(outDir)) {
    fs.mkdirSync(outDir, { recursive: true });
}
if (fs.existsSync(outTemplateDir)) {
    fs.rmSync(outTemplateDir, { recursive: true, force: true });
}
fs.mkdirSync(outTemplateDir, { recursive: true });

// Copy only clean production files
function copyDirRecursive(src, dest) {
    fs.mkdirSync(dest, { recursive: true });
    for (const item of fs.readdirSync(src)) {
        // Exclude development/source-only items
        if (item === '.git' || item === 'node_modules' || item.endsWith('.zip') || item === 'tailwind.config.js' || item === 'input.css') {
            continue;
        }
        const srcPath = path.join(src, item);
        const destPath = path.join(dest, item);
        if (fs.statSync(srcPath).isDirectory()) {
            copyDirRecursive(srcPath, destPath);
        } else {
            fs.copyFileSync(srcPath, destPath);
        }
    }
}

// Copy source items into outTemplateDir (data.json excluded from server ZIP)
const itemsToExport = ['index.html', 'assets', 'languages', 'components'];
for (const item of itemsToExport) {
    const srcPath = path.join(rootDir, item);
    const destPath = path.join(outTemplateDir, item);
    if (fs.existsSync(srcPath)) {
        if (fs.statSync(srcPath).isDirectory()) {
            copyDirRecursive(srcPath, destPath);
        } else {
            fs.copyFileSync(srcPath, destPath);
        }
    }
}

// Also exclude tailwind.js from production assets/js if it exists
const prodTailwindJs = path.join(outTemplateDir, 'assets/js/tailwind.js');
if (fs.existsSync(prodTailwindJs)) {
    try { fs.unlinkSync(prodTailwindJs); } catch (_) {}
}

console.log(`   ✓ Clean production files copied to: ${outTemplateDir}`);

// Delete old zip if exists
if (fs.existsSync(zipFilePath)) {
    try { fs.unlinkSync(zipFilePath); } catch (_) {}
}

// Compress using PowerShell
try {
    const zipCmd = `powershell.exe -Command "Compress-Archive -Path '${outTemplateDir}\\*' -DestinationPath '${zipFilePath}' -Force"`;
    execSync(zipCmd, { stdio: 'pipe' });
    const stats = fs.statSync(zipFilePath);
    const sizeMb = (stats.size / (1024 * 1024)).toFixed(2);
    console.log(`   ✓ Successfully generated ZIP: ${zipFilePath} (${sizeMb} MB)`);
} catch (zipErr) {
    console.error('   ✗ Failed to create zip archive:', zipErr.message);
}

// Open the folder in Windows Explorer
try {
    execSync(`explorer.exe "${outDir}"`);
} catch (_) {}

console.log('\n===============================================================');
console.log('✅ BUILD & PACKAGING COMPLETE!');
console.log(`📁 Upload this ZIP to server: ${zipFilePath}`);
console.log('===============================================================\n');
