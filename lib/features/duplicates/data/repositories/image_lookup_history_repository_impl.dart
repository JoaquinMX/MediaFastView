import '../../domain/entities/image_lookup_session.dart';
import '../../domain/repositories/image_lookup_history_repository.dart';
import '../data_sources/image_lookup_history_data_source.dart';
import '../isar/image_lookup_history_collection.dart';
import '../services/image_lookup_session_serializer.dart';

/// Isar-backed history repository with a ten-session cap per profile.
class ImageLookupHistoryRepositoryImpl implements ImageLookupHistoryRepository {
  const ImageLookupHistoryRepositoryImpl(
    this._dataSource, {
    ImageLookupSessionSerializer serializer =
        const ImageLookupSessionSerializer(),
  }) : _serializer = serializer;

  static const int maximumSessions = 10;

  final ImageLookupHistoryDataSource _dataSource;
  final ImageLookupSessionSerializer _serializer;

  @override
  Future<List<ImageLookupSession>> load(String profileId) async {
    final rows = await _dataSource.getForProfile(profileId);
    final sessions = <ImageLookupSession>[];
    for (final row in rows) {
      try {
        sessions.add(_serializer.decode(row.payloadJson));
      } catch (_) {
        // A corrupt history row should not make the lookup screen unusable.
      }
    }
    return List<ImageLookupSession>.unmodifiable(sessions);
  }

  @override
  Future<void> save(ImageLookupSession session) async {
    await _dataSource.put(
      ImageLookupHistoryCollection(
        sessionId: session.id,
        profileId: session.profileId,
        createdAt: session.createdAt,
        payloadJson: _serializer.encode(session),
      ),
    );
    final rows = await _dataSource.getForProfile(session.profileId);
    for (final row in rows.skip(maximumSessions)) {
      await _dataSource.delete(row.sessionId);
    }
  }

  @override
  Future<void> delete(String sessionId) => _dataSource.delete(sessionId);

  @override
  Future<void> clear(String profileId) => _dataSource.clearProfile(profileId);
}
