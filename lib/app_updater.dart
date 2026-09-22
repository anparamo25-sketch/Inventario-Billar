import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateInfo {
  final String version;
  final int build;
  final String downloadUrl;
  final String assetName;

  const AppUpdateInfo({
    required this.version,
    required this.build,
    required this.downloadUrl,
    required this.assetName,
  });
}

class AppUpdater {
  static const String versionUrl =
      'https://raw.githubusercontent.com/anparamo25-sketch/Inventario-Billar/main/pubspec.yaml';

  static Future<String> _getText(String url) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);

    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.acceptHeader, 'text/plain');
      request.headers.set(HttpHeaders.userAgentHeader, 'Inventario-Billar-Updater/1.1');
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'HTTP ${response.statusCode} al consultar la actualización',
          uri: Uri.parse(url),
        );
      }

      return await response.transform(utf8.decoder).join();
    } on SocketException catch (e) {
      throw Exception('Sin conexión a Internet: ${e.message}');
    } on HttpException catch (e) {
      throw Exception(e.message);
    } on HandshakeException {
      throw Exception('No se pudo establecer una conexión segura con GitHub.');
    } finally {
      client.close(force: true);
    }
  }

  static Future<AppUpdateInfo> check() async {
    final pubspec = await _getText(versionUrl);

    final versionMatch =
        RegExp(r'^version:\s*([^+\s]+)\+(\d+)\s*$', multiLine: true)
            .firstMatch(pubspec);

    if (versionMatch == null) {
      throw Exception('No se pudo leer la versión publicada.');
    }

    final version = versionMatch.group(1)!;
    final build = int.tryParse(versionMatch.group(2)!) ?? 0;

    if (build <= 0) {
      throw Exception('La versión publicada no tiene un build válido.');
    }

    final assetName = 'Inventario-Billar-v$version-build$build.apk';
    final downloadUrl =
        'https://github.com/anparamo25-sketch/Inventario-Billar/releases/download/v$version/$assetName';

    return AppUpdateInfo(
      version: version,
      build: build,
      downloadUrl: downloadUrl,
      assetName: assetName,
    );
  }

  static Future<int> currentBuild() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  static Future<void> checkAndShow(BuildContext context) async {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Buscando actualizaciones...')),
    );

    try {
      final update = await check();
      if (!context.mounted) return;

      final current = await currentBuild();
      if (!context.mounted) return;

      if (update.build <= current) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'La aplicación ya está actualizada. Build actual: $current.',
            ),
          ),
        );
        return;
      }

      final install = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Nueva actualización disponible'),
          content: Text(
            'Versión ${update.version} (build ${update.build}) está disponible.\n\n'
            'La actualización se descargará y después se abrirá el instalador de Android.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Actualizar'),
            ),
          ],
        ),
      );

      if (install != true || !context.mounted) return;

      messenger.showSnackBar(
        const SnackBar(content: Text('Descargando actualización...')),
      );

      final directory = await getTemporaryDirectory();
      final apkPath = '${directory.path}/${update.assetName}';
      final file = File(apkPath);

      if (await file.exists()) {
        await file.delete();
      }

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 30);

      try {
        final request = await client.getUrl(Uri.parse(update.downloadUrl));
        request.headers.set(
          HttpHeaders.userAgentHeader,
          'Inventario-Billar-Updater/1.1',
        );
        final response = await request.close();

        if (response.statusCode != HttpStatus.ok) {
          throw HttpException(
            'HTTP ${response.statusCode} al descargar el APK',
            uri: Uri.parse(update.downloadUrl),
          );
        }

        final sink = file.openWrite();
        await response.pipe(sink);
        await sink.flush();
        await sink.close();
      } finally {
        client.close(force: true);
      }

      if (!context.mounted) return;

      messenger.showSnackBar(
        const SnackBar(content: Text('Descarga terminada. Abriendo instalador...')),
      );

      final result = await OpenFilex.open(
        apkPath,
        type: 'application/vnd.android.package-archive',
      );

      if (!context.mounted) return;

      if (result.type != ResultType.done) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo abrir el instalador: ${result.message}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text('Error al comprobar actualización: $e'),
        ),
      );
    }
  }
}
