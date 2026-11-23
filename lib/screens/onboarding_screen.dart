import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monu/core/app_colors.dart';
import 'package:monu/core/app_dimens.dart';
import 'package:monu/core/app_info.dart';
import 'package:monu/core/app_text.dart';
import 'package:monu/widgets/fade_slide_in.dart';
import 'package:monu/widgets/forest_background.dart';
import 'package:monu/widgets/glass_card.dart';
import 'package:monu/widgets/glass_pill.dart';
import 'package:monu/widgets/primary_button.dart';

const Color _accentGreen = Color(0xFF7ED39A);
const String _markAsset = 'assets/images/monu_mark.png';

/// Halaman awal. Tombol "Masuk" memanggil [onEnter]
/// (nanti disambungkan ke halaman Login).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onEnter});

  final VoidCallback onEnter;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _initialPage = 1; // kartu tengah = Monitoring Lingkungan

  static const List<_CardData> _cards = [
    _CardData(
      kind: _PreviewKind.device,
      badgeIcon: Icons.bolt,
      title: 'Status Perangkat',
      info: 'Online',
      infoIcon: Icons.circle,
    ),
    _CardData(
      kind: _PreviewKind.monitoring,
      badgeIcon: Icons.eco,
      title: 'Monitoring Lingkungan',
      info: 'Kalimantan, Indonesia',
      infoIcon: Icons.location_on,
    ),
    _CardData(
      kind: _PreviewKind.app,
      badgeIcon: Icons.smartphone,
      title: 'Aplikasi Pemantauan',
      info: 'Pelajari lebih lanjut',
      arrowAfter: true,
    ),
    _CardData(
      kind: _PreviewKind.map,
      badgeIcon: Icons.map_outlined,
      title: 'Peta Lokasi',
      info: 'Pantau titik sensor di hutan',
      infoIcon: Icons.place,
    ),
  ];

  int _current = _initialPage;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: ForestBackground(
          child: SafeArea(
            minimum: const EdgeInsets.only(top: 20, bottom: 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double w = constraints.maxWidth;
                final double buttonWidth =
                    math.min(300.0, math.max(230.0, w * 0.64));

                return Column(
                  children: [
                    const SizedBox(height: 14),
                    const FadeSlideIn(child: _TopBadge()),
                    const SizedBox(height: 22),
                    const FadeSlideIn(
                      delay: Duration(milliseconds: 100),
                      child: _Headline(),
                    ),
                    const SizedBox(height: 16),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 200),
                      child: _SubtitlePill(maxWidth: w * 0.78),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: FadeSlideIn(
                        delay: const Duration(milliseconds: 300),
                        child: _CardCarousel(
                          cards: _cards,
                          initialPage: _initialPage,
                          onPageChanged: (index) =>
                              setState(() => _current = index),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _Dots(count: _cards.length, current: _current),
                    const SizedBox(height: 26),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 450),
                      child: SizedBox(
                        width: buttonWidth,
                        child: PrimaryButton(
                          label: 'Masuk ke ${AppInfo.appName}',
                          icon: Icons.arrow_forward_rounded,
                          height: 48,
                          fontSize: 14.5,
                          onPressed: widget.onEnter,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bagian atas: badge, judul, subjudul
// ---------------------------------------------------------------------------

class _Mark extends StatelessWidget {
  const _Mark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _markAsset,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.eco_outlined, size: size, color: AppColors.forest),
    );
  }
}

class _TopBadge extends StatelessWidget {
  const _TopBadge();

  @override
  Widget build(BuildContext context) {
    return GlassPill(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Mark(size: 24),
          const SizedBox(width: 8),
          Text(
            AppInfo.appName,
            style: AppText.label.copyWith(
              color: AppColors.forest,
              fontSize: 14,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    final TextStyle base = GoogleFonts.playfairDisplay(
      fontSize: 35,
      fontWeight: FontWeight.w500,
      color: AppColors.forest,
      height: 1.12,
    );
    final TextStyle italic = GoogleFonts.playfairDisplay(
      fontSize: 46,
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.italic,
      color: AppColors.forest,
      height: 1.2,
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Jaga Hutan,', textAlign: TextAlign.center, style: base),
          Text('Pantau dari', textAlign: TextAlign.center, style: base),
          Text('Mana Saja', textAlign: TextAlign.center, style: italic),
        ],
      ),
    );
  }
}

class _SubtitlePill extends StatelessWidget {
  const _SubtitlePill({required this.maxWidth});

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final String text =
        AppInfo.tagline.replaceFirst('peringatan dini', 'peringatan\ndini');

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: GlassCard(
        radius: 22,
        blur: 12,
        showShadow: false,
        tint: Colors.white.withValues(alpha: 0.42),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppText.bodySoft.copyWith(
              color: AppColors.ink,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: AppRadius.pill,
      blur: 10,
      showShadow: false,
      tint: Colors.white.withValues(alpha: 0.30),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (index) {
          final bool active = index == current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3.5),
            width: active ? 16 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(7),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data kartu
// ---------------------------------------------------------------------------

enum _PreviewKind { monitoring, device, app, map }

class _CardData {
  const _CardData({
    required this.kind,
    required this.badgeIcon,
    required this.title,
    required this.info,
    this.infoIcon,
    this.arrowAfter = false,
  });

  final _PreviewKind kind;
  final IconData badgeIcon;
  final String title;
  final String info;
  final IconData? infoIcon;
  final bool arrowAfter;
}

// ---------------------------------------------------------------------------
// Carousel kartu bertumpuk (kartu tengah di atas, kiri-kanan terselip)
// ---------------------------------------------------------------------------

class _CardCarousel extends StatefulWidget {
  const _CardCarousel({
    required this.cards,
    required this.initialPage,
    required this.onPageChanged,
  });

  final List<_CardData> cards;
  final int initialPage;
  final ValueChanged<int> onPageChanged;

  @override
  State<_CardCarousel> createState() => _CardCarouselState();
}

class _CardCarouselState extends State<_CardCarousel>
    with SingleTickerProviderStateMixin {
  late double _page = widget.initialPage.toDouble();
  late int _reported = widget.initialPage;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  Animation<double> _animation = const AlwaysStoppedAnimation<double>(0);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTick);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTick() {
    setState(() => _page = _animation.value);
    _report();
  }

  void _report() {
    final int rounded = _page.round();
    if (rounded != _reported) {
      _reported = rounded;
      widget.onPageChanged(rounded);
    }
  }

  void _onDragUpdate(DragUpdateDetails details, double spacing) {
    _controller.stop();
    final double maxPage = (widget.cards.length - 1).toDouble();
    setState(() {
      _page = (_page - details.delta.dx / spacing).clamp(0.0, maxPage).toDouble();
    });
    _report();
  }

  void _onDragEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    int target = _page.round();
    if (velocity < -350) {
      target = _page.floor() + 1;
    } else if (velocity > 350) {
      target = _page.ceil() - 1;
    }
    _animateTo(target);
  }

  void _animateTo(int index) {
    final int target = index.clamp(0, widget.cards.length - 1).toInt();
    _animation = Tween<double>(begin: _page, end: target.toDouble()).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        final double cardH = math.max(0.0, math.min(h, w * 0.80));
        final double cardW = math.min(cardH * 0.73, w * 0.60);
        final double spacing = cardW * 0.46;
        final double top = (h - cardH) / 2;

        // Kartu paling jauh digambar duluan, kartu terdekat paling atas.
        final List<int> order = List<int>.generate(widget.cards.length, (i) => i)
          ..sort(
            (a, b) => (b - _page).abs().compareTo((a - _page).abs()),
          );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) => _onDragUpdate(details, spacing),
          onHorizontalDragEnd: _onDragEnd,
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              children: [
                for (final int i in order)
                  _buildCard(i, w, cardW, cardH, top, spacing),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(
    int i,
    double w,
    double cardW,
    double cardH,
    double top,
    double spacing,
  ) {
    final double offset = i - _page;
    final double dist = offset.abs();
    final double scale = 1.0 - 0.14 * math.min(dist, 1.0);
    final double opacity = math.max(0.0, math.min(1.0, 2.0 - dist));
    if (opacity <= 0) return const SizedBox.shrink();

    final double left = w / 2 + offset * spacing - cardW / 2;

    return Positioned(
      left: left,
      top: top,
      width: cardW,
      height: cardH,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: dist > 0.5 ? () => _animateTo(i) : null,
            child: _ShowcaseCard(data: widget.cards[i], width: cardW),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Satu kartu: foto/pratinjau + gradient gelap + teks putih di bawah
// ---------------------------------------------------------------------------

class _ShowcaseCard extends StatelessWidget {
  const _ShowcaseCard({required this.data, required this.width});

  final _CardData data;
  final double width;

  @override
  Widget build(BuildContext context) {
    final double radius = width * 0.14;
    final double pad = width * 0.12;
    final double badge = width * 0.17;
    final BorderRadius borderRadius = BorderRadius.circular(radius);

    final TextStyle infoStyle = GoogleFonts.poppins(
      fontSize: width * 0.056,
      fontWeight: FontWeight.w400,
      color: Colors.white,
      height: 1.3,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.22),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 2.4,
        ),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _CardPreview(kind: data.kind),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.62),
                    ],
                    stops: const [0.45, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              left: pad,
              top: pad * 0.95,
              child: _CircleBadge(icon: data.badgeIcon, size: badge),
            ),
            Positioned(
              left: pad,
              right: pad * 0.6,
              bottom: width * 0.11,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: width * 0.088,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: width * 0.04),
                  Row(
                    children: [
                      if (data.infoIcon != null) ...[
                        Icon(
                          data.infoIcon,
                          size: data.infoIcon == Icons.circle
                              ? width * 0.04
                              : width * 0.075,
                          color: _accentGreen,
                        ),
                        SizedBox(width: width * 0.025),
                      ],
                      Flexible(
                        child: Text(
                          data.info,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: infoStyle,
                        ),
                      ),
                      if (data.arrowAfter) ...[
                        SizedBox(width: width * 0.02),
                        Icon(
                          Icons.arrow_forward,
                          size: width * 0.065,
                          color: Colors.white,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleBadge extends StatelessWidget {
  const _CircleBadge({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.55, color: AppColors.forest),
    );
  }
}

// ---------------------------------------------------------------------------
// Pratinjau di dalam kartu
// ---------------------------------------------------------------------------

class _CardPreview extends StatelessWidget {
  const _CardPreview({required this.kind});

  final _PreviewKind kind;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case _PreviewKind.monitoring:
        return const _MiniScreen();
      case _PreviewKind.app:
        return const _MiniScreen();
      case _PreviewKind.device:
        return const ForestBackground(child: _DeviceRows());
      case _PreviewKind.map:
        return const ForestBackground(child: _PinsPreview());
    }
  }
}

/// Miniatur tampilan app (screenshot mini) untuk kartu tengah dan kanan.
class _MiniScreen extends StatelessWidget {
  const _MiniScreen();

  @override
  Widget build(BuildContext context) {
    final TextStyle heading = GoogleFonts.playfairDisplay(
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: AppColors.forest,
      height: 1.12,
    );
    final TextStyle italic = GoogleFonts.playfairDisplay(
      fontSize: 29,
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.italic,
      color: AppColors.forest,
      height: 1.2,
    );

    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: 300,
        height: 411,
        child: ForestBackground(
          child: Column(
            children: [
              const SizedBox(height: 24),
              const _MiniBadge(),
              const SizedBox(height: 12),
              Text(
                'Jaga Hutan,\nPantau dari',
                textAlign: TextAlign.center,
                style: heading,
              ),
              Text('Mana Saja', textAlign: TextAlign.center, style: italic),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
                ),
                child: Text(
                  'Pemantauan lingkungan dan peringatan\ndini dalam satu genggaman.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 7.5,
                    color: AppColors.ink,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 120, child: _MiniCards()),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.mist.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Mark(size: 13),
          const SizedBox(width: 5),
          Text(
            'DiHutan',
            style: GoogleFonts.poppins(
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward, size: 9, color: AppColors.forest),
        ],
      ),
    );
  }
}

Widget _miniGlass({required Widget child}) {
  return Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.30),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 1.2),
    ),
    child: child,
  );
}

Widget _miniPhoto({Widget? child}) {
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(11),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.sage.withValues(alpha: 0.55),
          AppColors.forest.withValues(alpha: 0.85),
        ],
      ),
    ),
    child: child,
  );
}

Widget _miniBar(double width) {
  return Container(
    width: width,
    height: 4,
    margin: const EdgeInsets.only(top: 3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

class _MiniCards extends StatelessWidget {
  const _MiniCards();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 6,
          top: 16,
          width: 76,
          height: 100,
          child: _miniGlass(
            child: _miniPhoto(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [_miniBar(34), _miniBar(22)],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 218,
          top: 16,
          width: 76,
          height: 100,
          child: _miniGlass(
            child: _miniPhoto(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [_miniBar(30), _miniBar(40)],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 88,
          top: 0,
          width: 124,
          height: 118,
          child: _miniGlass(
            child: _miniPhoto(
              child: const Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.all(6),
                  child: CircleAvatar(
                    radius: 8,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.eco, size: 10, color: AppColors.forest),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniRowData {
  const _MiniRowData(this.title, this.subtitle, this.trailing, this.color);

  final String title;
  final String subtitle;
  final String trailing;
  final Color color;
}

class _DeviceRows extends StatelessWidget {
  const _DeviceRows();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 64, 14, 0),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 170,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              _MiniRow(
                item: _MiniRowData(
                  'Node Hutan 1',
                  'Baterai 87%',
                  'Online',
                  AppColors.safe,
                ),
              ),
              SizedBox(height: 8),
              _MiniRow(
                item: _MiniRowData(
                  'Node Hutan 2',
                  'Baterai 64%',
                  'Online',
                  AppColors.safe,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniRow extends StatelessWidget {
  const _MiniRow({required this.item});

  final _MiniRowData item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label.copyWith(fontSize: 12),
                ),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.trailing,
            style: AppText.label.copyWith(fontSize: 12, color: item.color),
          ),
        ],
      ),
    );
  }
}

class _PinsPreview extends StatelessWidget {
  const _PinsPreview();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      child: Stack(
        children: [
          Align(
            alignment: Alignment(-0.45, -0.25),
            child: _Pin(color: AppColors.safe),
          ),
          Align(
            alignment: Alignment(0.4, -0.5),
            child: _Pin(color: AppColors.warning),
          ),
          Align(
            alignment: Alignment(0.1, 0.1),
            child: _Pin(color: AppColors.danger),
          ),
        ],
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.location_on,
      size: 34,
      color: color,
      shadows: const [Shadow(color: Colors.black26, blurRadius: 6)],
    );
  }
}