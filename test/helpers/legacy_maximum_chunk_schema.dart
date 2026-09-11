// This test-only schema reproduces the persisted shape before byte-count
// metadata existed. Isar marks its generated-schema constructors protected.
// ignore_for_file: invalid_use_of_protected_member

import 'package:isar/isar.dart';
import 'package:media_fast_view/features/duplicates/data/isar/video_maximum_frame_index_chunk_collection.dart';

CollectionSchema<VideoMaximumFrameIndexChunkCollection>
legacyMaximumChunkSchema() {
  const current = VideoMaximumFrameIndexChunkCollectionSchema;
  return CollectionSchema<VideoMaximumFrameIndexChunkCollection>(
    id: current.id,
    name: current.name,
    properties: const <String, PropertySchema>{
      'chunkIndex': PropertySchema(
        id: 0,
        name: 'chunkIndex',
        type: IsarType.long,
      ),
      'computedAt': PropertySchema(
        id: 1,
        name: 'computedAt',
        type: IsarType.dateTime,
      ),
      'descriptorBytes': PropertySchema(
        id: 2,
        name: 'descriptorBytes',
        type: IsarType.byteList,
      ),
      'fingerprint': PropertySchema(
        id: 3,
        name: 'fingerprint',
        type: IsarType.string,
      ),
      'mediaId': PropertySchema(id: 4, name: 'mediaId', type: IsarType.string),
    },
    estimateSize: current.estimateSize,
    serialize: (object, writer, offsets, allOffsets) {
      writer.writeLong(offsets[0], object.chunkIndex);
      writer.writeDateTime(offsets[1], object.computedAt);
      writer.writeByteList(offsets[2], object.descriptorBytes);
      writer.writeString(offsets[3], object.fingerprint);
      writer.writeString(offsets[4], object.mediaId);
    },
    deserialize: (id, reader, offsets, allOffsets) =>
        VideoMaximumFrameIndexChunkCollection(
          chunkIndex: reader.readLong(offsets[0]),
          computedAt: reader.readDateTime(offsets[1]),
          descriptorBytes: reader.readByteList(offsets[2]) ?? <int>[],
          fingerprint: reader.readString(offsets[3]),
          mediaId: reader.readString(offsets[4]),
        ),
    deserializeProp: (reader, propertyId, offset, allOffsets) =>
        current.deserializeProp(
          reader,
          propertyId >= 3 ? propertyId + 1 : propertyId,
          offset,
          allOffsets,
        ),
    idName: current.idName,
    indexes: <String, IndexSchema>{
      'mediaId_chunkIndex': current.indexes['mediaId_chunkIndex']!,
    },
    links: current.links,
    embeddedSchemas: current.embeddedSchemas,
    getId: current.getId,
    getLinks: current.getLinks,
    attach: current.attach,
    version: current.version,
  );
}
