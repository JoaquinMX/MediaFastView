import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/providers/repository_providers.dart';
import '../../domain/entities/tag_entity.dart';
import '../../domain/repositories/tag_repository.dart';
import '../states/tag_state.dart';

/// ViewModel for managing tag operations and state.
/// Handles CRUD operations, filtering, and tag management.
class TagViewModel extends StateNotifier<TagState> {
  TagViewModel(this._tagRepository) : super(const TagLoading()) {
    loadTags();
  }

  final TagRepository _tagRepository;
  final _uuid = const Uuid();

  /// Loads all tags from the repository.
  Future<void> loadTags() async {
    state = const TagLoading();
    try {
      final tags = await _tagRepository.getTags();
      if (tags.isEmpty) {
        state = const TagEmpty();
      } else {
        state = TagLoaded(tags);
      }
    } catch (e) {
      state = TagError(e.toString());
    }
  }

  /// Creates a new tag with the given name and color.
  Future<void> createTag(String name, int color) async {
    try {
      final tag = TagEntity(
        id: _uuid.v4(),
        name: name.trim(),
        color: color,
        createdAt: DateTime.now(),
      );

      await _tagRepository.createTag(tag);

      // Update state optimistically to avoid device update conflicts
      // Instead of reloading which causes TagLoading -> TagLoaded transition
      WidgetsBinding.instance.addPostFrameCallback((_) {
        state = switch (state) {
          TagLoaded(:final tags) => TagLoaded([...tags, tag]),
          _ => TagLoaded([tag]), // Fallback in case state is not loaded
        };
      });
    } catch (e) {
      // Delay error state update as well
      WidgetsBinding.instance.addPostFrameCallback((_) {
        state = TagError('Failed to create tag: $e');
      });
    }
  }

  /// Updates an existing tag.
  Future<void> updateTag(TagEntity tag) async {
    try {
      await _tagRepository.updateTag(tag);

      // Update state optimistically
      state = switch (state) {
        TagLoaded(:final tags) => TagLoaded(
          tags.map((t) => t.id == tag.id ? tag : t).toList(),
        ),
        _ => state, // Keep current state if not loaded
      };
    } catch (e) {
      state = TagError('Failed to update tag: $e');
    }
  }

  /// Deletes a tag by its ID.
  Future<void> deleteTag(String tagId) async {
    try {
      await _tagRepository.deleteTag(tagId);

      // Update state optimistically
      state = switch (state) {
        TagLoaded(:final tags) => tags.length <= 1
          ? const TagEmpty()
          : TagLoaded(tags.where((tag) => tag.id != tagId).toList()),
        _ => state, // Keep current state if not loaded
      };
    } catch (e) {
      state = TagError('Failed to delete tag: $e');
    }
  }

  /// Gets a tag by its ID.
  Future<TagEntity?> getTagById(String id) async {
    try {
      return await _tagRepository.getTagById(id);
    } catch (e) {
      state = TagError('Failed to get tag: $e');
      return null;
    }
  }

  /// Filters tags by a search query.
  void filterTags(String query) {
    state = switch (state) {
      TagLoaded(:final tags) => TagLoaded(_filterTagsByQuery(tags, query)),
      _ => state,
    };
  }

  /// Gets all tags (useful for external consumers).
  List<TagEntity> getAllTags() {
    return switch (state) {
      TagLoaded(:final tags) => tags,
      _ => const [],
    };
  }

  /// Checks if a tag with the given name already exists.
  bool tagNameExists(String name) {
    final trimmedName = name.trim().toLowerCase();
    return getAllTags().any((tag) => tag.name.toLowerCase() == trimmedName);
  }

  /// Helper method to filter tags by query.
  List<TagEntity> _filterTagsByQuery(List<TagEntity> tags, String query) {
    if (query.isEmpty) return tags;
    final lowerQuery = query.toLowerCase();
    return tags
        .where((tag) => tag.name.toLowerCase().contains(lowerQuery))
        .toList();
  }
}

/// Provider for TagViewModel with auto-dispose.
final tagViewModelProvider =
    StateNotifierProvider.autoDispose<TagViewModel, TagState>(
      (ref) => TagViewModel(ref.watch(tagRepositoryProvider)),
    );
