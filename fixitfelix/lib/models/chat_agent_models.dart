import 'package:equatable/equatable.dart';

class ChatSuggestion extends Equatable {
  final String id;
  final String label;

  const ChatSuggestion({required this.id, required this.label});

  factory ChatSuggestion.fromJson(Map<String, dynamic> json) {
    return ChatSuggestion(
      id: json['id'] ?? '',
      label: json['label'] ?? '',
    );
  }

  @override
  List<Object?> get props => [id, label];
}

class CollectedData extends Equatable {
  final String? serviceId;
  final String? serviceName;
  final String? categoryId;
  final String? categoryName;
  final String? optionId;
  final String? optionName;
  final List<String>? selections;
  final String? description;
  final String? professionalDescription;
  final String? urgency;

  const CollectedData({
    this.serviceId,
    this.serviceName,
    this.categoryId,
    this.categoryName,
    this.optionId,
    this.optionName,
    this.selections,
    this.description,
    this.professionalDescription,
    this.urgency,
  });

  factory CollectedData.fromJson(Map<String, dynamic> json) {
    return CollectedData(
      serviceId: json['service_id'],
      serviceName: json['service_name'],
      categoryId: json['category_id'],
      categoryName: json['category_name'],
      optionId: json['option_id'],
      optionName: json['option_name'],
      selections: json['selections'] != null
          ? List<String>.from(json['selections'])
          : null,
      description: json['description'],
      professionalDescription: json['professional_description'],
      urgency: json['urgency'],
    );
  }

  @override
  List<Object?> get props => [
        serviceId, serviceName, categoryId, categoryName,
        optionId, optionName, selections, description,
        professionalDescription, urgency,
      ];
}

class ChatMessage extends Equatable {
  final String role;
  final String text;
  final List<ChatSuggestion>? suggestions;
  final CollectedData? collectedData;
  final bool readyToSubmit;
  final String? tip;
  final String? warning;
  final String timestamp;

  const ChatMessage({
    required this.role,
    required this.text,
    this.suggestions,
    this.collectedData,
    this.readyToSubmit = false,
    this.tip,
    this.warning,
    this.timestamp = '',
  });

  bool get isAgent => role == 'agent';
  bool get isUser => role == 'user';
  bool get hasSuggestions => suggestions != null && suggestions!.isNotEmpty;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] ?? 'agent',
      text: json['text'] ?? '',
      suggestions: json['suggestions'] != null
          ? (json['suggestions'] as List)
              .map((s) => ChatSuggestion.fromJson(s as Map<String, dynamic>))
              .toList()
          : null,
      collectedData: json['collected_data'] != null
          ? CollectedData.fromJson(json['collected_data'] as Map<String, dynamic>)
          : null,
      readyToSubmit: json['ready_to_submit'] ?? false,
      tip: json['tip'],
      warning: json['warning'],
      timestamp: json['timestamp'] ?? '',
    );
  }

  /// Create a user message for optimistic UI
  factory ChatMessage.user(String text) {
    return ChatMessage(
      role: 'user',
      text: text,
      timestamp: DateTime.now().toUtc().toIso8601String(),
    );
  }

  @override
  List<Object?> get props => [
        role, text, suggestions, collectedData, readyToSubmit,
        tip, warning, timestamp,
      ];
}

class ChatSession extends Equatable {
  final String id;
  final String userId;
  final List<ChatMessage> messages;
  final CollectedData? collectedData;
  final bool readyToSubmit;
  final String createdAt;
  final String updatedAt;

  const ChatSession({
    required this.id,
    required this.userId,
    this.messages = const [],
    this.collectedData,
    this.readyToSubmit = false,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      messages: json['messages'] != null
          ? (json['messages'] as List)
              .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList()
          : [],
      collectedData: json['collected_data'] != null
          ? CollectedData.fromJson(json['collected_data'] as Map<String, dynamic>)
          : null,
      readyToSubmit: json['ready_to_submit'] ?? false,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  @override
  List<Object?> get props => [
        id, userId, messages, collectedData, readyToSubmit,
        createdAt, updatedAt,
      ];
}

class VoiceMessageResponse extends Equatable {
  final ChatMessage chatMessage;
  final String transcribedText;
  final String? audioResponse; // base64-encoded audio
  final String? audioContentType;

  const VoiceMessageResponse({
    required this.chatMessage,
    required this.transcribedText,
    this.audioResponse,
    this.audioContentType,
  });

  factory VoiceMessageResponse.fromJson(Map<String, dynamic> json) {
    return VoiceMessageResponse(
      chatMessage: ChatMessage.fromJson(
        json['chat_message'] as Map<String, dynamic>,
      ),
      transcribedText: json['transcribed_text'] ?? '',
      audioResponse: json['audio_response'],
      audioContentType: json['audio_content_type'],
    );
  }

  @override
  List<Object?> get props => [
        chatMessage, transcribedText, audioResponse, audioContentType,
      ];
}

enum FelixVoiceGender { male, female }

class VoicePreset extends Equatable {
  final String gender;
  final String voiceName;
  final String displayName;

  const VoicePreset({
    required this.gender,
    required this.voiceName,
    required this.displayName,
  });

  factory VoicePreset.fromJson(Map<String, dynamic> json) {
    return VoicePreset(
      gender: json['gender'] ?? 'female',
      voiceName: json['voice_name'] ?? '',
      displayName: json['display_name'] ?? '',
    );
  }

  @override
  List<Object?> get props => [gender, voiceName, displayName];
}

class VoiceConfig extends Equatable {
  final bool sttEnabled;
  final bool ttsEnabled;
  final String sttProvider;
  final String ttsProvider;
  final List<VoicePreset> voicePresets;
  final String? defaultVoice;

  const VoiceConfig({
    required this.sttEnabled,
    required this.ttsEnabled,
    required this.sttProvider,
    required this.ttsProvider,
    this.voicePresets = const [],
    this.defaultVoice,
  });

  factory VoiceConfig.fromJson(Map<String, dynamic> json) {
    return VoiceConfig(
      sttEnabled: json['stt_enabled'] ?? false,
      ttsEnabled: json['tts_enabled'] ?? false,
      sttProvider: json['stt_provider'] ?? 'none',
      ttsProvider: json['tts_provider'] ?? 'none',
      voicePresets: json['voice_presets'] != null
          ? (json['voice_presets'] as List)
              .map((p) => VoicePreset.fromJson(p as Map<String, dynamic>))
              .toList()
          : [],
      defaultVoice: json['default_voice'],
    );
  }

  /// Resolve a gender to the actual voice name from presets.
  String? voiceForGender(FelixVoiceGender gender) {
    final genderStr = gender == FelixVoiceGender.male ? 'male' : 'female';
    for (final preset in voicePresets) {
      if (preset.gender == genderStr) return preset.voiceName;
    }
    return defaultVoice;
  }

  @override
  List<Object?> get props => [
        sttEnabled, ttsEnabled, sttProvider, ttsProvider,
        voicePresets, defaultVoice,
      ];
}

class ChatCompletionResult extends Equatable {
  final String jobId;
  final String status;
  final String message;

  const ChatCompletionResult({
    required this.jobId,
    required this.status,
    required this.message,
  });

  factory ChatCompletionResult.fromJson(Map<String, dynamic> json) {
    return ChatCompletionResult(
      jobId: json['job_id'] ?? '',
      status: json['status'] ?? '',
      message: json['message'] ?? '',
    );
  }

  @override
  List<Object?> get props => [jobId, status, message];
}
