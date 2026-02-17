import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_bookmarks/services/share_service.dart';
import 'package:universal_bookmarks/services/bookmark_storage.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final List<Bookmark> _bookmarks = [];
  final List<Category> _categories = [];
  final ShareService _shareService = ShareService();
  final BookmarkStorage _storage = BookmarkStorage();
  final TextEditingController _searchController = TextEditingController();
  
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    
    // Listen for new shares
    _shareService.listenToShares(_processSharedText);
    _shareService.checkForInitialShare(_processSharedText);
  }

  Future<void> _loadData() async {
    await _storage.init();
    final bookmarks = await _storage.getAllBookmarks();
    final categories = await _storage.getCategories();
    
    if (mounted) {
      setState(() {
        _bookmarks.addAll(bookmarks);
        _categories.addAll(categories);
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _shareService.dispose();
    super.dispose();
  }

  List<Bookmark> get _filteredBookmarks {
    List<Bookmark> result = _bookmarks;
    
    // Filter by category
    if (_selectedCategory != 'All') {
      result = result.where((b) => b.category == _selectedCategory).toList();
    }
    
    // Filter by search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((b) => 
        b.title.toLowerCase().contains(query) ||
        b.url.toLowerCase().contains(query)
      ).toList();
    }
    
    return result;
  }

  Future<void> _processSharedText(String sharedText) async {
    final urlRegExp = RegExp(
      r"(https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|www\.[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|https?:\/\/[a-zA-Z0-9]+\.[^\s]{2,})",
      caseSensitive: false,
    );

    final match = urlRegExp.firstMatch(sharedText);
    if (match != null) {
      final url = match.group(0);
      if (url != null) {
        final saved = await _storage.addBookmark(url, category: _selectedCategory == 'All' ? 'Uncategorized' : _selectedCategory);
        
        if (saved) {
          final bookmarks = await _storage.getAllBookmarks();
          setState(() {
            _bookmarks.clear();
            _bookmarks.addAll(bookmarks);
          });
          if (mounted) {
            _showPremiumSnackBar("✨ Bookmark saved: ${_extractDomain(url)}");
          }
        } else {
          if (mounted) {
            _showPremiumSnackBar("📌 Already saved: ${_extractDomain(url)}");
          }
        }
      }
    }
  }

  String _extractDomain(String url) {
    try {
      Uri uri = Uri.parse(url);
      return uri.host.isNotEmpty ? uri.host : url;
    } catch (e) {
      return url;
    }
  }

  void _showPremiumSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bookmark_added, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16213E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFF6366F1).withValues(alpha: 0.5), width: 1),
        ),
      ),
    );
  }

  Future<void> _deleteBookmark(String id) async {
    await _storage.removeBookmark(id);
    setState(() {
      _bookmarks.removeWhere((b) => b.id == id);
    });
    if (mounted) _showPremiumSnackBar("🗑️ Bookmark removed");
  }

  Future<void> _exportData() async {
    try {
      final jsonData = await _storage.exportBookmarks();
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/bookmarks_backup.json');
      await file.writeAsString(jsonData);
      
      if (mounted) {
        await _showExportDialog(jsonData);
      }
    } catch (e) {
      if (mounted) _showPremiumSnackBar("❌ Export failed");
    }
  }

  Future<void> _showExportDialog(String jsonData) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.download_rounded, color: Color(0xFF6366F1)),
            SizedBox(width: 12),
            Text('Backup Ready', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your bookmarks have been exported. Copy the data below:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                jsonData.length > 500 ? '${jsonData.substring(0, 500)}...' : jsonData,
                style: const TextStyle(color: Colors.white60, fontSize: 10, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonData));
              Navigator.pop(context);
              _showPremiumSnackBar("📋 Copied to clipboard!");
            },
            child: const Text('Copy to Clipboard', style: TextStyle(color: Color(0xFF6366F1))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Future<void> _showImportDialog() async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.upload_rounded, color: Color(0xFF6366F1)),
            SizedBox(width: 12),
            Text('Import Bookmarks', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Paste your backup JSON data:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 5,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'Paste JSON here...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final imported = await _storage.importBookmarks(controller.text);
                if (imported > 0) {
                  final bookmarks = await _storage.getAllBookmarks();
                  final categories = await _storage.getCategories();
                  setState(() {
                    _bookmarks.clear();
                    _bookmarks.addAll(bookmarks);
                    _categories.clear();
                    _categories.addAll(categories);
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    _showPremiumSnackBar("✅ Imported $imported bookmarks!");
                  }
                } else {
                  _showPremiumSnackBar("❌ Invalid backup data");
                }
              }
            },
            child: const Text('Import', style: TextStyle(color: Color(0xFF6366F1))),
          ),
        ],
      ),
    );
  }

  Future<void> _showCategoryManager() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CategoryManagerSheet(
        categories: _categories,
        onCategoryAdded: (cat) async {
          await _storage.addCategory(cat);
          final categories = await _storage.getCategories();
          setState(() {
            _categories.clear();
            _categories.addAll(categories);
          });
        },
        onCategoryDeleted: (name) async {
          await _storage.deleteCategory(name);
          final categories = await _storage.getCategories();
          final bookmarks = await _storage.getAllBookmarks();
          setState(() {
            _categories.clear();
            _categories.addAll(categories);
            _bookmarks.clear();
            _bookmarks.addAll(bookmarks);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildPremiumAppBar(),
              _buildSearchBar(),
              _buildCategoryTabs(),
              Expanded(child: _isLoading ? _buildShimmerLoading() : _buildBookmarksList()),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildPremiumFAB(),
    );
  }

  Widget _buildPremiumAppBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF6366F1).withValues(alpha: 0.3),
                  const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
              boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Universal Bookmarks', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${_bookmarks.length} saved links', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
                    ],
                  ),
                ),
                _buildActionButton(Icons.folder_rounded, _showCategoryManager),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                  ),
                  color: const Color(0xFF16213E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) {
                    if (value == 'export') _exportData();
                    if (value == 'import') _showImportDialog();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'export', child: Row(children: [Icon(Icons.download, color: Color(0xFF6366F1)), SizedBox(width: 12), Text('Export Backup', style: TextStyle(color: Colors.white))])),
                    const PopupMenuItem(value: 'import', child: Row(children: [Icon(Icons.upload, color: Color(0xFF6366F1)), SizedBox(width: 12), Text('Import Backup', style: TextStyle(color: Colors.white))])),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search bookmarks...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5)),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white54),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(top: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _buildCategoryChip('All', 0, true);
          final category = _categories[index - 1];
          return _buildCategoryChip(category.name, category.colorIndex, _selectedCategory == category.name);
        },
      ),
    );
  }

  Widget _buildCategoryChip(String name, int colorIndex, bool isSelected) {
    final colors = BookmarkStorage.categoryColors[colorIndex % BookmarkStorage.categoryColors.length];
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? LinearGradient(colors: [Color(colors[0]), Color(colors[1])]) : null,
          color: isSelected ? null : const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(25),
          border: isSelected ? null : Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(name, style: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildPremiumEmptyState() {
    return Center(
      child: AnimationConfiguration.synchronized(
        duration: const Duration(milliseconds: 800),
        child: SlideAnimation(
          verticalOffset: 50.0,
          child: FadeInAnimation(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [const Color(0xFF6366F1).withValues(alpha: 0.2), const Color(0xFF8B5CF6).withValues(alpha: 0.1)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.3), blurRadius: 40, spreadRadius: 10)],
                  ),
                  child: const Icon(Icons.bookmark_border_rounded, size: 80, color: Color(0xFF6366F1)),
                ),
                const SizedBox(height: 32),
                const Text('No Bookmarks Found', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    _searchQuery.isNotEmpty ? 'No results for "$_searchQuery"' : 'Share links from any app to save them here',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookmarksList() {
    final filtered = _filteredBookmarks;
    if (filtered.isEmpty) return _buildPremiumEmptyState();
    
    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final bookmark = filtered[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 500),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: _buildPremiumBookmarkCard(bookmark, index),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPremiumBookmarkCard(Bookmark bookmark, int index) {
    final colorIndex = _categories.indexWhere((c) => c.name == bookmark.category);
    final colors = BookmarkStorage.categoryColors[(colorIndex >= 0 ? colorIndex : 0) % BookmarkStorage.categoryColors.length];
    
    return Dismissible(
      key: Key(bookmark.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Colors.red, Colors.redAccent]),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
      ),
      onDismissed: (_) => _deleteBookmark(bookmark.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF16213E), const Color(0xFF1A1A2E).withValues(alpha: 0.8)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
          boxShadow: [BoxShadow(color: Color(colors[0]).withValues(alpha: 0.1 + (index * 0.02)), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Color(colors[0]).withValues(alpha: 0.3), Color(colors[1]).withValues(alpha: 0.2)]),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: Color(colors[0]), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(bookmark.category, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              child: AnyLinkPreview(
                link: bookmark.url,
                displayDirection: UIDirection.uiDirectionHorizontal,
                showMultimedia: true,
                bodyMaxLines: 2,
                bodyTextOverflow: TextOverflow.ellipsis,
                titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                bodyStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                errorBody: 'Could not preview',
                errorTitle: 'Preview unavailable',
                errorWidget: Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.link_off_rounded, color: Color(colors[0]), size: 40),
                      const SizedBox(height: 8),
                      Text(bookmark.url, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                cache: const Duration(days: 7),
                backgroundColor: Colors.transparent,
                borderRadius: 0,
                removeElevation: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF16213E),
      highlightColor: const Color(0xFF1A1A2E).withValues(alpha: 0.8),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 160,
            decoration: BoxDecoration(color: const Color(0xFF16213E), borderRadius: BorderRadius.circular(20)),
          );
        },
      ),
    );
  }

  Widget _buildPremiumFAB() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFEC4899)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: FloatingActionButton(
        onPressed: () => _showPremiumSnackBar("💡 Share a link from any app to save it!"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.add_rounded, size: 32),
      ),
    );
  }
}

