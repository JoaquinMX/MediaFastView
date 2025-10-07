import '../entities/tag_entity.dart';
import '../repositories/tag_repository.dart';

/// Use case for retrieving all tags.
/// Provides a clean interface for fetching tags from the repository.
class GetTagsUseCase {
  const GetTagsUseCase(this._tagRepository);

  final TagRepository _tagRepository;

  /// Retrieves all tags from the repository.
  Future<List<TagEntity>> call() => _tagRepository.getTags();
}