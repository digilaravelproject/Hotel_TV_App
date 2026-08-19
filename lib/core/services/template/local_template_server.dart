import 'dart:io';
import 'package:path/path.dart' as p;
import 'template_manager_service.dart';
import '../../utils/logger.dart';

class LocalTemplateServer {
  static HttpServer? _server;
  static int? _port;
  static int _refCount = 0;

  static Future<int> get port async {
    while (_port == null) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    return _port!;
  }

  static Future<void> start() async {
    _refCount++;
    if (_server != null) {
      try {
        await _server!.close(force: true);
      } catch (_) {}
      _server = null;
      _port = null;
    }

    try {
      final dir = await TemplateManagerService.getTemplateDirectory();
      final dirPath = dir.path;

      try {
        _server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          40441,
          shared: true,
        );
      } catch (e) {
        Logger.w('[LocalServer] Port 40441 busy, binding to dynamic port: $e');
        _server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
          shared: true,
        );
      }
      _port = _server!.port;

      Logger.i('[LocalServer] Started on http://127.0.0.1:$_port');

      _server!.listen((HttpRequest request) async {
        var filePath = request.uri.path;
        if (filePath.isEmpty || filePath == '/') {
          filePath = 'index.html';
        } else {
          filePath = filePath.replaceAll(RegExp(r'^/+'), '');
        }

        final fullPath = p.join(dirPath, filePath);

        if (!fullPath.startsWith(dirPath)) {
          request.response.statusCode = 403;
          request.response.close();
          return;
        }

        var file = File(fullPath);
        if (!file.existsSync()) {
          final rootDir = Directory(dirPath);
          if (await rootDir.exists()) {
            // 1. Check if unzipped into single child root directory
            try {
              final list = await rootDir.list(recursive: false).toList();
              if (list.length == 1 && list.first is Directory) {
                final altPath = p.join(list.first.path, filePath);
                final altFile = File(altPath);
                if (await altFile.exists()) {
                  file = altFile;
                }
              }
            } catch (_) {}

            // 2. Recursive Search Fallback if direct path still doesn't exist
            if (!await file.exists()) {
              final fileName = p.basename(filePath);
              try {
                await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
                  if (entity is File && p.basename(entity.path) == fileName) {
                    file = entity;
                    break;
                  }
                }
              } catch (_) {}
            }
          }
        }

        if (!await file.exists()) {
          Logger.w('[LocalServer] File 404 Not Found: $filePath (searched root: $dirPath)');
          request.response.statusCode = 404;
          await request.response.close();
          return;
        }

        try {
          final ext = p.extension(filePath).toLowerCase();
          final contentType = _mimeType(ext);

          request.response.headers.contentType = ContentType.parse(contentType);
          request.response.headers.add('Access-Control-Allow-Origin', '*');
          request.response.headers.add('Cache-Control', 'no-cache, no-store, must-revalidate');
          request.response.headers.add('Pragma', 'no-cache');
          request.response.headers.add('Expires', '0');
          request.response.statusCode = 200;
          await file.openRead().pipe(request.response);
        } catch (e) {
          request.response.statusCode = 500;
          await request.response.close();
        }
      });
    } catch (e) {
      Logger.e('[LocalServer] Failed to start: $e');
      rethrow;
    }
  }

  static Future<void> stop() async {
    _refCount--;
    if (_refCount <= 0 && _server != null) {
      await _server!.close(force: true);
      _server = null;
      _port = null;
      _refCount = 0;
      Logger.i('[LocalServer] Stopped.');
    }
  }

  static String get baseUrl => 'http://127.0.0.1:$_port';

  static String _mimeType(String ext) {
    switch (ext) {
      case '.html': return 'text/html; charset=utf-8';
      case '.css': return 'text/css; charset=utf-8';
      case '.js': return 'text/javascript; charset=utf-8';
      case '.json': return 'application/json; charset=utf-8';
      case '.png': return 'image/png';
      case '.jpg':
      case '.jpeg': return 'image/jpeg';
      case '.svg': return 'image/svg+xml';
      case '.webp': return 'image/webp';
      case '.ico': return 'image/x-icon';
      case '.woff': return 'font/woff';
      case '.woff2': return 'font/woff2';
      case '.ttf': return 'font/ttf';
      default: return 'application/octet-stream';
    }
  }
}
