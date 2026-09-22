let images = [];
let currentIndex = 0;
let autoTimer;

function waitForLoginData() {
    return new Promise(resolve => {
        if (window.tvLoginData) return resolve(window.tvLoginData);
        if (window.parent && window.parent.tvLoginData) return resolve(window.parent.tvLoginData);

        // Check local storage cache immediately
        const cached = localStorage.getItem('cachedHotelData');
        if (cached) {
            try { return resolve(JSON.parse(cached)); } catch (e) { }
        }

        const check = setInterval(() => {
            const data = window.tvLoginData || (window.parent && window.parent.tvLoginData);
            if (data) {
                clearInterval(check);
                resolve(data);
            }
        }, 100);

        // Increase timeout from 3000ms to 8000ms for slow TV hardware
        setTimeout(() => { clearInterval(check); resolve(null); }, 8000);
    });
}

async function fetchHotelConfig() {
    const injected = await waitForLoginData();
    if (injected) {
        var normalized = injected.data || injected;
        localStorage.setItem('cachedHotelData', JSON.stringify(normalized));
        return normalized;
    }

    const filename = window.parent.HOTEL_DATA_FILE || window.HOTEL_DATA_FILE || 'data.json';
    const paths = [`../${filename}`, filename, '../data.json', 'data.json'];
    let config = null;

    for (let path of paths) {
        try {
            const res = await fetch(`${path}?t=${Date.now()}`);
            if (res.ok) {
                config = await res.json();
                config = config.data || config;
                localStorage.setItem('cachedHotelData', JSON.stringify(config));
                break;
            }
        } catch (e) {
            console.warn(`Failed to fetch config from ${path}:`, e);
        }
    }

    if (!config) {
        const cached = localStorage.getItem('cachedHotelData');
        if (cached) {
            try {
                config = JSON.parse(cached);
            } catch (e) {
                console.error("Failed parsing cached config:", e);
            }
        }
    }
    return config;
}

let bgSlideImages = [];
let bgCurrentImageIndex = 0;
let bgActiveSlideIndex = 0;
let bgSliderIntervalId = null;

function initBackgroundSlider(config) {
    if (bgSliderIntervalId) clearInterval(bgSliderIntervalId);
    bgSlideImages = [];

    const isInSubfolder = window.location.pathname.indexOf('/') !== window.location.pathname.lastIndexOf('/');
    const basePath = isInSubfolder ? '../' : '';

    if (config && config.hotel && config.hotel.media) {
        if (config.hotel.media.slider_images && config.hotel.media.slider_images.length > 0) {
            bgSlideImages = config.hotel.media.slider_images.map(img => {
                return (img.startsWith('http') || img.startsWith('/')) ? img : basePath + img;
            });
        } else if (config.hotel.media.cover_image) {
            let cover = config.hotel.media.cover_image;
            if (!cover.startsWith('http') && !cover.startsWith('/')) {
                cover = basePath + cover;
            }
            bgSlideImages = [cover];
        }
    }

    if (bgSlideImages.length === 0) {
        bgSlideImages = ['../images/main.jpg'];
    }

    const slides = document.querySelectorAll('#bg-slider .slide');
    if (slides.length < 2) return;

    const tempImg1 = new Image();
    tempImg1.onload = () => {
        slides[0].style.backgroundImage = `url('${bgSlideImages[0]}')`;
        slides[0].classList.add('active');
        slides[1].classList.remove('active');
    };
    tempImg1.onerror = () => {
        slides[0].style.backgroundImage = "url('../images/main.jpg')";
        slides[0].classList.add('active');
        slides[1].classList.remove('active');
    };
    tempImg1.src = bgSlideImages[0];

    bgCurrentImageIndex = 0;
    bgActiveSlideIndex = 0;

    if (bgSlideImages.length > 1) {
        bgSliderIntervalId = setInterval(() => {
            bgCurrentImageIndex = (bgCurrentImageIndex + 1) % bgSlideImages.length;
            const nextSlideIndex = bgActiveSlideIndex === 0 ? 1 : 0;
            const targetUrl = bgSlideImages[bgCurrentImageIndex];

            const tempImgNext = new Image();
            tempImgNext.onload = () => {
                slides[nextSlideIndex].style.backgroundImage = `url('${targetUrl}')`;
                slides[nextSlideIndex].classList.add('active');
                slides[bgActiveSlideIndex].classList.remove('active');
                bgActiveSlideIndex = nextSlideIndex;
            };
            tempImgNext.onerror = () => {
                slides[nextSlideIndex].style.backgroundImage = "url('../images/main.jpg')";
                slides[nextSlideIndex].classList.add('active');
                slides[bgActiveSlideIndex].classList.remove('active');
                bgActiveSlideIndex = nextSlideIndex;
            };
            tempImgNext.src = targetUrl;
        }, 5000);
    }
}

function extractRoomInfo(config) {
    if (!config) return [];
    let list = [];

    const root = config.data || config;

    // Read room_info array from data.json or config object
    if (root.room_info && Array.isArray(root.room_info) && root.room_info.length > 0) {
        list = root.room_info
            .filter(item => item && (item.image_url || item.url || item.image))
            .map(item => ({
                title: item.title || 'Room Info',
                description: item.description || '',
                image_url: item.image_url || item.url || item.image
            }));
    }

    return list;
}

