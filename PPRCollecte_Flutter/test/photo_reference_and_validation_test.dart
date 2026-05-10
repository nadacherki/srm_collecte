import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:srm_collecte/data/remote/api_service.dart';
import 'package:srm_collecte/services/photo_reference_service.dart';
import 'package:srm_collecte/services/photo_slot_service.dart';
import 'package:srm_collecte/services/photo_validation_service.dart';

void main() {
  group('PhotoReferenceService', () {
    test('distinguishes remote references from local references', () {
      expect(
          PhotoReferenceService.isRemoteReference('https://srv/p.jpg'), true);
      expect(PhotoReferenceService.isRemoteReference('/media/p.jpg'), true);
      expect(PhotoReferenceService.isRemoteReference('media/p.jpg'), true);
      expect(PhotoReferenceService.isRemoteReference('srm_photos/p.jpg'), true);

      expect(PhotoReferenceService.isLocalReference('C:/tmp/photo.jpg'), true);
      expect(PhotoReferenceService.isLocalReference('/tmp/photo.jpg'), true);
      expect(PhotoReferenceService.isLocalReference('/media/p.jpg'), false);
      expect(PhotoReferenceService.isLocalReference(''), false);
    });

    test('builds absolute URLs only for server-side photo references', () {
      expect(
        PhotoReferenceService.buildRemoteUrl('https://srv/p.jpg'),
        'https://srv/p.jpg',
      );
      expect(
        PhotoReferenceService.buildRemoteUrl('/media/p.jpg'),
        '${ApiService.baseUrl}/media/p.jpg',
      );
      expect(
        PhotoReferenceService.buildRemoteUrl('media/p.jpg'),
        '${ApiService.baseUrl}/media/p.jpg',
      );
      expect(
        PhotoReferenceService.buildRemoteUrl('srm_photos/p.jpg'),
        '${ApiService.baseUrl}/media/srm_photos/p.jpg',
      );
      expect(PhotoReferenceService.buildRemoteUrl('C:/tmp/photo.jpg'), isNull);
    });
  });

  group('PhotoSlotService', () {
    test('exposes only filled slots plus the next available slot', () {
      expect(PhotoSlotService.visibleSlotCount({}, 4, allowAdd: true), 1);
      expect(
        PhotoSlotService.visibleSlotCount({1: 'a.jpg'}, 4, allowAdd: true),
        2,
      );
      expect(
        PhotoSlotService.visibleSlotCount(
          {1: 'a.jpg', 2: 'b.jpg', 3: 'c.jpg', 4: 'd.jpg'},
          4,
          allowAdd: true,
        ),
        4,
      );
      expect(
        PhotoSlotService.visibleSlotCount({1: 'a.jpg'}, 4, allowAdd: false),
        1,
      );
    });

    test('prevents jumping ahead to later empty slots', () {
      expect(PhotoSlotService.canPickSlot({}, 1, 4), isTrue);
      expect(PhotoSlotService.canPickSlot({}, 3, 4), isFalse);
      expect(PhotoSlotService.canPickSlot({1: 'a.jpg'}, 2, 4), isTrue);
      expect(PhotoSlotService.canPickSlot({1: 'a.jpg'}, 4, 4), isFalse);
      expect(PhotoSlotService.canPickSlot({1: 'a.jpg'}, 1, 4), isTrue);
    });

    test('compacts local photos after removing a middle slot', () {
      final compacted = PhotoSlotService.removeAndCompact(
        {1: 'a.jpg', 2: 'b.jpg', 3: 'c.jpg'},
        1,
        4,
      );

      expect(compacted[1], 'b.jpg');
      expect(compacted[2], 'c.jpg');
      expect(compacted[3], isNull);
      expect(compacted[4], isNull);
    });

    test('keeps remote photo references anchored while compacting locals', () {
      final compacted = PhotoSlotService.removeAndCompact(
        {
          1: 'local-a.jpg',
          2: 'media/remote-b.jpg',
          3: 'local-c.jpg',
        },
        1,
        4,
        isLockedReference: PhotoReferenceService.isRemoteReference,
      );

      expect(compacted[1], 'local-c.jpg');
      expect(compacted[2], 'media/remote-b.jpg');
      expect(compacted[3], isNull);
    });
  });

  group('PhotoValidationService duplicate detection', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('srm_photo_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('detects duplicate files by content fingerprint', () async {
      final candidate = File('${tempDir.path}/candidate.jpg');
      final duplicate = File('${tempDir.path}/duplicate.jpg');
      final other = File('${tempDir.path}/other.jpg');

      final bytes = List<int>.generate(160, (index) => index % 251);
      await candidate.writeAsBytes(bytes);
      await duplicate.writeAsBytes(bytes);
      await other.writeAsBytes(
        List<int>.generate(160, (index) => (index + 17) % 251),
      );

      expect(
        await PhotoValidationService.findDuplicateSlot(
          candidatePath: candidate.path,
          existingPaths: {
            1: other.path,
            2: duplicate.path,
          },
        ),
        2,
      );
      expect(
        await PhotoValidationService.findDuplicateSlot(
          candidatePath: candidate.path,
          existingPaths: {
            2: duplicate.path,
          },
          currentSlot: 2,
        ),
        isNull,
      );
    });

    test('returns null for missing candidates or distinct photos', () async {
      final candidate = File('${tempDir.path}/candidate.jpg');
      final other = File('${tempDir.path}/other.jpg');
      await candidate.writeAsBytes(List<int>.filled(100, 1));
      await other.writeAsBytes(List<int>.filled(100, 2));

      expect(
        await PhotoValidationService.findDuplicateSlot(
          candidatePath: '${tempDir.path}/missing.jpg',
          existingPaths: {1: other.path},
        ),
        isNull,
      );
      expect(
        await PhotoValidationService.findDuplicateSlot(
          candidatePath: candidate.path,
          existingPaths: {1: other.path},
        ),
        isNull,
      );
    });
  });
}
