import 'dart:io';
import 'package:flutter/foundation.dart';
import '../constants/position_constants.dart';
import '../models/player_model.dart';
import '../providers/player_provider.dart';
import '../services/backend_api_service.dart';

enum SubmitState { idle, submitting, success, error }
enum AiSummaryState { idle, loading, ready, error }

/// Holds the submit-a-player form's transient UI state, kept separate from
/// PlayerProvider (which owns the feed) so the form can be reset/disposed
/// independently of feed data.
class UploadFormController extends ChangeNotifier {
  final PlayerProvider playerProvider;
  final BackendApiService _backendApi = BackendApiService();
  UploadFormController(this.playerProvider);

  PlayerPosition? position;
  File? videoFile;
  SubmitState state = SubmitState.idle;

  AiSummaryState aiState = AiSummaryState.idle;
  String? aiSummary;
  String? aiError;

  /// Id of the row just inserted — used by the post-submit boost dialog to
  /// tag the M-Pesa payment to the right player. Null until a submit
  /// succeeds.
  String? lastSubmittedPlayerId;

  void setPosition(PlayerPosition? p) {
    position = p;
    notifyListeners();
  }

  void setVideo(File? file) {
    videoFile = file;
    notifyListeners();
  }

  /// Calls the backend's AI endpoint for a short scouting-note preview.
  /// Optional — the submit button doesn't wait on this, it's just a
  /// "see how this reads" preview the submitter can request before
  /// sending the form.
  Future<void> generateAiPreview({
    required String name,
    required String country,
    required int age,
    String? club,
    String? strengths,
  }) async {
    if (position == null || name.trim().isEmpty || country.trim().isEmpty) {
      aiError = 'Fill in name, position, and country first';
      aiState = AiSummaryState.error;
      notifyListeners();
      return;
    }

    aiState = AiSummaryState.loading;
    aiError = null;
    notifyListeners();

    try {
      final summary = await _backendApi.summarizePlayer(
        name: name,
        position: position!.dbValue,
        age: age,
        country: country,
        club: club,
        strengths: strengths,
      );
      aiSummary = summary;
      aiState = AiSummaryState.ready;
    } catch (e) {
      aiError = 'Could not generate a preview — is the backend configured? (${e.toString()})';
      aiState = AiSummaryState.error;
    }
    notifyListeners();
  }

  Future<bool> submit({
    required String name,
    required int age,
    required String country,
    String? club,
    String? strengths,
    String? contactEmail,
    String? contactPhone,
    String? league,
    int? height,
    String? foot,
  }) async {
    if (position == null) return false;
    state = SubmitState.submitting;
    notifyListeners();

    final player = Player(
      id: '', // assigned by Supabase on insert
      name: name,
      position: position!,
      age: age,
      country: country,
      club: club,
      strengths: strengths,
      contactEmail: contactEmail,
      contactPhone: contactPhone,
      league: league,
      height: height,
      foot: foot,
    );

    final newId = await playerProvider.submitPlayer(player, videoFile: videoFile);
    lastSubmittedPlayerId = newId;
    state = newId != null ? SubmitState.success : SubmitState.error;
    notifyListeners();
    return newId != null;
  }

  void reset() {
    position = null;
    videoFile = null;
    state = SubmitState.idle;
    aiState = AiSummaryState.idle;
    aiSummary = null;
    aiError = null;
    // lastSubmittedPlayerId is deliberately NOT cleared here — the boost
    // dialog needs it after reset() has already run post-submit.
    notifyListeners();
  }
}
