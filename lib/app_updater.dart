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
  const AppUpdateInfo({required this.version, required this.build, required this.downloadUrl, required this.assetName});
}

class AppUpdater {
  static const String apiUrl = 'https://api.github.com/repos/anparamo25-sketch/Inventario-Billar/releases/latest';

  static Future<AppUpdateInfo?> check() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(apiUrl));
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set(HttpHeaders.userAgentHeader, 'Inventario-Billar-Updater');
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      if (data is! Map<String, dynamic>) return null;
      final tag = (data['tag_name'] ?? '').toString();
      final releaseVersion = tag.startsWith('v') ? tag.substring(1) : tag;
      final assets = (data['assets'] as List? ?? []);
      Map<String, dynamic>? apk;
      for (final item in assets) {
        if (item is Map<String, dynamic>) {
          final name = (item['name'] ?? '').toString();
          if (name.toLowerCase().endsWith('.apk')) { apk = item; break; }
        }
      }
      if (apk == null) return null;
      final match = RegExp(r'build(\d+)', caseSensitive: false).firstMatch((apk['name'] ?? '').toString());
      final build = int.tryParse(match?.group(1) ?? '') ?? 0;
      if (build <= 0) return null;
      return AppUpdateInfo(version: releaseVersion, build: build, downloadUrl: (apk['browser_download_url'] ?? '').toString(), assetName: (apk['name'] ?? 'Inventario-Billar-update.apk').toString());
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<int> currentBuild() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  static Future<void> checkAndShow(BuildContext context) async {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Buscando actualizaciones...')));
    final update = await check();
    if (!context.mounted) return;
    if (update == null) {
      messenger.showSnackBar(const SnackBar(content: Text('No se pudo comprobar la actualización.')));
      return;
    }
    final current = await currentBuild();
    if (!context.mounted) return;
    if (update.build <= current) {
      messenger.showSnackBar(const SnackBar(content: Text('La aplicación ya está actualizada.')));
      return;
    }
    final install = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nueva actualización disponible'),
        content: Text('Versión ' + update.version + ' (build ' + update.build.toString() + ') está disponible.\n\nLa actualización se descargará y después se abrirá el instalador de Android.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Ahora no')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Actualizar')),
        ],
      ),
    );
    if (install != true || !context.mounted) return;
    try {
      messenger.showSnackBar(const SnackBar(content: Text('Descargando actualización...')));
      final directory = await getTemporaryDirectory();
      final apkPath = directory.path + '/' + update.assetName;
      final file = File(apkPath);
      if (await file.exists()) await file.delete();
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(update.downloadUrl));
        request.headers.set(HttpHeaders.userAgentHeader, 'Inventario-Billar-Updater');
        final response = await request.close();
        if (response.statusCode != 200) throw HttpException('HTTP ' + response.statusCode.toString());
        final sink = file.openWrite();
        await response.pipe(sink);
        await sink.flush();
        await sink.close();
      } finally {
        client.close(force: true);
      }
      if (!context.mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Descarga terminada. Abriendo instalador...')));
      final result = await OpenFilex.open(apkPath, type: 'application/vnd.android.package-archive');
      if (!context.mounted) return;
      if (result.type != ResultType.done) messenger.showSnackBar(SnackBar(content: Text('No se pudo abrir el instalador: ' + result.message)));
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Error al actualizar: ' + e.toString())));
    }
  }
}