import '../../../media_library/domain/repositories/tag_repository.dart';

import 'clear_tag_assignments_use_case.dart';

/// Use case for removing all tags and their assignments.
class ClearTagsUseCase {
  const ClearTagsUseCase({
    required this.tagRepository,
    required this.clearTagAssignmentsUseCase,
  });

  final TagRepository tagRepository;
  final ClearTagAssignmentsUseCase clearTagAssignmentsUseCase;

  /// Removes every tag definition and clears related assignments.
  Future<void> call() async {
    await clearTagAssignmentsUseCase();
    await tagRepository.clearTags();
  }
}
