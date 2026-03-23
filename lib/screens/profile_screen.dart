import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/portfolio_storage.dart';

// ── Theme colors
const Color _bg = Color(0xFF060E06);
const Color _cardBg = Color(0xFF0C1A0C);
const Color _green = Color(0xFF4ADE80);
const Color _cardBorder = Color(0xFF1A3520);
const Color _textDim = Color(0xFF6B8A6B);
const Color _red = Color(0xFFEF4444);

// ── Supported currencies
const _currencies = [
  ('EUR', '€', 'Euro'),
  ('USD', r'$', 'US Dollar'),
  ('GBP', '£', 'British Pound'),
  ('CNY', '¥', 'Chinese Yuan'),
  ('BRL', r'R$', 'Brazilian Real'),
  ('CAD', r'CA$', 'Canadian Dollar'),
  ('AUD', r'AU$', 'Australian Dollar'),
  ('RUB', '₽', 'Russian Ruble'),
];

// ─────────────────────────────────────────
// Profile Screen
// ─────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  final String? steamId;
  final String currency;
  final ValueChanged<String> onCurrencyChanged;
  final VoidCallback onRemoveInventory;

  const ProfileScreen({
    super.key,
    required this.steamId,
    required this.currency,
    required this.onCurrencyChanged,
    required this.onRemoveInventory,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? get _user => FirebaseAuth.instance.currentUser;

  // ── Sign out
  Future<void> _signOut() async {
    final confirm = await _showConfirmDialog(
      title: 'Abmelden',
      message: 'Möchtest du dich wirklich abmelden?',
      confirmLabel: 'Abmelden',
      isDestructive: true,
    );
    if (confirm != true) return;
    await FirebaseAuth.instance.signOut();
  }

  // ── Remove inventory
  Future<void> _removeInventory() async {
    final confirm = await _showConfirmDialog(
      title: 'Inventar entfernen',
      message:
          'Dein Inventar wird entfernt. Du kannst es jederzeit erneut verknüpfen.',
      confirmLabel: 'Entfernen',
      isDestructive: true,
    );
    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('linked_steam_id');
    await prefs.remove('inventory_items');

    final uid = _user?.uid;
    if (uid != null) {
      try {
        await PortfolioStorage.unlinkUidFromSteamId(uid);
      } catch (_) {}
    }

    widget.onRemoveInventory();
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required bool isDestructive,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _cardBorder),
        ),
        title: Text(
          title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: const TextStyle(color: _textDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen',
                style: TextStyle(color: _textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: isDestructive ? _red : _green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Currency picker bottom sheet
  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: _cardBorder),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Währung wählen',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...(_currencies.map((c) {
            final code = c.$1;
            final symbol = c.$2;
            final name = c.$3;
            final selected = widget.currency == code;
            return InkWell(
              onTap: () {
                Navigator.pop(context);
                widget.onCurrencyChanged(code);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: selected
                      ? _green.withAlpha(20)
                      : Colors.transparent,
                  border: Border(
                    bottom:
                        BorderSide(color: _cardBorder, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: selected
                            ? _green.withAlpha(40)
                            : const Color(0xFF0F1F0F),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              selected ? _green : _cardBorder,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          symbol,
                          style: TextStyle(
                            color: selected ? _green : _textDim,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            code,
                            style: const TextStyle(
                              color: _textDim,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      const Icon(Icons.check_rounded,
                          color: _green, size: 20),
                  ],
                ),
              ),
            );
          })),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final user = _user;
    final hasSteam = widget.steamId != null;
    final currencyName = _currencies
        .firstWhere((c) => c.$1 == widget.currency,
            orElse: () => _currencies.first)
        .$3;
    final currencySymbol = _currencies
        .firstWhere((c) => c.$1 == widget.currency,
            orElse: () => _currencies.first)
        .$2;

    return DefaultTextStyle.merge(
      style: const TextStyle(decoration: TextDecoration.none),
      child: Container(
        color: _bg,
        child: Column(
          children: [
            SizedBox(height: topPad + 16),

            // ── Header
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Profil',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Avatar + Name
            Column(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _green, width: 2.5),
                  ),
                  child: ClipOval(
                    child: user?.photoURL != null
                        ? Image.network(
                            user!.photoURL!,
                            fit: BoxFit.cover,
                            errorBuilder: (context2, err, stack) =>
                                _avatarFallback,
                          )
                        : _avatarFallback,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.displayName ?? 'Gast',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasSteam
                          ? Icons.link_rounded
                          : Icons.link_off_rounded,
                      color: hasSteam ? _green : _textDim,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasSteam
                          ? 'Steam-ID verknüpft'
                          : 'Steam-ID nicht verknüpft',
                      style: TextStyle(
                        color: hasSteam ? _green : _textDim,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── Settings List
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Währung
                    _SettingsRow(
                      icon: Icons.currency_exchange_rounded,
                      label: 'Währung',
                      subtitle: '$currencySymbol $currencyName (${widget.currency})',
                      onTap: _showCurrencyPicker,
                    ),
                    const SizedBox(height: 8),

                    // Support
                    _SettingsRow(
                      icon: Icons.help_outline_rounded,
                      label: 'Support',
                      onTap: () {},
                    ),
                    const SizedBox(height: 8),

                    // Nutzungsbedingungen
                    _SettingsRow(
                      icon: Icons.description_outlined,
                      label: 'Nutzungsbedingungen',
                      onTap: () {},
                    ),

                    const SizedBox(height: 24),

                    // Abmelden
                    _ActionButton(
                      label: 'Abmelden',
                      icon: Icons.logout_rounded,
                      color: _red,
                      onTap: _signOut,
                    ),

                    if (hasSteam) ...[
                      const SizedBox(height: 12),
                      // Inventar entfernen
                      _ActionButton(
                        label: 'Inventar entfernen',
                        icon: Icons.delete_outline_rounded,
                        color: _red,
                        onTap: _removeInventory,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget get _avatarFallback => Container(
        color: _cardBg,
        child: const Icon(Icons.person_rounded, color: _textDim, size: 40),
      );
}

// ─────────────────────────────────────────
// Settings Row
// ─────────────────────────────────────────
class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _green.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _green, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style:
                          const TextStyle(color: _textDim, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: _textDim, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Action Button (Abmelden / Inventar entfernen)
// ─────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
