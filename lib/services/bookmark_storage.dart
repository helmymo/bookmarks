import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Bookmark {
  final String id;
  final String url;
  final String title;
  final String? favicon;
  final String category;
  final DateTime createdAt;

  Bookmark({
    required this.id,
    required this.url,
    required this.title,
    this.favicon,
    this.category = 'Uncategorized',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'title': title,
    'favicon': favicon,
    'category': category,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
    id: json['id'],
    url: json['url'],
    title: json['title'],
    favicon: json['favicon'],
    category: json['category'] ?? 'Uncategorized',
    createdAt: DateTime.parse(json['createdAt']),
  );

  Bookmark copyWith({
    String? id,
    String? url,
    String? title,
    String? favicon,
    String? category,
    DateTime? createdAt,
  }) {
    return Bookmark(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      favicon: favicon ?? this.favicon,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class Category {
  final String name;
  final String icon;
  final int colorIndex;

  Category({
    required this.name,
    this.icon = '📁',
    this.colorIndex = 0,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'icon': icon,
    'colorIndex': colorIndex,
  };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    name: json['name'],
    icon: json['icon'] ?? '📁',
    colorIndex: json['colorIndex'] ?? 0,
  );
}

class BookmarkStorage {
  static const String _bookmarksKey = 'saved_bookmarks';
  static const String _categoriesKey = 'saved_categories';
  
  // Default categories
  static final List<Category> defaultCategories = [
    Category(name: 'Uncategorized', icon: '📁', colorIndex: 0),
    Category(name: 'Work', icon: '💼', colorIndex: 1),
    Category(name: 'Personal', icon: '👤', colorIndex: 2),
    Category(name: 'Shopping', icon: '🛒', colorIndex: 3),
    Category(name: 'News', icon: '📰', colorIndex: 4),
    Category(name: 'Entertainment', icon: '🎬', colorIndex: 5),
  ];

  // Premium gradient colors for categories
  static const List<List<int>> categoryColors = [
    [0xFF6366F1, 0xFF8B5CF6], // Indigo
    [0xFFEC4899, 0xFFF472B6], // Pink
    [0xFF10B981, 0xFF34D399], // Green
    [0xFFF59E0B, 0xFFFBBF24], // Amber
    [0xFF3B82F6, 0xFF60A5FA], // Blue
    [0xFF8B5CF6, 0xFFA78BFA], // Purple
  ];

  // Singleton pattern
  static final BookmarkStorage _instance = BookmarkStorage._internal();
  factory BookmarkStorage() => _instance;
  BookmarkStorage._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Initialize default categories if none exist
    await _initializeCategories();
  }

  Future<void> _initializeCategories() async {
    final categories = await getCategories();
    if (categories.isEmpty) {
      for (var cat in defaultCategories) {
        await addCategory(cat);
      }
    }
  }

  /// Get all bookmarks
  Future<List<Bookmark>> getAllBookmarks() async {
    _prefs ??= await SharedPreferences.getInstance();
    final String? data = _prefs!.getString(_bookmarksKey);
    if (data == null) return [];
    
    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((e) => Bookmark.fromJson(e)).toList();
  }

  /// Search bookmarks by query
  Future<List<Bookmark>> searchBookmarks(String query) async {
    final all = await getAllBookmarks();
    if (query.isEmpty) return all;
    
    final lowerQuery = query.toLowerCase();
    return all.where((b) => 
      b.title.toLowerCase().contains(lowerQuery) ||
      b.url.toLowerCase().contains(lowerQuery) ||
      b.category.toLowerCase().contains(lowerQuery)
    ).toList();
  }

  /// Get bookmarks by category
  Future<List<Bookmark>> getBookmarksByCategory(String category) async {
    final all = await getAllBookmarks();
    if (category == 'All') return all;
    return all.where((b) => b.category == category).toList();
  }

  /// Add a new bookmark
  Future<bool> addBookmark(String url, {String title = '', String category = 'Uncategorized'}) async {
    final bookmarks = await getAllBookmarks();
    
    // Check for duplicates
    if (bookmarks.any((b) => b.url == url)) {
      return false;
    }

    final bookmark = Bookmark(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: url,
      title: title.isEmpty ? _extractDomain(url) : title,
      category: category,
      createdAt: DateTime.now(),
    );

    bookmarks.insert(0, bookmark);
    return await _saveBookmarks(bookmarks);
  }

  /// Update bookmark category
  Future<bool> updateBookmarkCategory(String id, String newCategory) async {
    final bookmarks = await getAllBookmarks();
    final index = bookmarks.indexWhere((b) => b.id == id);
    if (index == -1) return false;

    bookmarks[index] = bookmarks[index].copyWith(category: newCategory);
    return await _saveBookmarks(bookmarks);
  }

  /// Remove a bookmark
  Future<bool> removeBookmark(String id) async {
    final bookmarks = await getAllBookmarks();
    bookmarks.removeWhere((b) => b.id == id);
    return await _saveBookmarks(bookmarks);
  }

  /// Get all categories
  Future<List<Category>> getCategories() async {
    _prefs ??= await SharedPreferences.getInstance();
    final String? data = _prefs!.getString(_categoriesKey);
    if (data == null) return defaultCategories;
    
    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((e) => Category.fromJson(e)).toList();
  }

  /// Add a new category
  Future<bool> addCategory(Category category) async {
    final categories = await getCategories();
    if (categories.any((c) => c.name == category.name)) {
      return false;
    }
    
    categories.add(category);
    return await _saveCategories(categories);
  }

  /// Delete a category (moves bookmarks to Uncategorized)
  Future<bool> deleteCategory(String categoryName) async {
    if (categoryName == 'Uncategorized') return false;
    
    // Move bookmarks to Uncategorized
    final bookmarks = await getAllBookmarks();
    for (var i = 0; i < bookmarks.length; i++) {
      if (bookmarks[i].category == categoryName) {
        bookmarks[i] = bookmarks[i].copyWith(category: 'Uncategorized');
      }
    }
    await _saveBookmarks(bookmarks);

    // Remove category
    final categories = await getCategories();
    categories.removeWhere((c) => c.name == categoryName);
    return await _saveCategories(categories);
  }

  /// Export bookmarks to JSON string
  Future<String> exportBookmarks() async {
    final bookmarks = await getAllBookmarks();
    final categories = await getCategories();
    
    final exportData = {
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
      'categories': categories.map((c) => c.toJson()).toList(),
    };
    
    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  /// Import bookmarks from JSON string
  Future<int> importBookmarks(String jsonString) async {
    try {
      final data = jsonDecode(jsonString);
      int imported = 0;
      
      // Import categories
      if (data['categories'] != null) {
        final categories = (data['categories'] as List)
            .map((e) => Category.fromJson(e))
            .toList();
        for (var cat in categories) {
          await addCategory(cat);
        }
      }
      
      // Import bookmarks
      if (data['bookmarks'] != null) {
        final bookmarks = (data['bookmarks'] as List)
            .map((e) => Bookmark.fromJson(e))
            .toList();
        
        for (var bookmark in bookmarks) {
          final success = await addBookmark(
            bookmark.url,
            title: bookmark.title,
            category: bookmark.category,
          );
          if (success) imported++;
        }
      }
      
      return imported;
    } catch (e) {
      return -1;
    }
  }

  Future<bool> _saveBookmarks(List<Bookmark> bookmarks) async {
    _prefs ??= await SharedPreferences.getInstance();
    final data = jsonEncode(bookmarks.map((b) => b.toJson()).toList());
    return await _prefs!.setString(_bookmarksKey, data);
  }

  Future<bool> _saveCategories(List<Category> categories) async {
    _prefs ??= await SharedPreferences.getInstance();
    final data = jsonEncode(categories.map((c) => c.toJson()).toList());
    return await _prefs!.setString(_categoriesKey, data);
  }

  String _extractDomain(String url) {
    try {
      Uri uri = Uri.parse(url);
      return uri.host.isNotEmpty ? uri.host : url;
    } catch (e) {
      return url;
    }
  }
}
