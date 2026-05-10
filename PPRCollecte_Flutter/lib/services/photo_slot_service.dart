class PhotoSlotService {
  const PhotoSlotService._();

  static Map<int, String?> compact(
    Map<int, String?> photoPaths,
    int maxSlots, {
    bool Function(String value)? isLockedReference,
  }) {
    final result = <int, String?>{
      for (var slot = 1; slot <= maxSlots; slot++) slot: null,
    };
    final movable = <String>[];

    for (var slot = 1; slot <= maxSlots; slot++) {
      final value = _clean(photoPaths[slot]);
      if (value == null) continue;
      if (isLockedReference?.call(value) == true) {
        result[slot] = value;
      } else {
        movable.add(value);
      }
    }

    var writeSlot = 1;
    for (final value in movable) {
      while (writeSlot <= maxSlots && _hasValue(result[writeSlot])) {
        writeSlot++;
      }
      if (writeSlot > maxSlots) break;
      result[writeSlot] = value;
      writeSlot++;
    }

    return result;
  }

  static Map<int, String?> removeAndCompact(
    Map<int, String?> photoPaths,
    int removedSlot,
    int maxSlots, {
    bool Function(String value)? isLockedReference,
  }) {
    final removedValue = _clean(photoPaths[removedSlot]);
    if (removedValue != null && isLockedReference?.call(removedValue) == true) {
      return compact(
        photoPaths,
        maxSlots,
        isLockedReference: isLockedReference,
      );
    }

    final copy = Map<int, String?>.from(photoPaths);
    copy[removedSlot] = null;
    return compact(copy, maxSlots, isLockedReference: isLockedReference);
  }

  static int firstEmptySlot(Map<int, String?> photoPaths, int maxSlots) {
    for (var slot = 1; slot <= maxSlots; slot++) {
      if (!_hasValue(photoPaths[slot])) return slot;
    }
    return maxSlots + 1;
  }

  static bool canPickSlot(
    Map<int, String?> photoPaths,
    int slot,
    int maxSlots,
  ) {
    if (slot < 1 || slot > maxSlots) return false;
    if (_hasValue(photoPaths[slot])) return true;
    return slot == firstEmptySlot(photoPaths, maxSlots);
  }

  static int visibleSlotCount(
    Map<int, String?> photoPaths,
    int maxSlots, {
    required bool allowAdd,
  }) {
    if (maxSlots <= 0) return 0;

    var lastFilled = 0;
    for (var slot = 1; slot <= maxSlots; slot++) {
      if (_hasValue(photoPaths[slot])) lastFilled = slot;
    }

    if (!allowAdd) return lastFilled;

    final nextSlot = firstEmptySlot(photoPaths, maxSlots);
    if (nextSlot > maxSlots) return maxSlots;
    return nextSlot > lastFilled ? nextSlot : lastFilled;
  }

  static String? _clean(String? value) {
    final clean = value?.trim() ?? '';
    return clean.isEmpty ? null : clean;
  }

  static bool _hasValue(String? value) => _clean(value) != null;
}
