/// OpenSheetMusicDisplay 渲染壳页 HTML / JS 片段（Web 与原生 WebView 共用）。
abstract final class OsmdScoreShell {
  static const osmdCdn =
      'https://cdn.jsdelivr.net/npm/opensheetmusicdisplay@1.8.9/build/opensheetmusicdisplay.min.js';

  static String htmlDocument() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    html, body {
      margin: 0;
      padding: 8px 12px 16px;
      background: #F5F6F8;
      overflow: auto;
      font-family: "Times New Roman", serif;
    }
    #osmd-container {
      width: 100%;
      min-height: 100%;
    }
    #osmd-container svg {
      max-width: 100%;
      height: auto;
    }
  </style>
  <script src="$osmdCdn"></script>
</head>
<body>
  <div id="osmd-container"></div>
  <script>
    window.osmdInstance = null;
    window.renderScoreFromBase64 = async function(encoded) {
      const container = document.getElementById('osmd-container');
      container.innerHTML = '';
      const xml = decodeURIComponent(escape(atob(encoded)));
      const osmd = new opensheetmusicdisplay.OpenSheetMusicDisplay('osmd-container', {
        autoResize: true,
        backend: 'svg',
        drawTitle: false,
        drawComposer: false,
        drawCredits: false,
        drawPartNames: false,
        drawingParameters: 'compacttight',
      });
      await osmd.load(xml);
      osmd.render();
      osmd.cursor.show();
      osmd.cursor.reset();
      window.osmdInstance = osmd;
    };
    window.seekToMs = function(ms) {
      const osmd = window.osmdInstance;
      if (!osmd || !osmd.cursor) return;
      const targetSec = Math.max(0, ms / 1000);
      osmd.cursor.reset();
      osmd.cursor.show();
      let guard = 0;
      while (!osmd.cursor.Iterator.EndReached && guard < 5000) {
        const ts = osmd.cursor.Iterator.currentTimeStamp;
        const currentSec = ts ? ts.realValue : 0;
        if (currentSec >= targetSec) break;
        osmd.cursor.next();
        guard++;
      }
      const cursorEl = osmd.cursor.cursorElement;
      if (cursorEl && cursorEl.scrollIntoView) {
        cursorEl.scrollIntoView({ block: 'center', inline: 'center', behavior: 'smooth' });
      }
    };
  </script>
</body>
</html>
''';
  }
}
