import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recall_app/src/updates/update_service.dart';

void main() {
  group('SemanticVersion', () {
    test('parses bare semantic versions', () {
      expect(SemanticVersion.tryParse('0.1.1').toString(), '0.1.1');
      expect(SemanticVersion.tryParse('10.20.30').toString(), '10.20.30');
    });

    test('rejects non-release versions', () {
      expect(SemanticVersion.tryParse('dev'), isNull);
      expect(SemanticVersion.tryParse('v1.2.3'), isNull);
      expect(SemanticVersion.tryParse('1.2.3-beta.1'), isNull);
      expect(SemanticVersion.tryParse('01.2.3'), isNull);
    });

    test('compares version components numerically', () {
      expect(
        SemanticVersion.tryParse(
          '0.1.2',
        )!.compareTo(SemanticVersion.tryParse('0.1.1')!),
        isPositive,
      );
      expect(
        SemanticVersion.tryParse(
          '0.10.0',
        )!.compareTo(SemanticVersion.tryParse('0.9.9')!),
        isPositive,
      );
      expect(
        SemanticVersion.tryParse(
          '2.0.0',
        )!.compareTo(SemanticVersion.tryParse('10.0.0')!),
        isNegative,
      );
    });
  });

  group('download cleanup', () {
    late Directory temporaryDirectory;
    late UpdateService service;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'recall-update-test-',
      );
      service = UpdateService(
        temporaryDirectoryProvider: () async => temporaryDirectory,
      );
    });

    tearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test('removes completed and partial Recall APKs only', () async {
      final downloads = Directory(
        '${temporaryDirectory.path}${Platform.pathSeparator}downloads',
      );
      await downloads.create();
      final oldApk = File(
        '${downloads.path}${Platform.pathSeparator}recall-android-0.1.12.apk',
      );
      final partialApk = File(
        '${downloads.path}${Platform.pathSeparator}recall-android-0.1.13.apk.part',
      );
      final unrelatedFile = File(
        '${downloads.path}${Platform.pathSeparator}keep.txt',
      );
      await oldApk.writeAsBytes([1]);
      await partialApk.writeAsBytes([2]);
      await unrelatedFile.writeAsString('keep');

      await service.cleanupStaleDownloads();

      expect(await oldApk.exists(), isFalse);
      expect(await partialApk.exists(), isFalse);
      expect(await unrelatedFile.exists(), isTrue);
    });

    test('runs cleanup before validating a new download', () async {
      final downloads = Directory(
        '${temporaryDirectory.path}${Platform.pathSeparator}downloads',
      );
      await downloads.create();
      final oldApk = File(
        '${downloads.path}${Platform.pathSeparator}recall-android-0.1.12.apk',
      );
      await oldApk.writeAsBytes([1]);
      final invalidUpdate = UpdateCheckResult(
        currentVersion: const SemanticVersion(0, 1, 12),
        latestVersion: const SemanticVersion(0, 1, 13),
        apkName: 'recall-android-0.1.13.apk',
        apkDownloadUrl: Uri.parse('https://example.com/update.apk'),
        releaseUrl: Uri.parse('https://example.com/releases/0.1.13'),
        downloadSizeBytes: 1,
        updateAvailable: true,
      );

      await expectLater(
        service.downloadApk(invalidUpdate),
        throwsA(isA<UpdateException>()),
      );

      expect(await oldApk.exists(), isFalse);
    });

    test('cancels an active response and removes its partial APK', () async {
      final responseController = StreamController<List<int>>();
      addTearDown(responseController.close);
      service = UpdateService(
        httpClient: _FakeHttpClient(
          _FakeHttpClientResponse(responseController.stream, contentLength: 2),
        ),
        temporaryDirectoryProvider: () async => temporaryDirectory,
      );
      final cancellationToken = UpdateCancellationToken();
      final receivedFirstChunk = Completer<void>();
      const apkName = 'recall-android-0.1.14.apk';
      final update = UpdateCheckResult(
        currentVersion: const SemanticVersion(0, 1, 13),
        latestVersion: const SemanticVersion(0, 1, 14),
        apkName: apkName,
        apkDownloadUrl: Uri.parse(
          'https://github.com/spamalot22/recall/releases/download/0.1.14/$apkName',
        ),
        releaseUrl: Uri.parse(
          'https://github.com/spamalot22/recall/releases/tag/0.1.14',
        ),
        downloadSizeBytes: 2,
        updateAvailable: true,
      );

      final download = service.downloadApk(
        update,
        cancellationToken: cancellationToken,
        onProgress: (received, _) {
          if (received == 1 && !receivedFirstChunk.isCompleted) {
            receivedFirstChunk.complete();
          }
        },
      );
      responseController.add([1]);
      await receivedFirstChunk.future;
      cancellationToken.cancel();

      await expectLater(download, throwsA(isA<UpdateCancelledException>()));
      final partialApk = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}downloads'
        '${Platform.pathSeparator}$apkName.part',
      );
      expect(await partialApk.exists(), isFalse);
    });
  });
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient(this.response);

  final HttpClientResponse response;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _FakeHttpClientRequest(response);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this.response);

  final HttpClientResponse response;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  bool followRedirects = false;

  @override
  int maxRedirects = 0;

  @override
  Future<HttpClientResponse> close() async => response;

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse(this._stream, {required this.contentLength});

  final Stream<List<int>> _stream;

  @override
  final int contentLength;

  @override
  int get statusCode => HttpStatus.ok;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