class _CategoryManagerSheet extends StatefulWidget {
  final List<Category> categories;
  final Function(Category) onCategoryAdded;
  final Function(String) onCategoryDeleted;

  const _CategoryManagerSheet({
    required this.categories,
    required this.onCategoryAdded,
    required this.onCategoryDeleted,
  });

  @override
  State<_CategoryManagerSheet> createState() => _CategoryManagerSheetState();
}

class _CategoryManagerSheetState extends State<_CategoryManagerSheet> {
  final TextEditingController _controller = TextEditingController();
  int _selectedColor = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF16213E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Manage Categories', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // Add new category
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'New category name...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                    filled: true,
                    fillColor: const Color(0xFF1A1A2E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  if (_controller.text.isNotEmpty) {
                    widget.onCategoryAdded(Category(
                      name: _controller.text,
                      colorIndex: _selectedColor,
                    ));
                    _controller.clear();
                    setState(() => _selectedColor = (_selectedColor + 1) % BookmarkStorage.categoryColors.length);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Color(BookmarkStorage.categoryColors[_selectedColor][0]),
                      Color(BookmarkStorage.categoryColors[_selectedColor][1]),
                    ]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Your Categories', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.categories.map((cat) {
              final colors = BookmarkStorage.categoryColors[cat.colorIndex % BookmarkStorage.categoryColors.length];
              return Chip(
                backgroundColor: Color(colors[0]).withValues(alpha: 0.2),
                side: BorderSide(color: Color(colors[0]).withValues(alpha: 0.5)),
                label: Text(cat.name, style: TextStyle(color: Colors.white)),
                deleteIcon: cat.name != 'Uncategorized'
                    ? const Icon(Icons.close, size: 18, color: Colors.white54)
                    : null,
                onDeleted: cat.name != 'Uncategorized' ? () => widget.onCategoryDeleted(cat.name) : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
