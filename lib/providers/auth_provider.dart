import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Login. Untuk sekarang berjalan secara lokal (mode demo, tanpa akun asli).
/// Nanti di Bagian Firebase, isi fungsi signIn/register diganti dengan
/// Firebase Auth. Tampilan tidak perlu diubah.
class AuthProvider extends ChangeNotifier {
  static const String _kLoggedIn = 'auth_logged_in';
  static const String _kName = 'auth_name';
  static const String _kEmail = 'auth_email';

  SharedPreferences? _prefs;
  bool _loaded = false;
  bool _loggedIn = false;
  String _name = '';
  String _email = '';

  bool get loaded => _loaded;
  bool get isLoggedIn => _loggedIn;
  String get name => _name.isEmpty ? 'Pengguna' : _name;
  String get email => _email;

  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    _loggedIn = prefs.getBool(_kLoggedIn) ?? false;
    _name = prefs.getString(_kName) ?? '';
    _email = prefs.getString(_kEmail) ?? '';
    _loaded = true;
    notifyListeners();
  }

  /// Mengembalikan pesan error, atau null jika berhasil.
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    final String mail = email.trim();
    if (!_isEmail(mail)) return 'Format email belum benar.';
    if (password.length < 6) return 'Kata sandi minimal 6 karakter.';

    final String name =
        (_email == mail && _name.isNotEmpty) ? _name : _nameFromEmail(mail);
    await _setSession(name: name, email: mail);
    return null;
  }

  /// Mengembalikan pesan error, atau null jika berhasil.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final String mail = email.trim();
    if (name.trim().isEmpty) return 'Nama belum diisi.';
    if (!_isEmail(mail)) return 'Format email belum benar.';
    if (password.length < 6) return 'Kata sandi minimal 6 karakter.';

    await _setSession(name: name.trim(), email: mail);
    return null;
  }

  Future<void> signInDemo() =>
      _setSession(name: 'Pengguna Demo', email: 'demo@monu.local');

  Future<void> updateName(String value) async {
    final String v = value.trim();
    if (v.isEmpty) return;
    _name = v;
    notifyListeners();
    await _prefs?.setString(_kName, v);
  }

  Future<void> signOut() async {
    _loggedIn = false;
    notifyListeners();
    await _prefs?.setBool(_kLoggedIn, false);
  }

  Future<void> _setSession({required String name, required String email}) async {
    _loggedIn = true;
    _name = name;
    _email = email;
    notifyListeners();
    await _prefs?.setBool(_kLoggedIn, true);
    await _prefs?.setString(_kName, name);
    await _prefs?.setString(_kEmail, email);
  }

  static bool _isEmail(String v) => v.contains('@') && v.contains('.');

  static String _nameFromEmail(String mail) {
    final String local = mail.split('@').first;
    if (local.isEmpty) return 'Pengguna';
    return local[0].toUpperCase() + local.substring(1);
  }
}