async function initGallery() {
    images = [];

    const isInSubfolder = window.location.pathname.indexOf('/') !== window.location.pathname.lastIndexOf('/');
    const basePath = isInSubfolder ? '../' : '';

    function updateSpecs(config) {
        const root = config ? (config.data || config) : null;
        const roomNo = localStorage.getItem('roomNo') || (root && root.device ? root.device.room_no : "") || "105";
        const roomNoEl = document.getElementById('roomNoVal');
        if (roomNoEl) roomNoEl.textContent = roomNo;

        let wifiName = "Taj_Guest_WiFi";
        let wifiPass = "Welcome123";
        let checkoutTime = "11:00 AM";

        if (root && root.hotel) {
            if (root.hotel.wifi_name) wifiName = root.hotel.wifi_name;
            if (root.hotel.wifi_password) wifiPass = root.hotel.wifi_password;
            if (root.hotel.checkout_time) checkoutTime = root.hotel.checkout_time;
        }

        const wifiNameEl = document.getElementById('wifiNameVal');
        if (wifiNameEl) wifiNameEl.textContent = wifiName;
        const wifiPassEl = document.getElementById('wifiPassVal');
        if (wifiPassEl) wifiPassEl.textContent = wifiPass;
        const checkoutEl = document.getElementById('checkoutTimeVal');
        if (checkoutEl) checkoutEl.textContent = checkoutTime;
    }

    // Try reading cached data from localStorage first
    const cachedStr = localStorage.getItem('cachedHotelData');
    if (cachedStr) {
        try {
            const cachedObj = JSON.parse(cachedStr);
            initBackgroundSlider(cachedObj);
            updateSpecs(cachedObj);
            const rawList = extractRoomInfo(cachedObj);
            if (rawList.length > 0) {
                images = rawList.map(item => ({
                    ...item,
                    image_url: (item.image_url.startsWith('http') || item.image_url.startsWith('/')) ? item.image_url : basePath + item.image_url
                }));
                updateDisplay(1);
            }
        } catch (e) {}
    }

    fetchHotelConfig().then(config => {
        if (config) {
            if (typeof window.checkPlanExpiredRedirect === 'function') window.checkPlanExpiredRedirect(config, '../index.html');
            initBackgroundSlider(config);
            updateSpecs(config);

            const rawList = extractRoomInfo(config);
            let newImages = [];
            if (rawList.length > 0) {
                newImages = rawList.map(item => ({
                    ...item,
                    image_url: (item.image_url.startsWith('http') || item.image_url.startsWith('/')) ? item.image_url : basePath + item.image_url
                }));
            }

            if (newImages.length > 0) {
                images = newImages;
                currentIndex = 0;
                updateDisplay(1);
                startAutoSlide();
            }
        }
    }).catch(err => console.warn("Background fetch failed:", err));

    if (images.length > 0) {
        updateDisplay(1);
        startAutoSlide();
    }
}

let isTransitioning = false;

function updateDisplay(dir = 1) {
    if (!images || images.length === 0) return;

    const currentEl = document.getElementById('slideCurrent');
    const nextEl = document.getElementById('slideNext');
    if (!currentEl || !nextEl) return;

    const item = images[currentIndex];
    const targetSrc = item.image_url || item;

    const titleEl = document.getElementById('roomTitleName');
    const badgeEl = document.getElementById('amenityBadge');
    const descEl = document.getElementById('roomFeatureDescription');
    const countEl = document.getElementById('countIndicator');

    if (badgeEl) {
        const num = currentIndex + 1;
        badgeEl.innerText = num < 10 ? `0${num}` : `${num}`;
    }

    if (titleEl) {
        titleEl.innerText = item.title || 'Room Feature';
    }

    if (countEl) {
        countEl.innerText = `${currentIndex + 1} / ${images.length}`;
    }

    if (descEl) {
        descEl.innerText = item.description || '';
    }

    const dotsContainer = document.getElementById('slideDots');
    if (dotsContainer) {
        dotsContainer.innerHTML = '';
        images.forEach((_, idx) => {
            const dot = document.createElement('div');
            dot.className = `slide-dot ${idx === currentIndex ? 'active' : ''}`;
            dotsContainer.appendChild(dot);
        });
    }

    if (!currentEl.getAttribute('src') || currentEl.getAttribute('src') === '') {
        currentEl.src = targetSrc;
        currentEl.className = 'slide-img active';
        return;
    }

    if (currentEl.src === targetSrc) {
        return;
    }

    if (isTransitioning) return;
    isTransitioning = true;

    const inClass = dir >= 0 ? 'slide-in-right' : 'slide-in-left';
    const outClass = dir >= 0 ? 'slide-out-left' : 'slide-out-right';

    nextEl.src = targetSrc;
    nextEl.className = 'slide-img ' + inClass + ' active';
    currentEl.className = 'slide-img ' + outClass;

    setTimeout(() => {
        currentEl.src = targetSrc;
        currentEl.className = 'slide-img active';
        nextEl.className = 'slide-img';
        nextEl.removeAttribute('src');
        isTransitioning = false;
    }, 600);
}

function changeSlide(dir) {
    if (images.length <= 1 || isTransitioning) return;
    currentIndex = (currentIndex + dir + images.length) % images.length;
    updateDisplay(dir);
    startAutoSlide();
}

function startAutoSlide() {
    clearInterval(autoTimer);
    if (images.length > 1) {
        autoTimer = setInterval(() => {
            currentIndex = (currentIndex + 1) % images.length;
            updateDisplay(1);
        }, 6000);
    }
}

function goBack() {
    sessionStorage.setItem('hotelMenuLastIndex', '1');
    window.location.href = "../hotel_info/hotel_info_menu.html";
}

window.onTVNavigate = function (direction) {
    if (direction === 'left') {
        changeSlide(-1);
        return true;
    }
    if (direction === 'right') {
        changeSlide(1);
        return true;
    }
    return false;
};

window.onTVBack = function () {
    goBack();
    return true;
};

window.onload = () => {
    initGallery();
    setTimeout(() => {
        const slider = document.getElementById('amenitiesSlider');
        if (slider) slider.focus();
    }, 200);
};
