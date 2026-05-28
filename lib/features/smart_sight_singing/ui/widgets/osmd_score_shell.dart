/// OpenSheetMusicDisplay 桥脚本与 WebView 壳页（iPad / 原生 WebView 优先）。
///
/// 设计要点（iPad WKWebView）：
/// - OSMD 库走本地 `opensheetmusicdisplay.min.js`，不依赖 CDN
/// - MusicXML 写入同目录 `score.xml`，WebView 内 fetch 加载，避免大字符串 eval 崩溃
/// - 光标定位用 Dart 传入的 onset 毫秒数组 + 增量 next()
/// - 滚动由 `#scroll-wrap` 容器负责（WKWebView 内 scrollIntoView 不可靠）
abstract final class OsmdScoreShell {
  static const osmdScriptFileName = 'opensheetmusicdisplay.min.js';
  static const hostHtmlFileName = 'index.html';
  static const scoreXmlFileName = 'score.xml';

  /// Web 端仍走 CDN；iPad 原生端使用本地 asset。
  static const osmdCdn =
      'https://cdn.jsdelivr.net/npm/opensheetmusicdisplay@1.8.9/build/opensheetmusicdisplay.min.js';

  static const String bridgeJs = r'''
(function(){
  if (window.__SightSingingOsmd) return;
  var hosts = {};

  function findTarget(onsets, ms) {
    if (!onsets || !onsets.length) return -1;
    var lo = 0, hi = onsets.length;
    while (lo < hi) {
      var mid = (lo + hi) >>> 1;
      if (onsets[mid] <= ms) lo = mid + 1; else hi = mid;
    }
    return Math.max(0, lo - 1);
  }

  function scrollWrapToCursor(host) {
    try {
      var wrap = document.getElementById('scroll-wrap');
      var cursor = host.osmd && host.osmd.cursor;
      if (!wrap || !cursor) return;
      var el = cursor.cursorElement || cursor.CursorElement;
      if (!el || !el.getBoundingClientRect) return;
      var rect = el.getBoundingClientRect();
      var wrapRect = wrap.getBoundingClientRect();
      var delta = rect.top - wrapRect.top - (wrap.clientHeight * 0.35);
      var nextTop = wrap.scrollTop + delta;
      wrap.scrollTo({ top: Math.max(0, nextTop), behavior: 'smooth' });
    } catch (e) {}
  }

  function notifyLoaded(divId, ok) {
    try {
      if (window.OsmdScoreLoaded && window.OsmdScoreLoaded.postMessage) {
        window.OsmdScoreLoaded.postMessage(ok ? 'loaded:' + divId : 'error:' + divId);
      }
    } catch (e) {}
  }

  function notifyReady() {
    try {
      if (window.OsmdHostReady && window.OsmdHostReady.postMessage) {
        window.OsmdHostReady.postMessage('ready');
      }
    } catch (e) {}
  }

  function renderXml(host, divId, xml) {
    host.loaded = false;
    host.currentIndex = -1;
    try {
      host.osmd.load(xml).then(function(){
        try {
          host.osmd.render();
          host.osmd.cursor.show();
          host.osmd.cursor.reset();
          host.currentIndex = 0;
          host.loaded = true;
          notifyLoaded(divId, true);
        } catch (e) {
          console.error('[OSMD] render failed', e);
          notifyLoaded(divId, false);
        }
      }).catch(function(e){
        console.error('[OSMD] load failed', e);
        notifyLoaded(divId, false);
      });
    } catch (e) {
      console.error('[OSMD] load sync failed', e);
      notifyLoaded(divId, false);
    }
  }

  window.__SightSingingOsmd = {
    create: function(divId) {
      if (hosts[divId]) return true;
      if (!window.opensheetmusicdisplay) return false;
      var div = document.getElementById(divId);
      if (!div) return false;
      try {
        var osmd = new window.opensheetmusicdisplay.OpenSheetMusicDisplay(div, {
          autoResize: true,
          backend: 'svg',
          drawTitle: false,
          drawComposer: false,
          drawCredits: false,
          drawPartNames: false,
          drawingParameters: 'compacttight',
        });
        hosts[divId] = { osmd: osmd, onsets: [], currentIndex: -1, loaded: false };
        return true;
      } catch (e) {
        console.error('[OSMD] create failed', e);
        return false;
      }
    },

    load: function(divId, xml) {
      var host = hosts[divId];
      if (!host) return;
      renderXml(host, divId, xml);
    },

    loadFromFile: function(divId, fileName) {
      var host = hosts[divId];
      if (!host) return;
      fetch(fileName, { cache: 'no-store' })
        .then(function(r){ return r.text(); })
        .then(function(xml){ renderXml(host, divId, xml); })
        .catch(function(e){
          console.error('[OSMD] fetch xml failed', e);
          notifyLoaded(divId, false);
        });
    },

    setOnsets: function(divId, onsetsRaw) {
      var host = hosts[divId];
      if (!host) return;
      var onsets = [];
      if (onsetsRaw && onsetsRaw.length) {
        for (var i = 0; i < onsetsRaw.length; i++) {
          var v = Number(onsetsRaw[i]);
          if (!isNaN(v)) onsets.push(v);
        }
        onsets.sort(function(a, b){ return a - b; });
      }
      host.onsets = onsets;
      host.currentIndex = -1;
    },

    seek: function(divId, ms) {
      var host = hosts[divId];
      if (!host || !host.loaded) return;
      var cursor = host.osmd.cursor;
      if (!cursor) return;
      var target = findTarget(host.onsets, ms);
      if (target < 0) return;
      if (target === host.currentIndex) return;
      try {
        if (target < host.currentIndex || host.currentIndex < 0) {
          cursor.reset();
          host.currentIndex = 0;
          for (var i = 0; i < target; i++) {
            try { cursor.next(); } catch (e) { break; }
          }
        } else {
          for (var j = host.currentIndex; j < target; j++) {
            try { cursor.next(); } catch (e) { break; }
          }
        }
        host.currentIndex = target;
        cursor.show();
        scrollWrapToCursor(host);
      } catch (e) {
        console.error('[OSMD] seek failed', e);
      }
    },

    dispose: function(divId) {
      var host = hosts[divId];
      if (host) {
        try { host.osmd.clear(); } catch (e) {}
        try { host.osmd.cursor.hide(); } catch (e) {}
      }
      delete hosts[divId];
    },
  };
})();
''';

