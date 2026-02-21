import 'package:encrypt/encrypt.dart' as encrypt;

/// AES encryption service for sensitive entry text.
/// Uses a key derived from a passphrase. Can be wired in as needed.
class EncryptionService {
  late final encrypt.Key _key;
  late final encrypt.IV _iv;
  late final encrypt.Encrypter _encrypter;

  EncryptionService({String? passphrase}) {
    // Generate a key from passphrase or use a default for development.
    // In production, derive this from user credentials or device keychain.
    final keyString = passphrase ?? _generateDefaultKey();
    _key = encrypt.Key.fromUtf8(keyString.padRight(32).substring(0, 32));
    _iv = encrypt.IV.fromLength(16);
    _encrypter = encrypt.Encrypter(encrypt.AES(_key));
  }

  /// Encrypt a plaintext string.
  String encryptText(String plainText) {
    final encrypted = _encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }

  /// Decrypt an encrypted string.
  String decryptText(String encryptedText) {
    final decrypted = _encrypter.decrypt64(encryptedText, iv: _iv);
    return decrypted;
  }

  String _generateDefaultKey() {
    // For development only — in production use secure key storage
    return 'emori_dev_key_32chars_padding!!';
  }
}
