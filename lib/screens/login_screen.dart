import 'package:flutter/material.dart';
import 'package:monu/core/app_colors.dart';
import 'package:monu/core/app_dimens.dart';
import 'package:monu/core/app_text.dart';
import 'package:monu/providers/auth_provider.dart';
import 'package:monu/widgets/forest_background.dart';
import 'package:monu/widgets/glass_card.dart';
import 'package:monu/widgets/page_header.dart';
import 'package:monu/widgets/primary_button.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _register = false;
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final AuthProvider auth = context.read<AuthProvider>();
    setState(() {
      _busy = true;
      _error = null;
    });

    final String? error = _register
        ? await auth.register(
            name: _name.text,
            email: _email.text,
            password: _password.text,
          )
        : await auth.signIn(email: _email.text, password: _password.text);

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    // Halaman utama otomatis berganti ke app; tutup halaman login.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _demo() async {
    final AuthProvider auth = context.read<AuthProvider>();
    setState(() => _busy = true);
    await auth.signInDemo();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _switchMode(bool register) {
    setState(() {
      _register = register;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ForestBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: CircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
                const SizedBox(height: 4),
                Image.asset(
                  'assets/images/monu_logo.png',
                  width: 190,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      Text('MONU', style: AppText.display),
                ),
                const SizedBox(height: 4),
                Text(
                  _register ? 'Buat Akun' : 'Selamat Datang',
                  style: AppText.display.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _register
                      ? 'Daftar untuk mulai memantau hutan.'
                      : 'Masuk untuk memantau hutan dari mana saja.',
                  textAlign: TextAlign.center,
                  style: AppText.bodySoft.copyWith(color: AppColors.ink),
                ),
                const SizedBox(height: 20),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  tint: Colors.white.withValues(alpha: 0.5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ModeToggle(register: _register, onChanged: _switchMode),
                      const SizedBox(height: 18),
                      if (_register) ...[
                        TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            hintText: 'Nama',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: _hidePassword,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: 'Kata sandi',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _hidePassword = !_hidePassword),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 18,
                              color: AppColors.danger,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: AppText.caption.copyWith(
                                  color: AppColors.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),
                      PrimaryButton(
                        label: _register ? 'Daftar' : 'Masuk',
                        icon: Icons.arrow_forward_rounded,
                        height: 52,
                        loading: _busy,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: _busy ? null : _demo,
                        child: const Text('Lewati, coba Mode Demo'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Akun sementara disimpan di perangkat ini. Login Firebase dipasang di tahap Firebase.',
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(color: AppColors.ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.register, required this.onChanged});

  final bool register;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget button(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(vertical: 11),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.forestDeep : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              label,
              style: AppText.label.copyWith(
                color: selected ? Colors.white : AppColors.inkSoft,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          button('Masuk', !register, () => onChanged(false)),
          button('Daftar', register, () => onChanged(true)),
        ],
      ),
    );
  }
}