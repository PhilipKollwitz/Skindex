import 'package:flutter/material.dart';

const Color _bgColor = Color(0xFF0D0D0D);
const Color _accentGreen = Color(0xFF4ADE80);
const Color _cardBg = Color(0xFF1C1C1C);
const Color _subtitleColor = Color(0xFF9CA3AF);
const Color _dividerColor = Color(0xFF374151);

class LoginScreen extends StatelessWidget {
  final WidgetBuilder nextScreenBuilder;

  const LoginScreen({super.key, required this.nextScreenBuilder});

  void _navigate(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: nextScreenBuilder),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // iPhone 14 Pro: 393 × 852 logical px
    final screenH = mq.size.height;
    final topPad = mq.padding.top; // dynamic island / status bar
    final bottomPad = mq.padding.bottom; // home indicator

    // Scale hero font relative to screen height
    final heroFontSize = screenH * 0.047; // ~40 on 852pt

    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: topPad + 12),

          // ── Logo top-left
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _SkindexLogo(),
          ),

          SizedBox(height: screenH * 0.04),

          // ── "Entdecke die Community" pill
          Center(child: _CommunityPill()),

          SizedBox(height: screenH * 0.06),

          // ── Hero text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Text(
                  'Tracke dein',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: heroFontSize,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Inventar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _accentGreen,
                    fontSize: heroFontSize,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: screenH * 0.028),
                Text(
                  'Verfolge den Wert deiner Skins\nund entdecke neue Trends.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _subtitleColor,
                    fontSize: screenH * 0.019,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: screenH * 0.06),

          // ── Bottom card
          _LoginCard(
            onGoogleLogin: () => _navigate(context),
            onGuestLogin: () => _navigate(context),
            bottomPad: bottomPad,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Logo
// ─────────────────────────────────────────
class _SkindexLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/logo.png',
          width: 40,
          height: 40,
          errorBuilder: (_, _, _) => _FallbackIcon(),
        ),
        const SizedBox(width: 10),
        const Text(
          'Skindex',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B00), Color(0xFFFFD600)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: const Icon(Icons.whatshot, color: Colors.white, size: 24),
    );
  }
}

// ─────────────────────────────────────────
// Community pill
// ─────────────────────────────────────────
class _CommunityPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: _accentGreen, width: 1.5),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.language, color: _accentGreen, size: 16),
          SizedBox(width: 8),
          Text(
            'ENTDECKE DIE COMMUNITY',
            style: TextStyle(
              color: _accentGreen,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Bottom login card
// ─────────────────────────────────────────
class _LoginCard extends StatelessWidget {
  final VoidCallback onGoogleLogin;
  final VoidCallback onGuestLogin;
  final double bottomPad;

  const _LoginCard({
    required this.onGoogleLogin,
    required this.onGuestLogin,
    required this.bottomPad,
  });

  @override
  Widget build(BuildContext context) {
    final extraBottom = bottomPad > 0 ? bottomPad : 16.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: EdgeInsets.fromLTRB(24, 28, 24, 20 + extraBottom),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Werde Teil der Community',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Verwalte dein Inventar wie ein Profi.',
            style: TextStyle(color: _subtitleColor, fontSize: 14),
          ),
          const SizedBox(height: 22),

          // Google button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: onGoogleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CustomPaint(painter: _GoogleGPainter()),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Mit Google anmelden',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 22),

          // OR divider
          const Row(
            children: [
              Expanded(child: Divider(color: _dividerColor, thickness: 1)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'ODER',
                  style: TextStyle(
                    color: _subtitleColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Expanded(child: Divider(color: _dividerColor, thickness: 1)),
            ],
          ),

          const SizedBox(height: 20),

          // Guest link
          GestureDetector(
            onTap: onGuestLogin,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'Als Gast erkunden',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Google "G" icon (no external package)
// ─────────────────────────────────────────
class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final arcR = r * 0.72;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.36
      ..strokeCap = StrokeCap.butt;

    // Blue arc (top → left, ~270°)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: arcR),
      -0.52,
      4.19,
      false,
      paint,
    );

    // Re-paint right portion in correct colors
    // Green (bottom-left)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: arcR),
      1.83,
      1.57,
      false,
      paint,
    );

    // Yellow (bottom-right)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: arcR),
      3.40,
      0.79,
      false,
      paint,
    );

    // Red (top-right)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: arcR),
      4.19,
      0.79,
      false,
      paint,
    );

    // Horizontal bar of the G
    canvas.drawRect(
      Rect.fromLTRB(cx, cy - r * 0.18, cx + r * 0.90, cy + r * 0.18),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
