import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile_response.dart';
import '../repositories/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

final profileStreamProvider = StreamProvider<ProfileResponse>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return repository.getProfileStream();
});

class ProfileNotifier extends AsyncNotifier<ProfileResponse> {
  late ProfileRepository _repository;

  @override
  Future<ProfileResponse> build() async {
    _repository = ref.watch(profileRepositoryProvider);
    // Return the latest from the stream
    return ref.watch(profileStreamProvider.future);
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final previousState = state;
    state = const AsyncValue.loading();
    try {
      await _repository.updateProfile(data);
      // Re-fetch to get the newly calculated completion percentage and updated data
      ref.invalidate(profileStreamProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      // Fallback to previous state on failure, or let the UI handle the error state
      if (previousState.hasValue) {
        state = previousState;
      }
      rethrow;
    }
  }

  Future<void> addAddress(Map<String, dynamic> data) async {
    try {
      await _repository.addAddress(data);
      ref.invalidate(profileStreamProvider);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateAddress(String id, Map<String, dynamic> data) async {
    try {
      await _repository.updateAddress(id, data);
      ref.invalidate(profileStreamProvider);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteAddress(String id) async {
    try {
      await _repository.deleteAddress(id);
      ref.invalidate(profileStreamProvider);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updatePreferences(Map<String, dynamic> data) async {
    try {
      await _repository.updatePreferences(data);
      ref.invalidate(profileStreamProvider);
    } catch (e) {
      rethrow;
    }
  }
}

final profileNotifierProvider =
    AsyncNotifierProvider<ProfileNotifier, ProfileResponse>(
  () => ProfileNotifier(),
);
