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

async function initGallery() {
    const injected = await waitForLoginData();
    if (injected) {
        var dataObj = injected.data || injected;
        localStorage.setItem('cachedHotelData', JSON.stringify(dataObj));
        if (dataObj.city_pics && Array.isArray(dataObj.city_pics) && dataObj.city_pics.length > 0) {
            images = dataObj.city_pics;
        } else if (dataObj.gallery && Array.isArray(dataObj.gallery) && dataObj.gallery.length > 0) {
            images = dataObj.gallery;
        }
    }

    if (images.length === 0) {
        if (window.AndroidBridge && window.AndroidBridge.getPictureList) {
            try {
                const listString = window.AndroidBridge.getPictureList('city');
                images = JSON.parse(listString);
            } catch (_) {}
        }
    }

    if (!images || images.length === 0) {
        images = ["pics/slide1.jpg", "pics/slide2.jpg"];
    }
    
    if (images.length > 0) {
        updateDisplay();
        startAutoSlide();
    }

    let langFile = localStorage.getItem('selectedLangFile') || 'english.json';
    
    if (window.AndroidBridge && window.AndroidBridge.getSelectedLanguageFile) {
        try { langFile = window.AndroidBridge.getSelectedLanguageFile(); } catch (_) {}
    }

    fetch(`../admin/${langFile}?t=${Date.now()}`)
        .then(res => res.json())
        .then(data => {
            const titleKey = 'city'; 
            const titleEl = document.getElementById('headerTitle');
            if (titleEl) {
                if (data.icons && data.icons[titleKey]) {
                    titleEl.innerText = data.icons[titleKey];
                } else if (data[titleKey]) {
                    titleEl.innerText = data[titleKey];
                }
            }
        })
        .catch(err => console.error("Language load error:", err));
}

        function updateDisplay() {
            if (images[currentIndex]) {
                const imgEl = document.getElementById('displayImage');
                imgEl.style.opacity = 0;
                setTimeout(() => {
                    imgEl.src = images[currentIndex];
                    imgEl.style.opacity = 1;
                }, 100);
            }
        }

        function changeSlide(dir) {
            let next = currentIndex + dir;
            if (next < 0) { trigger('btnPrev'); return; }
            if (next >= images.length) { trigger('btnNext'); return; }
            
            currentIndex = next;
            updateDisplay();
            startAutoSlide(); 
        }

        function startAutoSlide() {
            clearInterval(autoTimer);
            autoTimer = setInterval(() => {
                if (images.length > 1) {
                    currentIndex = (currentIndex + 1) % images.length;
                    updateDisplay();
                }
            }, 10000);
        }

        function trigger(id) {
            const el = document.getElementById(id);
            if (el) {
                el.classList.add('vibrate');
                setTimeout(() => el.classList.remove('vibrate'), 400);
            }
        }

        function goBack() {
            window.location.href = "../index.html";
        }

        
window.onTVNavigate = function(direction) {
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

window.onTVBack = function() {
    goBack();
    return true;
};


        
        window.onload = () => { initGallery(); setTimeout(() => document.getElementById('displayImage').focus(), 200); };