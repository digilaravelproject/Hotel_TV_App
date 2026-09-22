/**
 * PAX TV Hospitality - LG webOS Remote Navigation & Spatial Focus Engine
 * Full D-Pad (Up, Down, Left, Right), OK (13), Back (461), Color Keys & Numeric support.
 */

(function (window) {
  'use strict';

  var RemoteNav = {
    currentFocus: null,
    modalContainer: null,
    onBackHandlers: [],
    inactivityTimer: null,
    inactivityTimeoutMs: 120000, // 2 minutes
    onInactivityTrigger: null,

    KEYS: {
      UP: [38, 19, 65362, 103],
      DOWN: [40, 20, 65364, 108],
      LEFT: [37, 21, 65361, 105],
      RIGHT: [39, 22, 65363, 106],
      ENTER: [13, 32, 23, 66, 29443],
      BACK: [461, 27, 8, 10009, 10182],
      RED: [403],
      GREEN: [404],
      YELLOW: [405],
      BLUE: [406],
      PLAY: [415],
      PAUSE: [19],
      STOP: [413],
      FF: [417],
      REWIND: [412]
    },

    init: function () {
      var self = this;
      window.addEventListener('keydown', function (e) {
        self.handleKeyDown(e);
      }, { capture: true, passive: false });

      // Inactivity tracking
      ['mousemove', 'mousedown', 'keydown', 'touchstart'].forEach(function (evt) {
        window.addEventListener(evt, function () {
          self.resetInactivityTimer();
        }, { passive: true });
      });
      this.resetInactivityTimer();
    },

    resetInactivityTimer: function () {
      var self = this;
      if (this.inactivityTimer) clearTimeout(this.inactivityTimer);
      this.inactivityTimer = setTimeout(function () {
        if (typeof self.onInactivityTrigger === 'function') {
          self.onInactivityTrigger();
        }
      }, this.inactivityTimeoutMs);
    },

    /**
     * Set active modal scope so D-pad only navigates within the modal
     */
    setModalScope: function (element) {
      this.modalContainer = element;
      var firstFocusable = this.getFocusables()[0];
      if (firstFocusable) {
        this.setFocus(firstFocusable);
      }
    },

    clearModalScope: function () {
      this.modalContainer = null;
    },

    registerBackHandler: function (handler) {
      this.onBackHandlers.push(handler);
    },

    removeBackHandler: function (handler) {
      var idx = this.onBackHandlers.indexOf(handler);
      if (idx !== -1) this.onBackHandlers.splice(idx, 1);
    },

    getFocusables: function () {
      var root = this.modalContainer || document;
      var selector = '.tv-focusable, [tabindex="0"], button:not([disabled]), input:not([disabled]), a[href]';
      var all = Array.prototype.slice.call(root.querySelectorAll(selector));

      return all.filter(function (el) {
        if (el.disabled || el.getAttribute('aria-hidden') === 'true') return false;
        var style = window.getComputedStyle(el);
        if (style.display === 'none' || style.visibility === 'hidden' || parseFloat(style.opacity) === 0) {
          return false;
        }
        var rect = el.getBoundingClientRect();
        return rect.width > 0 && rect.height > 0;
      });
    },

    setFocus: function (el) {
      if (!el) return;
      if (this.currentFocus && this.currentFocus !== el) {
        this.currentFocus.classList.remove('tv-focused');
      }
      this.currentFocus = el;
      el.classList.add('tv-focused');
      if (typeof el.focus === 'function') {
        el.focus();
      }
      // Scroll into view smoothly if needed
      try {
        el.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'nearest' });
      } catch (_) {}
    },

    handleKeyDown: function (e) {
      var code = e.keyCode || e.which;

      // Handle Back Key (webOS 461, Esc, Backspace)
      if (this.KEYS.BACK.indexOf(code) !== -1 || e.key === 'Escape' || e.key === 'Backspace') {
        e.preventDefault();
        e.stopPropagation();
        this.triggerBack();
        return;
      }

      // Handle D-pad Navigation
      if (this.KEYS.UP.indexOf(code) !== -1 || e.key === 'ArrowUp') {
        e.preventDefault();
        this.navigate('up');
      } else if (this.KEYS.DOWN.indexOf(code) !== -1 || e.key === 'ArrowDown') {
        e.preventDefault();
        this.navigate('down');
      } else if (this.KEYS.LEFT.indexOf(code) !== -1 || e.key === 'ArrowLeft') {
        e.preventDefault();
        this.navigate('left');
      } else if (this.KEYS.RIGHT.indexOf(code) !== -1 || e.key === 'ArrowRight') {
        e.preventDefault();
        this.navigate('right');
      } else if (this.KEYS.ENTER.indexOf(code) !== -1 || e.key === 'Enter') {
        // Active element click is triggered naturally if already focused, or fire manually
        if (this.currentFocus && document.activeElement !== this.currentFocus) {
          e.preventDefault();
          this.currentFocus.click();
        }
      }
    },

    triggerBack: function () {
      if (this.onBackHandlers.length > 0) {
        var topHandler = this.onBackHandlers[this.onBackHandlers.length - 1];
        var handled = topHandler();
        if (handled) return;
      }
      console.log('[RemoteNav] Default back action triggered');
    },

    navigate: function (direction) {
      var focusables = this.getFocusables();
      if (focusables.length === 0) return;

      var current = this.currentFocus || document.activeElement;
      if (!current || focusables.indexOf(current) === -1) {
        this.setFocus(focusables[0]);
        return;
      }

      var currentRect = current.getBoundingClientRect();
      var curCenter = {
        x: currentRect.left + currentRect.width / 2,
        y: currentRect.top + currentRect.height / 2
      };

      var bestCandidate = null;
      var minDistance = Infinity;

      for (var i = 0; i < focusables.length; i++) {
        var candidate = focusables[i];
        if (candidate === current) continue;

        var candRect = candidate.getBoundingClientRect();
        var candCenter = {
          x: candRect.left + candRect.width / 2,
          y: candRect.top + candRect.height / 2
        };

        var isValid = false;
        var primaryDiff = 0;
        var orthoDiff = 0;

        if (direction === 'left' && candCenter.x < curCenter.x - 5) {
          isValid = true;
          primaryDiff = curCenter.x - candCenter.x;
          orthoDiff = Math.abs(curCenter.y - candCenter.y);
        } else if (direction === 'right' && candCenter.x > curCenter.x + 5) {
          isValid = true;
          primaryDiff = candCenter.x - curCenter.x;
          orthoDiff = Math.abs(curCenter.y - candCenter.y);
        } else if (direction === 'up' && candCenter.y < curCenter.y - 5) {
          isValid = true;
          primaryDiff = curCenter.y - candCenter.y;
          orthoDiff = Math.abs(curCenter.x - candCenter.x);
        } else if (direction === 'down' && candCenter.y > curCenter.y + 5) {
          isValid = true;
          primaryDiff = candCenter.y - curCenter.y;
          orthoDiff = Math.abs(curCenter.x - candCenter.x);
        }

        if (isValid) {
          // Weight orthogonal distance heavier so horizontal movements stay on the row
          var dist = primaryDiff + (orthoDiff * 2.5);
          if (dist < minDistance) {
            minDistance = dist;
            bestCandidate = candidate;
          }
        }
      }

      if (bestCandidate) {
        this.setFocus(bestCandidate);
      }
    }
  };

  RemoteNav.init();
  window.RemoteNav = RemoteNav;
})(window);
