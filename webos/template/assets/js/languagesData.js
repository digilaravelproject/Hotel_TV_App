"use strict";
const AVAILABLE_LANGUAGES = [
  { name: "English", file: "english.json", code: "EN" },
  { name: "\u0939\u093F\u0902\u0926\u0940", file: "hindi.json", code: "HI" },
  { name: "\u092E\u0930\u093E\u0920\u0940", file: "marathi.json", code: "MR" },
  { name: "\u0915\u094B\u0902\u0915\u0923\u0940", file: "konkani.json", code: "GOM" },
  { name: "\u0A97\u0AC1\u0A9C\u0AB0\u0ABE\u0AA4\u0AC0", file: "gujrati.json", code: "GU" },
  { name: "\u09AC\u09BE\u0982\u09B2\u09BE", file: "bengali.json", code: "BN" },
  { name: "\u0A2A\u0A70\u0A1C\u0A3E\u0A2C\u0A40", file: "punjabi.json", code: "PA" },
  { name: "\u0985\u09B8\u09AE\u09C0\u09AF\u09BC\u09BE", file: "assamese.json", code: "AS" },
  { name: "\u0C95\u0CA8\u0CCD\u0CA8\u0CA1", file: "kannada.json", code: "KN" },
  { name: "\u0BA4\u0BAE\u0BBF\u0BB4\u0BCD", file: "tamil.json", code: "TA" },
  { name: "\u0C24\u0C46\u0C32\u0C41\u0C17\u0C41", file: "telugu.json", code: "TE" },
  { name: "\u0D2E\u0D32\u0D2F\u0D3E\u0D33\u0D02", file: "malayalam.json", code: "ML" },
  { name: "Fran\xE7ais", file: "french.json", code: "FR" },
  { name: "Deutsch", file: "german.json", code: "DE" },
  { name: "Espa\xF1ol", file: "spanish.json", code: "ES" },
  { name: "Portugu\xEAs", file: "portuguese.json", code: "PT" },
  { name: "\u0420\u0443\u0441\u0441\u043A\u0438\u0439", file: "russian.json", code: "RU" },
  { name: "\u7B80\u4F53\u4E2D\u6587", file: "chinese.json", code: "ZH" },
  { name: "\u05E2\u05B4\u05D1\u05E8\u05B4\u05D9\u05EA", file: "hebrew.json", code: "HE" },
  { name: "\u0627\u0631\u062F\u0648", file: "urdu.json", code: "UR" },
  { name: "\u0639\u0631\u0628\u064A", file: "arabic.json", code: "AR" }
];
const RTL_LANG_FILES = ["arabic.json", "urdu.json", "hebrew.json"];
window.AVAILABLE_LANGUAGES = AVAILABLE_LANGUAGES;
window.RTL_LANG_FILES = RTL_LANG_FILES;