  /// 写入 WebView 宿主目录的 index.html（引用同目录本地 OSMD 脚本）。
  static String hostHtml({required String containerId}) {
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    html, body {
      margin: 0;
      padding: 0;
      background: #F5F6F8;
      font-family: "Times New Roman", serif;
      overflow: hidden;
      -webkit-overflow-scrolling: touch;
    }
    #scroll-wrap {
      position: absolute;
      inset: 0;
      overflow: auto;
      -webkit-overflow-scrolling: touch;
      padding: 8px 12px 16px;
      box-sizing: border-box;
    }
    #$containerId {
      width: 100%;
      min-height: 100%;
    }
    #$containerId svg {
      max-width: 100%;
      height: auto;
    }
  </style>
  <script src="$osmdScriptFileName"></script>
</head>
<body>
  <div id="scroll-wrap">
    <div id="$containerId"></div>
  </div>
  <script>$bridgeJs</script>
  <script>
    (function(){
      var divId = '$containerId';
      var attempts = 0;
      function tryInit() {
        attempts++;
        if (window.opensheetmusicdisplay && window.__SightSingingOsmd) {
          if (window.__SightSingingOsmd.create(divId)) {
            if (window.OsmdHostReady && window.OsmdHostReady.postMessage) {
              window.OsmdHostReady.postMessage('ready');
            }
            return;
          }
        }
        if (attempts > 240) {
          try {
            if (window.OsmdHostReady && window.OsmdHostReady.postMessage) {
              window.OsmdHostReady.postMessage('error');
            }
          } catch (e) {}
          return;
        }
        setTimeout(tryInit, 50);
      }
      tryInit();
    })();
  </script>
</body>
</html>''';
  }
}
