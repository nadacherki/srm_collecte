enum MobileJobType {
  download,
  sync,
}

class MobileJobGuard {
  MobileJobType? _activeJob;

  MobileJobType? get activeJob => _activeJob;

  bool get isBusy => _activeJob != null;

  bool tryStart(MobileJobType job) {
    if (_activeJob != null) {
      return false;
    }
    _activeJob = job;
    return true;
  }

  void finish(MobileJobType job) {
    if (_activeJob == job) {
      _activeJob = null;
    }
  }

  void reset() {
    _activeJob = null;
  }
}
