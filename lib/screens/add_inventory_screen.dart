import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart' show fetchCsInventory, Item;

// ── Theme colors (matching app-wide palette)
const Color _bg = Color(0xFF060E06);
const Color _cardBg = Color(0xFF0C1A0C);
const Color _green = Color(0xFF4ADE80);
const Color _cardBorder = Color(0xFF1A3520);
const Color _textDim = Color(0xFF6B8A6B);
const Color _inputBg = Color(0xFF0A160A);

// ─────────────────────────────────────────
// Inventory Setup Screen (kein Inventar hinterlegt)
// ─────────────────────────────────────────
class InventorySetupScreen extends StatefulWidget {
  /// Wird aufgerufen wenn das Inventar erfolgreich geladen wurde.
  /// Übergibt die Steam-ID und die geladenen Items.
  final void Function(String steamId, List<Item> items) onInventoryLoaded;

  const InventorySetupScreen({super.key, required this.onInventoryLoaded});

  @override
  State<InventorySetupScreen> createState() => _InventorySetupScreenState();
}

class _InventorySetupScreenState extends State<InventorySetupScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    final id = _controller.text.trim();
    if (id.isEmpty) {
      setState(() => _error = 'Bitte gib deine SteamID64 ein.');
      return;
    }
    if (!RegExp(r'^\d{15,20}$').hasMatch(id)) {
      setState(() => _error = 'Ungültige SteamID64. Sie sollte mit 7656119... beginnen.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await fetchCsInventory(id);
      if (!mounted) return;
      widget.onInventoryLoaded(id, items);
    } catch (e) {
      if (!mounted) return;
      String msg = e.toString();
      if (msg.contains('403') || msg.contains('Privat') || msg.contains('private')) {
        msg = 'Dein Steam-Profil ist privat. Bitte setze dein Inventar auf "Öffentlich" und versuche es erneut.';
      } else if (msg.contains('timeout') || msg.contains('SocketException')) {
        msg = 'Verbindungsfehler. Bitte überprüfe deine Internetverbindung.';
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openSteamIdHelp() async {
    final uri = Uri.parse('https://steamid.io/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return GestureDetector(
      onTap: () => _focusNode.unfocus(),
      child: Container(
        color: _bg,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: topPad + 16),

              // ── Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _InventarHeader(),
              ),

              const SizedBox(height: 48),

              // ── Icon + Titel + Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Box-Icon
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _cardBorder, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: _green,
                        size: 36,
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'Inventar hinzufügen',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Gib deine Steam-ID (76561...) ein, um deine Skins zu synchronisieren und deinen Inventarwert zu berechnen.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textDim,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ── Input + Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Label
                    const Text(
                      'STEAM-ID (STEAMID64)',
                      style: TextStyle(
                        color: _green,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Input field
                    _SteamIdInput(
                      controller: _controller,
                      focusNode: _focusNode,
                      enabled: !_loading,
                      onSubmitted: (_) => _loadInventory(),
                    ),

                    // Error message
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFEF4444),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),

                    // INVENTAR LADEN button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _loadInventory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          disabledBackgroundColor: const Color(0xFF1A3520),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.black,
                                ),
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.sync_rounded,
                                    color: Colors.black,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'INVENTAR LADEN',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Help link
                    Center(
                      child: GestureDetector(
                        onTap: _openSteamIdHelp,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              color: _green,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Wo finde ich meine Steam-ID?',
                              style: TextStyle(
                                color: _green,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: _green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Privacy note card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _cardBorder, width: 1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            color: _textDim,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Deine Privatsphäre-Einstellungen bei Steam müssen auf "Öffentlich" gesetzt sein, damit wir dein Inventar laden können.',
                              style: TextStyle(
                                color: _textDim,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Header
// ─────────────────────────────────────────
class _InventarHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // App logo
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/images/logo.png',
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B00), Color(0xFFFFD600)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: const Icon(Icons.whatshot, color: Colors.white, size: 24),
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Text(
          'INVENTAR',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Steam-ID Input Field
// ─────────────────────────────────────────
class _SteamIdInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  const _SteamIdInput({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    this.onSubmitted,
  });

  @override
  State<_SteamIdInput> createState() => _SteamIdInputState();
}

class _SteamIdInputState extends State<_SteamIdInput> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused ? _green : _cardBorder,
          width: _focused ? 1.5 : 1,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        enabled: widget.enabled,
        keyboardType: TextInputType.number,
        onSubmitted: widget.onSubmitted,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: '76561198...',
          hintStyle: const TextStyle(color: _textDim, fontSize: 16),
          suffixIcon: const Icon(
            Icons.fingerprint_rounded,
            color: _textDim,
            size: 22,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
