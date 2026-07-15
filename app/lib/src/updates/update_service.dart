import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

class UpdateService {
  UpdateService({
    HttpClient? httpClient,
    Future<Directory> Function()? temporaryDirectoryProvider,
    this.owner = 'spamalot22',
    this.repository = 'recall',
  }) : _httpClient =
           httpClient ??
           (HttpClient()..connectionTimeout = const Duration(seconds: 15)),
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory;

  static const _maxMetadataBytes = 1024 * 1024;
  static const _maxApkBytes = 250 * 1024 * 1024;

  final HttpClient _httpClient;
  final Future<Directory> Function() _temporaryDirectoryProvider;
  final String owner;
  final String repository;

  Future<void> cleanupStaleDownloads() async {
    try {
      final directory = await _downloadsDirectory();
      if (!await directory.exists()) {
        return;
      }

      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File ||
            !_isUpdateArtifactName(p.basename(entity.path))) {
          continue;
        }
        try {
          await entity.delete();
        } on Exception {
          // Cache cleanup is best effort and must not block app startup.
        }
      }
    } on Exception {
      // Updates remain usable if Android has already reclaimed the cache.
    }
  }

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
    UpdateCancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    await cleanupStaleDownloads();
    cancellationToken?.throwIfCancelled();
    final directory = await _downloadsDirectory();
    if (!await directory.exists()) {
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
    void abortRequest() {
      request.abort(const UpdateCancelledException());
    }

    cancellationToken?.addListener(abortRequest);
    late final HttpClientResponse response;
    try {
      cancellationToken?.throwIfCancelled();
      response = await request.close();
    } on Object {
      if (cancellationToken?.isCancelled ?? false) {
        throw const UpdateCancelledException();
      }
      rethrow;
    } finally {
      cancellationToken?.removeListener(abortRequest);
    }
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
    final downloadFinished = Completer<void>();
    StreamSubscription<List<int>>? subscription;

    void cancelDownload() {
      if (!downloadFinished.isCompleted) {
        downloadFinished.completeError(
          const UpdateCancelledException(),
          StackTrace.current,
        );
      }
      unawaited(subscription?.cancel());
    }

    subscription = response.listen(
      (chunk) {
        if (downloadFinished.isCompleted) {
          return;
        }
        try {
          received += chunk.length;
          if (received > total || received > _maxApkBytes) {
            throw const UpdateException(
              'APK download exceeded its expected size.',
            );
          }
          sink.add(chunk);
          onProgress?.call(received, total);
        } on Object catch (error, stackTrace) {
          downloadFinished.completeError(error, stackTrace);
          unawaited(subscription?.cancel());
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!downloadFinished.isCompleted) {
          downloadFinished.completeError(error, stackTrace);
        }
      },
      onDone: () {
        if (!downloadFinished.isCompleted) {
          downloadFinished.complete();
        }
      },
      cancelOnError: true,
    );
    cancellationToken?.addListener(cancelDownload);
    try {
      await downloadFinished.future;
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
    } on Object catch (error, stackTrace) {
      try {
        await subscription.cancel();
      } on Object {
        // Preserve the original download failure.
      }
      try {
        await sink.close();
      } on Object {
        // Preserve the original download failure.
      }
      try {
        if (partialFile.existsSync()) {
          await partialFile.delete();
        }
      } on Object {
        // The next startup cleanup will retry removal.
      }
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      cancellationToken?.removeListener(cancelDownload);
    }
  }

  Future<Directory> _downloadsDirectory() async {
    final temporaryDirectory = await _temporaryDirectoryProvider();
    return Directory(p.join(temporaryDirectory.path, 'downloads'));
  }

  bool _isUpdateArtifactName(String fileName) {
    final apkName = fileName.endsWith('.part')
        ? fileName.substring(0, fileName.length - '.part'.length)
        : fileName;
    const prefix = 'recall-android-';
    const suffix = '.apk';
    if (!apkName.startsWith(prefix) || !apkName.endsWith(suffix)) {
      return false;
    }

    final version = apkName.substring(
      prefix.length,
      apkName.length - suffix.length,
    );
    return SemanticVersion.tryParse(version) != null;
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

class UpdateCancellationToken {
  final Completer<void> _cancelled = Completer<void>();
  final Set<void Function()> _listeners = {};

  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (isCancelled) {
      return;
    }
    _cancelled.complete();
    for (final listener in List<void Function()>.of(_listeners)) {
      try {
        listener();
      } on Object {
        // Cancellation must still reach the remaining listeners.
      }
    }
    _listeners.clear();
  }

  void addListener(void Function() listener) {
    if (isCancelled) {
      listener();
      return;
    }
    _listeners.add(listener);
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  void throwIfCancelled() {
    if (isCancelled) {
      throw const UpdateCancelledException();
    }
  }
}

class UpdateCancelledException implements Exception {
  const UpdateCancelledException();

  @override
  String toString() => 'Update download cancelled.';
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
