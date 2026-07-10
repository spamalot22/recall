import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

class UpdateService {
  UpdateService({
    HttpClient? httpClient,
    this.owner = 'spamalot22',
    this.repository = 'recall',
  }) : _httpClient =
           httpClient ??
           (HttpClient()..connectionTimeout = const Duration(seconds: 15));

  static const _maxMetadataBytes = 1024 * 1024;
  static const _maxApkBytes = 250 * 1024 * 1024;

  final HttpClient _httpClient;
  final String owner;
  final String repository;

  Future<UpdateCheckResult> checkForUpdate({
    String currentVersion = appVersion,
  }) async {
    final current = SemanticVersion.tryParse(currentVersion);
    if (current == null) {
      throw const UpdateException(
        'This build does not have a release version.',
      );
    }

    final uri = Uri.https(
      'api.github.com',
      '/repos/$owner/$repository/releases/latest',
    );
    final response = await _getJson(uri);

    final tag = response['tag_name'];
    if (tag is! String) {
      throw const UpdateException('GitHub did not return a release tag.');
    }

    final latest = SemanticVersion.tryParse(tag);
    if (latest == null) {
      throw UpdateException(
        'Latest release tag "$tag" is not a supported version.',
      );
    }

    final expectedAssetName = 'recall-android-$tag.apk';
    final assets = response['assets'];
    if (assets is! List) {
      throw const UpdateException('GitHub did not return release assets.');
    }

    final asset = assets
        .whereType<Map<String, Object?>>()
        .cast<Map<String, dynamic>>()
        .firstWhere(
          (asset) => asset['name'] == expectedAssetName,
          orElse: () => throw UpdateException(
            'Release $tag has no $expectedAssetName asset.',
          ),
        );

    final downloadUrl = asset['browser_download_url'];
    final apkDownloadUrl = downloadUrl is String
        ? Uri.tryParse(downloadUrl)
        : null;
    if (apkDownloadUrl == null ||
        apkDownloadUrl.scheme != 'https' ||
        apkDownloadUrl.host != 'github.com' ||
        !_isExpectedDownloadPath(
          apkDownloadUrl,
          tag: tag,
          assetName: expectedAssetName,
        )) {
      throw const UpdateException(
        'GitHub returned an invalid APK download URL.',
      );
    }

    final size = asset['size'];
    if (size is! int || size < 1 || size > _maxApkBytes) {
      throw const UpdateException('GitHub returned an invalid APK size.');
    }

    return UpdateCheckResult(
      currentVersion: current,
      latestVersion: latest,
      apkName: expectedAssetName,
      apkDownloadUrl: apkDownloadUrl,
      releaseUrl: Uri.https(
        'github.com',
        '/$owner/$repository/releases/tag/$tag',
      ),
      downloadSizeBytes: size,
      updateAvailable: latest.compareTo(current) > 0,
    );
  }

  Future<File> downloadApk(
    UpdateCheckResult update, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final directory = Directory(
      p.join((await getTemporaryDirectory()).path, 'downloads'),
    );
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }

    if (update.downloadSizeBytes == null ||
        update.downloadSizeBytes! < 1 ||
        update.downloadSizeBytes! > _maxApkBytes ||
        update.apkDownloadUrl.scheme != 'https' ||
        update.apkDownloadUrl.host != 'github.com' ||
        !_isExpectedDownloadPath(
          update.apkDownloadUrl,
          tag: update.latestVersion.toString(),
          assetName: update.apkName,
        )) {
      throw const UpdateException('Update download metadata is invalid.');
    }

