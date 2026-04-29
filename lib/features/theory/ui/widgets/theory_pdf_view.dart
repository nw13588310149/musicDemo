// 平台分发：Web 用 iframe（避开 CORS、与 1.0 一致），原生用 pdfrx。
export 'theory_pdf_view_native.dart'
    if (dart.library.js_interop) 'theory_pdf_view_web.dart';
