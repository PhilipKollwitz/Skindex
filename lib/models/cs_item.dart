class CsItem {
  final String name;
  final String imageUrl;
  final String marketHashName;

  CsItem({
    required this.name,
    required this.imageUrl,
    required this.marketHashName,
  });

  factory CsItem.fromJson(Map<String, dynamic> json) {
    return CsItem(
      name: json['name'] as String? ?? '',
      imageUrl: json['image'] as String? ?? '',
      marketHashName: json['market_hash_name'] as String? ?? json['name'] as String? ?? '',
    );
  }
}