    final file = File(p.join(directory.path, update.apkName));
    final partialFile = File('${file.path}.part');
    if (partialFile.existsSync()) {
      await partialFile.delete();
    }
    final request = await _httpClient.getUrl(update.apkDownloadUrl);
    _setCommonHeaders(request, followRedirects: true);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw UpdateException(
        'APK download failed with HTTP ${response.statusCode}.',
      );
    }
    if (!_hasSafeDownloadRedirects(response)) {
      throw const UpdateException(
        'APK download was redirected to an untrusted host.',
      );
    }

    final total = update.downloadSizeBytes!;
    if (response.contentLength > 0 && response.contentLength != total) {
      throw const UpdateException(
        'APK download size did not match the release asset.',
      );
    }
    var received = 0;
    final sink = partialFile.openWrite();
    try {
      await for (final chunk in response) {
        received += chunk.length;
        if (received > total || received > _maxApkBytes) {
          throw const UpdateException(
            'APK download exceeded its expected size.',
          );
        }
        sink.add(chunk);
        onProgress?.call(received, total);
      }
      await sink.close();
      if (received != total) {
        throw const UpdateException(
          'Downloaded APK size did not match the release asset.',
        );
      }
      if (file.existsSync()) {
        await file.delete();
      }
      return partialFile.rename(file.path);
    } on Object {
      await sink.close();
      if (partialFile.existsSync()) {
        await partialFile.delete();
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final request = await _httpClient.getUrl(uri);
    _setCommonHeaders(request, followRedirects: false);
    final response = await request.close();
    final body = await _readBounded(response, _maxMetadataBytes);

    if (response.statusCode == HttpStatus.notFound) {
      throw const UpdateException('GitHub release metadata was not found.');
    }

    if (response.statusCode != HttpStatus.ok) {
      throw UpdateException(
        'GitHub release check failed with HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const UpdateException(
        'GitHub returned an unexpected release response.',
      );
    }

    return decoded;
  }

  void _setCommonHeaders(
    HttpClientRequest request, {
    required bool followRedirects,
  }) {
    request.headers.set(
      HttpHeaders.acceptHeader,
      'application/vnd.github+json',
    );
    request.headers.set(HttpHeaders.userAgentHeader, 'Recall/$appVersion');
    request.followRedirects = followRedirects;
    request.maxRedirects = 5;
  }

  bool _isExpectedDownloadPath(
    Uri uri, {
    required String tag,
    required String assetName,
  }) {
    final segments = uri.pathSegments;
    return segments.length == 6 &&
        segments[0] == owner &&
        segments[1] == repository &&
        segments[2] == 'releases' &&
        segments[3] == 'download' &&
        segments[4] == tag &&
        segments[5] == assetName;
  }

  bool _hasSafeDownloadRedirects(HttpClientResponse response) {
    return response.redirects.every(
      (redirect) =>
          redirect.location.scheme == 'https' &&
          const {
            'github.com',
            'release-assets.githubusercontent.com',
          }.contains(redirect.location.host),
    );
  }

  Future<String> _readBounded(HttpClientResponse response, int maximum) async {
    if (response.contentLength > maximum) {
      throw const UpdateException('GitHub release response was too large.');
    }
    final bytes = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in response) {
      length += chunk.length;
      if (length > maximum) {
        throw const UpdateException('GitHub release response was too large.');
      }
      bytes.add(chunk);
    }
    return utf8.decode(bytes.takeBytes());
  }
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    required this.latestVersion,
    required this.apkName,
    required this.apkDownloadUrl,
    required this.releaseUrl,
    required this.updateAvailable,
    this.downloadSizeBytes,
  });

  final SemanticVersion currentVersion;
  final SemanticVersion latestVersion;
  final String apkName;
  final Uri apkDownloadUrl;
  final Uri releaseUrl;
  final int? downloadSizeBytes;
  final bool updateAvailable;
}

class SemanticVersion implements Comparable<SemanticVersion> {
  const SemanticVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  static final _pattern = RegExp(r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$');

  static SemanticVersion? tryParse(String value) {
    final match = _pattern.firstMatch(value);
    if (match == null) {
      return null;
    }

    return SemanticVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  @override
  int compareTo(SemanticVersion other) {
    final majorCompare = major.compareTo(other.major);
    if (majorCompare != 0) {
      return majorCompare;
    }

    final minorCompare = minor.compareTo(other.minor);
    if (minorCompare != 0) {
      return minorCompare;
    }

    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';
}

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
