import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/app_image.dart';
import '../database/firestore_database.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  bool _routeArgsRead = false;

  static const cream = Color(0xFFFAF8F3);
  static const ink = Color(0xFF172033);
  static const blue = Color(0xFF2563EB);
  static const muted = Color(0xFF707681);
  static const border = Color(0xFFE7E2D9);

  String category = 'All';
  String query = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeArgsRead) return;
    _routeArgsRead = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      query = (args['query'] ?? '').toString();
      category = (args['category'] ?? 'All').toString();
      _searchController.text = query;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: cream,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: const Text('Shop', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/wishlist'),
            icon: const Icon(Icons.favorite_border_rounded),
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/cart'),
            icon: const Icon(Icons.shopping_bag_outlined),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirestoreDatabase.instance.watchCategories(),
        builder: (context, categorySnapshot) {
          if (categorySnapshot.hasError) {
            return _message(
              'Could not load categories.\n\n' +
                  categorySnapshot.error.toString(),
            );
          }
          if (!categorySnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final categoryDocs = categorySnapshot.data!;
          final categoryNames = <String>[
            'All',
            ...categoryDocs.map(
              (c) => (c['name'] ?? c['slug'] ?? 'Category').toString(),
            ),
          ];

          if (!categoryNames.contains(category)) {
            category = 'All';
          }

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: FirestoreDatabase.instance.watchProducts(),
            builder: (context, productSnapshot) {
              if (productSnapshot.hasError) {
                return _message(
                  'Could not load products.\n\n' +
                      productSnapshot.error.toString() +
                      '\n\nCheck Firestore and deployed security rules.',
                );
              }
              if (!productSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final products = productSnapshot.data!;
              final normalizedQuery = query.trim().toLowerCase();
              final filtered = products.where((p) {
                final productCategory =
                    (p['category'] ?? '').toString().trim();
                final matchesCategory = category == 'All' ||
                    productCategory.toLowerCase() == category.toLowerCase();
                final text = (p['name'] ?? '').toString() +
                    ' ' +
                    (p['description'] ?? '').toString();
                return matchesCategory &&
                    text.toLowerCase().contains(normalizedQuery);
              }).toList();

              return LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1050
                      ? 4
                      : constraints.maxWidth >= 700
                          ? 3
                          : 2;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: ink,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: Color(0xFFFACC15),
                              size: 24,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Find your next campus essential.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) => setState(
                                () => query = _searchController.text.trim(),
                              ),
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText: 'Search by product name...',
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: const Icon(Icons.search_rounded, color: blue),
                                suffixIcon: _searchController.text.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Clear search',
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => query = '');
                                        },
                                        icon: const Icon(Icons.clear_rounded),
                                      ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: blue, width: 1.5),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: () => setState(
                                () => query = _searchController.text.trim(),
                              ),
                              icon: const Icon(Icons.search_rounded, size: 19),
                              label: const Text('Search'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: blue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                textStyle: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categoryNames.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final name = categoryNames[i];
                            final selected = name == category;
                            return ChoiceChip(
                              label: Text(name),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => category = name),
                              selectedColor: blue,
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: selected ? blue : border,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              showCheckmark: false,
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : ink,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (filtered.isEmpty)
                        _message(
                          products.isEmpty
                              ? 'No products yet. Add products from Admin Dashboard.'
                              : 'No products match this category or search.',
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: columns == 2 ? .64 : columns == 3 ? .72 : .78,
                          ),
                          itemBuilder: (_, i) => _card(context, filtered[i]),
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _message(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ink,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, Map<String, dynamic> p) {
    final price = p['price'];
    final realPhotoUrl = _realPhotoUrl(p);

    Widget photo() {
      return AppImage(
        source: realPhotoUrl,
        fit: BoxFit.contain,
        fallback: const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: blue,
            size: 54,
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => Navigator.pushNamed(context, '/product', arguments: p),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3EE),
                  borderRadius: BorderRadius.circular(17),
                ),
                clipBehavior: Clip.antiAlias,
                child: photo(),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              (p['name'] ?? 'Product').toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ink, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              (p['category'] ?? '').toString().trim().isEmpty
                  ? 'Campus essential'
                  : (p['category'] ?? '').toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            if ((p['description'] ?? '').toString().trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                (p['description'] ?? '').toString().trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: muted,
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
            ],
            const SizedBox(height: 7),
            Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFF4B400),
                  size: 15,
                ),
                const SizedBox(width: 3),
                Text(
                  (p['rating'] ?? 'New').toString(),
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
                const Spacer(),
                Text(
                  price == null ? '₹0' : '₹$price',
                  style: const TextStyle(
                    color: blue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/product', arguments: p),
                style: OutlinedButton.styleFrom(
                  foregroundColor: blue,
                  side: const BorderSide(color: blue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                child: const Text('View Product'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _realPhotoUrl(Map<String, dynamic> product) {
  // Prefer the image path selected in the Admin panel.
  final storedPath = (product['imageUrl'] ?? '').toString().trim();
  if (storedPath.isNotEmpty) {
    // Supports both bundled assets and Firebase Storage download URLs.
    return storedPath;
  }

  // Backward-compatible fallback for existing products.
  final value = '${product['name'] ?? ''} ${product['category'] ?? ''}'.toLowerCase();

  if (value.contains('backpack') || value.contains('bag')) return 'assets/image/products/backpack.svg';
  if (value.contains('headphone')) return 'assets/image/products/headphones.svg';
  if (value.contains('bottle') || value.contains('tumbler')) return 'assets/image/products/bottle.svg';
  if (value.contains('calculator')) return 'assets/image/products/calculator.svg';
  if (value.contains('lamp')) return 'assets/image/products/lamp.svg';
  if (value.contains('sleeve')) return 'assets/image/products/sleeve.svg';
  if (value.contains('pen')) return 'assets/image/products/pen.svg';
  return 'assets/image/products/notebook.svg';
}

String _productSvg({
  required String bg,
  required String body,
  required String accent,
  required String shape,
}) {
  String art;

  switch (shape) {
    case 'bag':
      art =
          '<path d="M210 175c0-68 40-105 90-105s90 37 90 105v45h-48v-43c0-34-14-55-42-55s-42 21-42 55v43h-48z" fill="$body"/>'
          '<rect x="155" y="150" width="290" height="265" rx="48" fill="$body"/>'
          '<rect x="205" y="225" width="190" height="125" rx="24" fill="#1D4ED8"/>'
          '<rect x="250" y="245" width="100" height="18" rx="9" fill="$accent"/>';
      break;
    case 'headphones':
      art =
          '<path d="M170 275v-45c0-78 58-140 130-140s130 62 130 140v45" fill="none" stroke="#172033" stroke-width="42" stroke-linecap="round"/>'
          '<rect x="135" y="250" width="95" height="150" rx="38" fill="$body"/>'
          '<rect x="370" y="250" width="95" height="150" rx="38" fill="$body"/>'
          '<rect x="160" y="278" width="45" height="80" rx="18" fill="$accent"/>'
          '<rect x="395" y="278" width="45" height="80" rx="18" fill="$accent"/>';
      break;
    case 'bottle':
      art =
          '<rect x="245" y="70" width="110" height="55" rx="16" fill="#172033"/>'
          '<path d="M225 115h150l38 60v205c0 36-29 65-65 65H252c-36 0-65-29-65-65V175z" fill="$body"/>'
          '<rect x="225" y="205" width="150" height="70" rx="18" fill="$accent"/>';
      break;
    case 'pen':
      art =
          '<g transform="rotate(-25 300 250)"><rect x="150" y="220" width="300" height="58" rx="20" fill="$body"/><rect x="210" y="220" width="145" height="58" fill="$accent"/><path d="M450 220l70 29-70 29z" fill="#172033"/></g>';
      break;
    case 'calculator':
      art =
          '<rect x="170" y="55" width="260" height="390" rx="34" fill="$body"/>'
          '<rect x="205" y="90" width="190" height="95" rx="16" fill="#EAF2FF"/>'
          '<rect x="205" y="215" width="45" height="45" rx="10" fill="$accent"/>'
          '<rect x="275" y="215" width="45" height="45" rx="10" fill="$accent"/>'
          '<rect x="345" y="215" width="45" height="45" rx="10" fill="$accent"/>';
      break;
    case 'lamp':
      art =
          '<path d="M200 120h190l65 120H135z" fill="$body"/>'
          '<path d="M300 240v155" stroke="#172033" stroke-width="20" stroke-linecap="round"/>'
          '<path d="M220 410h160" stroke="#172033" stroke-width="25" stroke-linecap="round"/>'
          '<circle cx="300" cy="225" r="28" fill="$accent"/>';
      break;
    case 'sleeve':
      art =
          '<rect x="105" y="100" width="390" height="300" rx="30" fill="$body"/>'
          '<rect x="135" y="130" width="330" height="235" rx="18" fill="$accent"/>'
          '<rect x="205" y="165" width="190" height="135" rx="12" fill="#EAF2FF"/>';
      break;
    default:
      art =
          '<rect x="150" y="75" width="300" height="350" rx="24" fill="#172033"/>'
          '<rect x="175" y="55" width="300" height="350" rx="24" fill="#fff"/>'
          '<rect x="215" y="120" width="190" height="18" rx="9" fill="$accent"/>'
          '<rect x="215" y="170" width="150" height="12" rx="6" fill="#CBD5E1"/>'
          '<rect x="215" y="205" width="175" height="12" rx="6" fill="#CBD5E1"/>';
  }

  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 500"><rect width="600" height="500" rx="48" fill="$bg"/>$art</svg>';
}
