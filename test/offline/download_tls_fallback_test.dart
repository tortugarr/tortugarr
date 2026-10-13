import 'package:background_downloader/background_downloader.dart' as bgd;
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/download_service.dart';

// Android maps every IOException to a file system exception, and
// SSLHandshakeException is one, so a refused certificate never arrives as the
// connection exception it reads like. Keying the check on the type left
// downloads from a self-signed server stuck at zero with no fallback.
void main() {
  test('a refused certificate is caught whatever type it arrives as', () {
    const trustAnchor =
        'javax.net.ssl.SSLHandshakeException: '
        'java.security.cert.CertPathValidatorException: '
        'Trust anchor for certification path not found.';

    expect(looksLikeTlsError(bgd.TaskFileSystemException(trustAnchor)), isTrue);
    expect(looksLikeTlsError(bgd.TaskConnectionException(trustAnchor)), isTrue);
    expect(looksLikeTlsError(bgd.TaskException(trustAnchor)), isTrue);
  });

  test('an ordinary failure is left to the normal error path', () {
    expect(
      looksLikeTlsError(
        bgd.TaskFileSystemException('java.io.IOException: No space left'),
      ),
      isFalse,
    );
    expect(
      looksLikeTlsError(bgd.TaskConnectionException('Task timed out')),
      isFalse,
    );
    expect(looksLikeTlsError(null), isFalse);
  });
}
