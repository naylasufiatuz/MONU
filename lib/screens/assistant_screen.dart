import 'package:flutter/material.dart';
import 'package:monu/core/app_colors.dart';
import 'package:monu/core/app_dimens.dart';
import 'package:monu/core/app_text.dart';
import 'package:monu/core/formatters.dart';
import 'package:monu/core/routes.dart';
import 'package:monu/providers/assistant_provider.dart';
import 'package:monu/providers/monitor_provider.dart';
import 'package:monu/repositories/mock_sensor_repository.dart';
import 'package:monu/services/assistant_models.dart';
import 'package:monu/widgets/forest_background.dart';
import 'package:monu/widgets/glass_card.dart';
import 'package:monu/widgets/monu_mark.dart';
import 'package:monu/widgets/page_header.dart';
import 'package:monu/widgets/primary_button.dart';
import 'package:provider/provider.dart';

/// Membuka asisten. [question] (opsional) langsung dikirim saat halaman terbuka.
void openAssistant(BuildContext context, {String? question}) {
  Navigator.of(context)
      .push(fadeRoute(AssistantScreen(initialQuestion: question)));
}

void _openSettings(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _AiSettingsSheet(),
  );
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, this.initialQuestion});

  final String? initialQuestion;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  int _lastCount = 0;
  bool _lastBusy = false;

  @override
  void initState() {
    super.initState();
    final String? q = widget.initialQuestion;
    if (q != null && q.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<AssistantProvider>().send(q);
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    _input.clear();
    context.read<AssistantProvider>().send(text);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  List<String> _suggestions(MonitorProvider m) {
    final List<String> s = <String>[];
    if (m.isOffline) s.add('Kenapa perangkat offline?');
    if (m.activeAlerts.isNotEmpty) {
      s.add('Kenapa ada peringatan?');
      s.add('Apa yang harus kuperiksa?');
    } else {
      s.add('Ringkas kondisi sekarang');
    }
    s.addAll(<String>[
      'Apakah ini tanda kebakaran?',
      'Apa arti nilai MQ-2?',
      'Bagaimana tren suhu?',
      'Kapan sensor perlu dikalibrasi?',
    ]);
    return s.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final AssistantProvider ai = context.watch<AssistantProvider>();
    final MonitorProvider monitor = context.watch<MonitorProvider>();
    final List<ChatMessage> msgs = ai.messages;

    if (msgs.length != _lastCount || ai.busy != _lastBusy) {
      _lastCount = msgs.length;
      _lastBusy = ai.busy;
      _scrollToEnd();
    }

    return Scaffold(
      body: ForestBackground(
        strong: true,
        child: SafeArea(
          child: Column(
            children: [
              PageHeader(
                eyebrow: ai.hasKey ? 'Ditenagai Gemini' : 'Mode Contoh (tanpa AI)',
                title: 'Tanya MONU',
                leading: CircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleIconButton(
                      icon: Icons.tune,
                      onTap: () => _openSettings(context),
                    ),
                    const SizedBox(width: 8),
                    CircleIconButton(
                      icon: Icons.delete_outline,
                      onTap: msgs.isEmpty ? () {} : ai.clearChat,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  children: [
                    if (msgs.isEmpty)
                      _Welcome(
                        hasKey: ai.hasKey,
                        onSetup: () => _openSettings(context),
                      ),
                    for (final ChatMessage m in msgs) _Bubble(message: m),
                    if (ai.busy) const _TypingBubble(),
                  ],
                ),
              ),
              _SuggestionRow(
                items: _suggestions(monitor),
                enabled: !ai.busy,
                onTap: _send,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: _InputBar(
                  controller: _input,
                  busy: ai.busy,
                  onSend: _send,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Text(
                  'Jawaban AI bisa keliru dan bukan konfirmasi kebakaran.',
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(fontSize: 10.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kartu sambutan
// ---------------------------------------------------------------------------

class _Welcome extends StatelessWidget {
  const _Welcome({required this.hasKey, required this.onSetup});

  final bool hasKey;
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MonuMark(size: 44),
            const SizedBox(height: 14),
            Text('Hai, aku Asisten MONU', style: AppText.headline),
            const SizedBox(height: 6),
            Text(
              'Tanya apa saja soal kondisi sensor, status, dan peringatan. Aku membaca data terbaru dari perangkat setiap kamu bertanya.',
              style: AppText.bodySoft,
            ),
            if (!hasKey) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sekarang memakai Mode Contoh (jawaban berbasis aturan).',
                      style: AppText.label,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pasang kunci Gemini gratis untuk jawaban AI yang lebih pintar dan luwes.',
                      style: AppText.caption,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: onSetup,
                      child: const Text('Aktifkan Gemini'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gelembung percakapan
// ---------------------------------------------------------------------------

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final bool user = message.role == ChatRole.user;
    final double maxWidth = MediaQuery.of(context).size.width * 0.78;
    final BorderRadius radius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(user ? 20 : 6),
      bottomRight: Radius.circular(user ? 6 : 20),
    );

    final Widget bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: user
            ? AppColors.forestDeep
            : Colors.white.withValues(alpha: 0.88),
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: user
          ? Text(
              message.text,
              style: AppText.body.copyWith(color: Colors.white),
            )
          : SelectableText.rich(_markdown(message.text, AppText.body)),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment:
            user ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!user) ...[const _Avatar(), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  user ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                bubble,
                const SizedBox(height: 4),
                if (message.note != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Text(
                        message.note!,
                        style: AppText.caption.copyWith(
                          fontSize: 10.5,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ),
                Text(
                  Fmt.hourMinute(message.time),
                  style: AppText.caption.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const MonuMark(size: 18),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          const _Avatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(6),
              ),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(3, (i) {
            final double phase = (_c.value + i * 0.2) % 1.0;
            final double o =
                0.3 + 0.7 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.forest.withValues(alpha: o),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Saran pertanyaan dan kolom input
// ---------------------------------------------------------------------------

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.items,
    required this.enabled,
    required this.onTap,
  });

  final List<String> items;
  final bool enabled;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          return Opacity(
            opacity: enabled ? 1 : 0.5,
            child: GestureDetector(
              onTap: enabled ? () => onTap(items[i]) : null,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: AppColors.forest.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  items[i],
                  style: AppText.label.copyWith(fontSize: 12.5),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool busy;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 28,
      blur: 16,
      showShadow: false,
      tint: Colors.white.withValues(alpha: 0.72),
      padding: const EdgeInsets.fromLTRB(18, 4, 6, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: onSend,
              style: AppText.body,
              decoration: InputDecoration(
                hintText: 'Tanya soal kondisi hutan…',
                hintStyle: AppText.bodySoft,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 6),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final bool canSend = !busy && value.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: canSend ? () => onSend(controller.text) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: canSend
                        ? AppColors.forestDeep
                        : AppColors.inkSoft.withValues(alpha: 0.35),
                  ),
                  child: const Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pengaturan AI (kunci, model, simulasi data)
// ---------------------------------------------------------------------------

class _AiSettingsSheet extends StatefulWidget {
  const _AiSettingsSheet();

  @override
  State<_AiSettingsSheet> createState() => _AiSettingsSheetState();
}

class _AiSettingsSheetState extends State<_AiSettingsSheet> {
  final TextEditingController _key = TextEditingController();
  late final TextEditingController _model;
  bool _hide = true;
  bool _testing = false;
  bool _ok = false;
  String? _result;

  @override
  void initState() {
    super.initState();
    _model = TextEditingController(text: context.read<AssistantProvider>().model);
  }

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final AssistantProvider ai = context.read<AssistantProvider>();
    setState(() {
      _testing = true;
      _result = null;
    });
    final String? error = await ai.testGemini(
      apiKey: _key.text.trim(),
      model: _model.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _testing = false;
      _ok = error == null;
      _result = error ?? 'Berhasil! Gemini bisa dihubungi.';
    });
  }

  Future<void> _save() async {
    final AssistantProvider ai = context.read<AssistantProvider>();
    final NavigatorState navigator = Navigator.of(context);
    await ai.saveSettings(apiKey: _key.text, model: _model.text);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final AssistantProvider ai = context.watch<AssistantProvider>();
    final MonitorProvider monitor = context.watch<MonitorProvider>();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.fog,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.inkSoft.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Pengaturan AI', style: AppText.headline),
                const SizedBox(height: 4),
                Text(
                  ai.hasKey
                      ? 'Gemini aktif (kunci ${ai.maskedKey}).'
                      : 'Belum ada kunci, jadi memakai Mode Contoh.',
                  style: AppText.bodySoft,
                ),
                const SizedBox(height: 16),
                Text('Cara dapat kunci gratis', style: AppText.label),
                const SizedBox(height: 4),
                Text(
                  '1. Buka aistudio.google.com/apikey di browser\n'
                  '2. Masuk dengan akun Google\n'
                  '3. Klik "Create API key"\n'
                  '4. Salin kuncinya, tempel di bawah ini',
                  style: AppText.caption,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _key,
                  obscureText: _hide,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    hintText: ai.hasKey
                        ? 'Kosongkan untuk tetap memakai kunci lama'
                        : 'Tempel kunci API Gemini di sini',
                    prefixIcon: const Icon(Icons.key_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _hide
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _hide = !_hide),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _model,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'Nama model',
                    prefixIcon: Icon(Icons.memory_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: 'Simpan',
                        height: 48,
                        fontSize: 14,
                        onPressed: _save,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _testing ? null : _test,
                        child: Text(_testing ? 'Menguji…' : 'Tes'),
                      ),
                    ),
                  ],
                ),
                if (_result != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _ok ? Icons.check_circle_outline : Icons.error_outline,
                        size: 18,
                        color: _ok ? AppColors.safe : AppColors.danger,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _result!,
                          style: AppText.caption.copyWith(
                            color: _ok ? AppColors.safe : AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (ai.hasKey)
                  TextButton(
                    onPressed: () => ai.clearKey(),
                    child: const Text('Hapus kunci dari perangkat ini'),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Kunci hanya disimpan di perangkat ini dan tidak ditulis di kode. Isi percakapan dan data sensor dikirim ke Google untuk diproses, jadi jangan menulis data pribadi di chat.',
                  style: AppText.caption,
                ),
                if (monitor.isMock) ...[
                  const SizedBox(height: 20),
                  Text('Simulasi kondisi (Mode Demo)', style: AppText.label),
                  const SizedBox(height: 4),
                  Text(
                    'Ubah data demo untuk mencoba asisten saat ada peringatan.',
                    style: AppText.caption,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final DemoScenario s in DemoScenario.values)
                        GestureDetector(
                          onTap: () => monitor.setScenario(s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: monitor.scenario == s
                                  ? AppColors.forestDeep
                                  : Colors.white.withValues(alpha: 0.8),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              s.label,
                              style: AppText.label.copyWith(
                                fontSize: 12.5,
                                color: monitor.scenario == s
                                    ? Colors.white
                                    : AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Penampil teks sederhana: **tebal**, daftar "- ", dan judul "#"
// ---------------------------------------------------------------------------

TextSpan _markdown(String text, TextStyle base) {
  final List<InlineSpan> spans = <InlineSpan>[];
  final List<String> lines = text.split('\n');
  final RegExp bulletRe = RegExp(r'^\s*[-*•]\s+(.*)$');
  final RegExp headingRe = RegExp(r'^\s*#{1,4}\s+(.*)$');

  for (int i = 0; i < lines.length; i++) {
    String line = lines[i];
    bool boldAll = false;

    final RegExpMatch? bullet = bulletRe.firstMatch(line);
    final RegExpMatch? heading = headingRe.firstMatch(line);
    if (bullet != null) {
      line = '•  ${bullet.group(1)}';
    } else if (heading != null) {
      line = heading.group(1) ?? '';
      boldAll = true;
    }

    spans.addAll(
      _inline(line, boldAll ? base.copyWith(fontWeight: FontWeight.w700) : base),
    );
    if (i < lines.length - 1) spans.add(TextSpan(text: '\n', style: base));
  }
  return TextSpan(style: base, children: spans);
}

List<InlineSpan> _inline(String line, TextStyle base) {
  final List<InlineSpan> out = <InlineSpan>[];
  final RegExp bold = RegExp(r'\*\*(.+?)\*\*');
  int cursor = 0;
  for (final RegExpMatch m in bold.allMatches(line)) {
    if (m.start > cursor) {
      out.add(TextSpan(text: line.substring(cursor, m.start), style: base));
    }
    out.add(
      TextSpan(
        text: m.group(1),
        style: base.copyWith(fontWeight: FontWeight.w700),
      ),
    );
    cursor = m.end;
  }
  if (cursor < line.length) {
    out.add(TextSpan(text: line.substring(cursor), style: base));
  }
  return out;
}