import '../entities/image_lookup_session.dart';

/// Stores the most recent lookup snapshots for each profile.
abstract interface class ImageLookupHistoryRepository {
  Future<List<ImageLookupSession>> load(String profileId);

  Future<void> save(ImageLookupSession session);

  Future<void> delete(String sessionId);

  Future<void> clear(String profileId);
}
