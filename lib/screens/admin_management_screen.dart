import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/image_storage_service.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/app_image.dart';

enum AdminSection { products, categories, bundles, orders, users, reviews }

class AdminManagementScreen extends StatelessWidget {
  const AdminManagementScreen({super.key, required this.section});
  final AdminSection section;

  String get title {
    switch (section) {
      case AdminSection.products: return 'Products';
      case AdminSection.categories: return 'Categories';
      case AdminSection.bundles: return 'Bundles';
      case AdminSection.orders: return 'Orders';
      case AdminSection.users: return 'Users';
      case AdminSection.reviews: return 'Reviews';
    }
  }

  String get collection {
    switch (section) {
      case AdminSection.products: return 'products';
      case AdminSection.categories: return 'categories';
      case AdminSection.bundles: return 'bundles';
      case AdminSection.orders: return 'orders';
      case AdminSection.users: return 'users';
      case AdminSection.reviews: return 'reviews';
    }
  }

  IconData get icon {
    switch (section) {
      case AdminSection.products: return Icons.inventory_2_outlined;
      case AdminSection.categories: return Icons.category_outlined;
      case AdminSection.bundles: return Icons.auto_awesome_outlined;
      case AdminSection.orders: return Icons.receipt_long_outlined;
      case AdminSection.users: return Icons.people_outline_rounded;
      case AdminSection.reviews: return Icons.rate_review_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (section == AdminSection.bundles) {
      return const _BundlesWorkspace();
    }
    final canAdd = section == AdminSection.products || section == AdminSection.categories || section == AdminSection.bundles;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: canAdd
          ? FloatingActionButton.extended(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(section == AdminSection.products ? 'Product' : section == AdminSection.categories ? 'Category' : 'Bundle'),
            )
          : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection(collection).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Unable to load ' + title + '.'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return Center(child: Text('No ' + title + ' yet.'));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _tile(context, docs[index]),
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final name = (data['name'] ?? data['title'] ?? doc.id).toString();
    String subtitle;
    switch (section) {
      case AdminSection.products:
        subtitle = '₹' + (data['price'] ?? '-').toString() + ' • ' + (data['category'] ?? 'General').toString();
        break;
      case AdminSection.categories:
      case AdminSection.bundles:
        subtitle = (data['description'] ?? 'Catalog item').toString();
        break;
      case AdminSection.orders:
        subtitle = 'Status: ' + (data['status'] ?? 'pending').toString() + ' • Total: ₹' + (data['total'] ?? '-').toString();
        break;
      case AdminSection.users:
        subtitle = (data['email'] ?? '').toString() + ' • Role: ' + (data['role'] ?? 'user').toString();
        break;
      case AdminSection.reviews:
        subtitle = 'Rating: ' + (data['rating'] ?? '-').toString() + ' • ' + (data['comment'] ?? '').toString();
        break;
    }

    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: const Color(0xFFEAF2FF), child: Icon(icon, color: const Color(0xFF2563EB))),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') _edit(context, doc);
            if (value == 'delete') _delete(context, doc);
            if (value.startsWith('status:')) _setOrderStatus(doc.id, value.substring(7));
            if (value.startsWith('role:')) _setRole(doc.id, value.substring(5));
          },
          itemBuilder: (_) {
            if (section == AdminSection.products || section == AdminSection.categories || section == AdminSection.bundles) {
              return const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ];
            }
            if (section == AdminSection.orders) {
              return const [
                PopupMenuItem(value: 'status:pending', child: Text('Pending')),
                PopupMenuItem(value: 'status:confirmed', child: Text('Confirmed')),
                PopupMenuItem(value: 'status:shipped', child: Text('Shipped')),
                PopupMenuItem(value: 'status:delivered', child: Text('Delivered')),
                PopupMenuItem(value: 'status:cancelled', child: Text('Cancelled')),
              ];
            }
            if (section == AdminSection.users) {
              return const [
                PopupMenuItem(value: 'role:user', child: Text('Make user')),
                PopupMenuItem(value: 'role:admin', child: Text('Make admin')),
              ];
            }
            return const [PopupMenuItem(value: 'delete', child: Text('Delete review'))];
          },
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final name = TextEditingController();
    final description = TextEditingController();
    final price = TextEditingController();
    final imageUrl = TextEditingController();
    final saved = await _showItemDialog(
      context,
      title: section == AdminSection.products
          ? 'Add product'
          : section == AdminSection.categories
              ? 'Add category'
              : 'Add bundle',
      name: name,
      description: description,
      price: price,
      imageUrl: imageUrl,
    );
    if (saved != true || name.text.trim().isEmpty) return;
    final data = <String, dynamic>{
      'name': name.text.trim(),
      'description': description.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (section == AdminSection.products || section == AdminSection.bundles) {
      data['price'] = double.tryParse(price.text.trim()) ?? 0;
      data['category'] = 'General';
      data['stock'] = 0;
    }
    if (section == AdminSection.products || section == AdminSection.categories || section == AdminSection.bundles) {
      data['imageUrl'] = imageUrl.text.trim();
    }
    try {
      await FirebaseFirestore.instance.collection(collection).add(data);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item saved successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database save failed: $e')),
        );
      }
    } finally {
      name.dispose();
      description.dispose();
      price.dispose();
      imageUrl.dispose();
    }
  }

  Future<void> _edit(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final name = TextEditingController(text: (data['name'] ?? data['title'] ?? '').toString());
    final description = TextEditingController(text: (data['description'] ?? '').toString());
    final price = TextEditingController(text: (data['price'] ?? '').toString());
    final imageUrl = TextEditingController(text: (data['imageUrl'] ?? '').toString());
    final saved = await _showItemDialog(
      context,
      title: 'Edit item',
      name: name,
      description: description,
      price: price,
      imageUrl: imageUrl,
    );
    if (saved != true) return;
    final update = <String, dynamic>{
      'name': name.text.trim(),
      'description': description.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (section == AdminSection.products || section == AdminSection.bundles) {
      update['price'] = double.tryParse(price.text.trim()) ?? 0;
    }
    if (section == AdminSection.products || section == AdminSection.categories || section == AdminSection.bundles) {
      update['imageUrl'] = imageUrl.text.trim();
    }
    try {
      await doc.reference.update(update);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database update failed: $e')),
        );
      }
    } finally {
      name.dispose();
      description.dispose();
      price.dispose();
      imageUrl.dispose();
    }
  }

  Future<bool?> _showItemDialog(
    BuildContext context, {
    required String title,
    required TextEditingController name,
    required TextEditingController description,
    required TextEditingController price,
    required TextEditingController imageUrl,
  }) {
    if (section == AdminSection.bundles) {
      return _showBundleDialog(
        context,
        title: title,
        name: name,
        description: description,
        price: price,
        imageUrl: imageUrl,
      );
    }

    Uint8List? selectedImageBytes;
    String? selectedFileName;
    bool isSaving = false;

    bool isValidImageUrl(String value) {
      final uri = Uri.tryParse(value.trim());
      return uri != null &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    }

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> enterImageUrl() async {
            if (isSaving) return;
            final urlController = TextEditingController(text: imageUrl.text.trim());
            final url = await showDialog<String>(
              context: dialogContext,
              builder: (urlContext) => AlertDialog(
                title: const Text('Use image URL'),
                content: TextField(
                  controller: urlController,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Image URL',
                    hintText: 'https://example.com/image.jpg',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(urlContext),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final value = urlController.text.trim();
                      if (!isValidImageUrl(value)) {
                        ScaffoldMessenger.of(urlContext).showSnackBar(
                          const SnackBar(content: Text('Enter a valid http:// or https:// image URL')),
                        );
                        return;
                      }
                      Navigator.pop(urlContext, value);
                    },
                    child: const Text('Use URL'),
                  ),
                ],
              ),
            );
            urlController.dispose();
            if (url == null || url.isEmpty) return;
            setDialogState(() {
              imageUrl.text = url;
              selectedImageBytes = null;
              selectedFileName = 'Image URL';
            });
          }

          Future<void> pickImage() async {
            if (isSaving) return;

            try {
              final picker = ImagePicker();
              final file = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 90,
                maxWidth: 1600,
                maxHeight: 1600,
              );
              if (file == null) return;

              final bytes = await file.readAsBytes();
              final filename = file.name.trim();
              final lowerName = filename.toLowerCase();
              final supported = lowerName.endsWith('.jpg') ||
                  lowerName.endsWith('.jpeg') ||
                  lowerName.endsWith('.png') ||
                  lowerName.endsWith('.webp') ||
                  lowerName.endsWith('.gif');
              if (!supported) {
                throw Exception('Please choose JPG, JPEG, PNG, WEBP or GIF.');
              }
              final folder = section == AdminSection.products
                  ? 'products'
                  : section == AdminSection.categories
                      ? 'categories'
                      : 'bundles';

              setDialogState(() {
                selectedImageBytes = bytes;
                selectedFileName = filename;
              });

              final downloadUrl = await ImageStorageService.upload(
                bytes: bytes,
                folder: folder,
                fileName: filename,
              );

              setDialogState(() {
                imageUrl.text = downloadUrl;
                selectedFileName = '$filename • uploaded';
              });

              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Image uploaded to GitHub Storage successfully')),
                );
              }
            } catch (e) {
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('Image upload failed: $e')),
                );
              }
            }
          }

          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    TextField(
                      controller: description,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    if (section == AdminSection.products || section == AdminSection.bundles)
                      TextField(
                        controller: price,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Price'),
                      ),
                    if (section == AdminSection.products ||
                        section == AdminSection.categories ||
                        section == AdminSection.bundles) ...[
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: pickImage,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFD6DCE5)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              if (selectedImageBytes != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.memory(
                                    selectedImageBytes!,
                                    width: 58,
                                    height: 58,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF2FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.cloud_upload_outlined,
                                    color: Color(0xFF2563EB),
                                    size: 30,
                                  ),
                                ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedFileName ?? 'Upload Image',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      selectedFileName == null
                                          ? 'Choose JPG, PNG, WEBP or GIF'
                                          : 'Image selected',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF707681),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.add_photo_alternate_outlined),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: imageUrl,
                        decoration: InputDecoration(
                          labelText: 'Image URL',
                          hintText: 'https://example.com/image.jpg',
                          prefixIcon: const Icon(Icons.link_rounded),
                          suffixIcon: imageUrl.text.trim().isNotEmpty
                              ? IconButton(
                                  tooltip: 'Clear image URL',
                                  onPressed: () => setDialogState(() => imageUrl.clear()),
                                  icon: const Icon(Icons.clear),
                                )
                              : null,
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: pickImage,
                              icon: const Icon(Icons.upload_file_rounded),
                              label: const Text('Upload from device'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: enterImageUrl,
                              icon: const Icon(Icons.link_rounded),
                              label: const Text('Use image URL'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Use a local image (uploaded to GitHub Storage) or paste a public direct image URL.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF707681)),
                      ),
                      if (isValidImageUrl(imageUrl.text)) ...[
                        const SizedBox(height: 12),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Image preview',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: double.infinity,
                            height: 150,
                            child: AppImage(
                              source: imageUrl.text.trim(),
                              fit: BoxFit.cover,
                              placeholder: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              fallback: const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.broken_image_outlined, size: 34),
                                    SizedBox(height: 6),
                                    Text('Image URL could not be loaded'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final value = imageUrl.text.trim();
                        if (value.isNotEmpty && !isValidImageUrl(value)) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid public http:// or https:// image URL.'),
                              duration: Duration(seconds: 4),
                            ),
                          );
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        try {
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (e) {
                          if (dialogContext.mounted) {
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Save failed: ${e.toString().replaceFirst('Exception: ', '')}',
                                ),
                                duration: const Duration(seconds: 6),
                              ),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool?> _showBundleDialog(
    BuildContext context, {
    required String title,
    required TextEditingController name,
    required TextEditingController description,
    required TextEditingController price,
    required TextEditingController imageUrl,
  }) {
    Uint8List? selectedImageBytes;
    String? selectedFileName;
    bool isSaving = false;

    bool isValidImageUrl(String value) {
      final uri = Uri.tryParse(value.trim());
      return uri != null &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    }

    return showDialog<bool>(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> enterImageUrl() async {
            if (isSaving) return;
            final urlController = TextEditingController(text: imageUrl.text.trim());
            final url = await showDialog<String>(
              context: dialogContext,
              builder: (urlContext) => AlertDialog(
                title: const Text('Use image URL'),
                content: TextField(
                  controller: urlController,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Direct image URL',
                    hintText: 'https://example.com/image.jpg',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(urlContext),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final value = urlController.text.trim();
                      if (!isValidImageUrl(value)) {
                        ScaffoldMessenger.of(urlContext).showSnackBar(
                          const SnackBar(
                            content: Text('Enter a valid http:// or https:// image URL'),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(urlContext, value);
                    },
                    child: const Text('Use URL'),
                  ),
                ],
              ),
            );
            urlController.dispose();
            if (url == null || url.isEmpty || !dialogContext.mounted) return;
            setDialogState(() {
              imageUrl.text = url;
              selectedImageBytes = null;
              selectedFileName = 'Image URL';
            });
          }

          Future<void> pickImage() async {
            if (isSaving) return;
            try {
              final picker = ImagePicker();
              final file = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 90,
                maxWidth: 1600,
                maxHeight: 1600,
              );
              if (file == null) return;

              final bytes = await file.readAsBytes();
              final filename = file.name.trim();
              final lowerName = filename.toLowerCase();
              final supported = lowerName.endsWith('.jpg') ||
                  lowerName.endsWith('.jpeg') ||
                  lowerName.endsWith('.png') ||
                  lowerName.endsWith('.webp') ||
                  lowerName.endsWith('.gif');
              if (!supported) {
                throw Exception('Please choose JPG, JPEG, PNG, WEBP or GIF.');
              }

              setDialogState(() {
                selectedImageBytes = bytes;
                selectedFileName = filename;
              });

              final downloadUrl = await ImageStorageService.upload(
                bytes: bytes,
                folder: 'bundles',
                fileName: filename,
              );

              if (!dialogContext.mounted) return;
              setDialogState(() {
                imageUrl.text = downloadUrl;
                selectedFileName = filename + ' • uploaded';
              });
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Image uploaded to GitHub Storage successfully')),
              );
            } catch (e) {
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('Image upload failed: ' + e.toString())),
                );
              }
            }
          }

          Widget imagePreview() {
            if (selectedImageBytes != null) {
              return Image.memory(
                selectedImageBytes!,
                width: double.infinity,
                height: 170,
                fit: BoxFit.cover,
              );
            }
            if (isValidImageUrl(imageUrl.text)) {
              return AppImage(
                source: imageUrl.text.trim(),
                fit: BoxFit.cover,
                placeholder: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                fallback: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image_outlined, size: 32),
                      SizedBox(height: 5),
                      Text('Image URL could not be loaded'),
                    ],
                  ),
                ),
              );
            }
            return Container(
              height: 170,
              width: double.infinity,
              color: const Color(0xFFEAF2FF),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome_mosaic_outlined,
                      color: Color(0xFF2563EB), size: 38),
                  SizedBox(height: 8),
                  Text('Bundle image preview'),
                ],
              ),
            );
          }

          return AlertDialog(
            backgroundColor: const Color(0xFFFFFEFC),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
            contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            title: Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome_outlined,
                      color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                        color: Color(0xFF172554),
                        fontWeight: FontWeight.w800,
                      )),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 560,
                maxHeight: MediaQuery.of(dialogContext).size.height * 0.66,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Bundle details',
                      style: TextStyle(
                        color: Color(0xFF172554),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Bundle name',
                        hintText: 'e.g. Exam Ready Kit',
                        prefixIcon: const Icon(Icons.inventory_2_outlined),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(color: Color(0xFFDCE6F8)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(color: Color(0xFFDCE6F8)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: description,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'What is included in this bundle?',
                        alignLabelWithHint: true,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 28),
                          child: Icon(Icons.notes_rounded),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(color: Color(0xFFDCE6F8)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(color: Color(0xFFDCE6F8)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: price,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Price (₹)',
                        hintText: '0.00',
                        prefixIcon: const Icon(Icons.currency_rupee_rounded),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(color: Color(0xFFDCE6F8)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(color: Color(0xFFDCE6F8)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Bundle image',
                      style: TextStyle(
                        color: Color(0xFF172554),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: SizedBox(
                        width: double.infinity,
                        height: 170,
                        child: imagePreview(),
                      ),
                    ),
                    if (selectedFileName != null) ...[
                      const SizedBox(height: 7),
                      Text(
                        selectedFileName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: imageUrl,
                      keyboardType: TextInputType.url,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Image URL',
                        hintText: 'https://example.com/image.jpg',
                        prefixIcon: const Icon(Icons.link_rounded),
                        suffixIcon: imageUrl.text.trim().isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear image URL',
                                onPressed: () => setDialogState(() {
                                  imageUrl.clear();
                                  selectedImageBytes = null;
                                  selectedFileName = null;
                                }),
                                icon: const Icon(Icons.clear_rounded),
                              ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(color: Color(0xFFDCE6F8)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(color: Color(0xFFDCE6F8)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: isSaving ? null : pickImage,
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text('Upload from device'),
                        ),
                        OutlinedButton.icon(
                          onPressed: isSaving ? null : enterImageUrl,
                          icon: const Icon(Icons.link_rounded),
                          label: const Text('Use image URL'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose an image file or paste a public direct image URL.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
            actions: [
              TextButton(
                onPressed: isSaving
                    ? null
                    : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isSaving
                    ? null
                    : () {
                        final value = imageUrl.text.trim();
                        if (value.isNotEmpty && !isValidImageUrl(value)) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid public http:// or https:// image URL.'),
                              duration: Duration(seconds: 4),
                            ),
                          );
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        Navigator.pop(dialogContext, true);
                      },
                icon: isSaving
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Save bundle'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _delete(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete item?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes == true) await doc.reference.delete();
  }

  Future<void> _setOrderStatus(String id, String status) {
    return FirebaseFirestore.instance.collection('orders').doc(id).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _setRole(String uid, String role) {
    return FirebaseFirestore.instance.collection('users').doc(uid).update({
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class _BundlesWorkspace extends StatelessWidget {
  const _BundlesWorkspace();

  static const Color _canvas = Color(0xFFFAF8F3);
  static const Color _ink = Color(0xFF172554);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFDCE6F8);

  final AdminManagementScreen _actions =
      const AdminManagementScreen(section: AdminSection.bundles);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        title: const Text(
          'Bundles',
          style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
        ),
        backgroundColor: _canvas,
        foregroundColor: _ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: FilledButton.icon(
              onPressed: () => _actions._add(context),
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text('Add Bundle'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('bundles').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(22),
                  constraints: const BoxConstraints(maxWidth: 480),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: Color(0xFFDC2626), size: 30),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Unable to load Bundles.',
                              style: TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Please check your connection and try again.',
                              style: TextStyle(color: _muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 34,
                      width: 34,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: _blue,
                      ),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Loading bundles...',
                      style: TextStyle(color: _muted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }

            final docs = snapshot.data!.docs;
            return LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final horizontalPadding = width < 600 ? 16.0 : 28.0;
                final columns = width >= 1100 ? 3 : width >= 650 ? 2 : 1;
                final cardExtent = width < 520 ? 375.0 : width < 900 ? 360.0 : 355.0;

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    12,
                    horizontalPadding,
                    28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manage student bundles and package details.',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (docs.isEmpty)
                        _emptyState(context)
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: docs.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            mainAxisExtent: cardExtent,
                          ),
                          itemBuilder: (context, index) =>
                              _bundleCard(context, docs[index]),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: _blue,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No bundles yet.',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a bundle to organize useful student essentials into one package.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _actions._add(context),
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add your first bundle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bundleCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final name = (data['name'] ?? data['title'] ?? doc.id).toString();
    final description = (data['description'] ?? 'No description provided.')
        .toString()
        .trim();
    final imageUrl = (data['imageUrl'] ?? '').toString().trim();
    final rawPrice = data['price'];
    final priceLabel = rawPrice == null
        ? '₹0'
        : rawPrice is num
            ? '₹' + (rawPrice % 1 == 0
                ? rawPrice.toStringAsFixed(0)
                : rawPrice.toStringAsFixed(2))
            : '₹' + rawPrice.toString();

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: imageUrl.isEmpty
                ? Container(
                    color: const Color(0xFFEAF2FF),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome_mosaic_outlined,
                          color: _blue,
                          size: 42,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Bundle image',
                          style: TextStyle(
                            color: _muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : AppImage(
                    source: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _blue,
                      ),
                    ),
                    fallback: Container(
                      color: const Color(0xFFEAF2FF),
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: _blue,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 15.5,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        height: 32,
                        width: 32,
                        child: PopupMenuButton<String>(
                          tooltip: 'Bundle actions',
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.more_vert_rounded,
                              color: _muted),
                          onSelected: (value) {
                            if (value == 'edit') _actions._edit(context, doc);
                            if (value == 'delete') _actions._delete(context, doc);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 10),
                                  Text('Edit bundle'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, size: 18),
                                  SizedBox(width: 10),
                                  Text('Delete bundle'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    priceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _blue,
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Expanded(
                    child: Text(
                      description.isEmpty ? 'No description provided.' : description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
