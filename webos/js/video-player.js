/**
 * PAX TV Hospitality - Video Playback Engine for LG webOS TV
 * Supports HTML5 Video, webOS Media pipeline, Live HLS and MP4 streams.
 */

(function (window) {
  'use strict';

  var VideoEngine = {
    videoEl: null,
    currentChannel: null,
    channels: [
      { id: 1, number: '001', name: 'Hotel Welcome Channel', category: 'Hotel Promo', url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4' },
      { id: 2, number: '002', name: 'Discovery HD', category: 'Documentary', url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4' },
      { id: 3, number: '003', name: 'National Geographic', category: 'Nature', url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4' },
      { id: 4, number: '004', name: 'BBC World News', category: 'News', url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4' },
      { id: 5, number: '005', name: 'CNN International', category: 'News', url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4' },
      { id: 6, number: '006', name: 'Bloomberg TV', category: 'Finance', url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyBlazes.mp4' },
      { id: 7, number: '007', name: 'ESPN Sports', category: 'Sports', url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4' },
      { id: 8, number: '008', name: 'Star Sports 1', category: 'Sports', url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4' }
    ],

    init: function (elementId) {
      this.videoEl = document.getElementById(elementId);
      if (!this.videoEl) {
        console.warn('[VideoEngine] Video element #' + elementId + ' not found');
        return;
      }

      var self = this;
      this.videoEl.addEventListener('error', function (e) {
        console.warn('[VideoEngine] Playback error:', e);
        self._showPlayerMessage('Stream buffering or unavailable. Retrying...');
      });

      this.videoEl.addEventListener('playing', function () {
        self._hidePlayerMessage();
      });
    },

    loadChannel: function (channel) {
      if (!this.videoEl) return;
      this.currentChannel = channel;
      console.log('[VideoEngine] Loading channel ' + channel.number + ' - ' + channel.name);

      this.videoEl.pause();
      this.videoEl.src = channel.url;
      this.videoEl.load();
      var playPromise = this.videoEl.play();
      if (playPromise !== undefined) {
        playPromise.catch(function (err) {
          console.warn('[VideoEngine] Auto-play was prevented:', err);
        });
      }

      this._updateChannelInfoOverlay(channel);
    },

    playChannelByNumber: function (numStr) {
      var target = null;
      for (var i = 0; i < this.channels.length; i++) {
        if (this.channels[i].number === numStr || String(this.channels[i].id) === numStr) {
          target = this.channels[i];
          break;
        }
      }
      if (target) {
        this.loadChannel(target);
        return true;
      }
      return false;
    },

    channelUp: function () {
      if (!this.currentChannel) {
        this.loadChannel(this.channels[0]);
        return;
      }
      var idx = this.channels.indexOf(this.currentChannel);
      var nextIdx = (idx + 1) % this.channels.length;
      this.loadChannel(this.channels[nextIdx]);
    },

    channelDown: function () {
      if (!this.currentChannel) {
        this.loadChannel(this.channels[0]);
        return;
      }
      var idx = this.channels.indexOf(this.currentChannel);
      var prevIdx = (idx - 1 + this.channels.length) % this.channels.length;
      this.loadChannel(this.channels[prevIdx]);
    },

    togglePlay: function () {
      if (!this.videoEl) return;
      if (this.videoEl.paused) {
        this.videoEl.play();
      } else {
        this.videoEl.pause();
      }
    },

    stop: function () {
      if (!this.videoEl) return;
      this.videoEl.pause();
      this.videoEl.removeAttribute('src');
      this.videoEl.load();
    },

    _updateChannelInfoOverlay: function (ch) {
      var badge = document.getElementById('tv-player-channel-badge');
      if (badge) {
        badge.innerHTML = '<span class="text-amber-400 font-bold">' + ch.number + '</span> ' + ch.name + ' <span class="text-xs text-gray-400">(' + ch.category + ')</span>';
        badge.style.display = 'block';
        badge.style.opacity = '1';
        clearTimeout(this._badgeTimer);
        this._badgeTimer = setTimeout(function () {
          badge.style.opacity = '0';
        }, 4000);
      }
    },

    _showPlayerMessage: function (msg) {
      var el = document.getElementById('tv-player-message');
      if (el) {
        el.innerText = msg;
        el.style.display = 'block';
      }
    },

    _hidePlayerMessage: function () {
      var el = document.getElementById('tv-player-message');
      if (el) {
        el.style.display = 'none';
      }
    }
  };

  window.VideoEngine = VideoEngine;
})(window);
