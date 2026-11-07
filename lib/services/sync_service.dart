/// Cloud synchronization is intentionally not advertised as active.
/// This release stores records in SQLite on the device only.
class SyncService {
  Future<bool> hasNetwork() async => false;
  Future<void> synchronize() async {
    throw UnsupportedError('Google Drive synchronization is not configured.');
  }
}
