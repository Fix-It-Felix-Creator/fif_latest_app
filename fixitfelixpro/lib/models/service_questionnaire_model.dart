import 'package:equatable/equatable.dart';

/// Represents a single option in a service questionnaire
class ServiceOption extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? nextQuestion;
  final List<ServiceOption>? options;
  final bool requiresDescription;
  final bool urgent;

  const ServiceOption({
    required this.id,
    required this.name,
    this.description,
    this.nextQuestion,
    this.options,
    this.requiresDescription = false,
    this.urgent = false,
  });

  factory ServiceOption.fromJson(Map<String, dynamic> json) {
    return ServiceOption(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      nextQuestion: json['nextQuestion'] as String?,
      options: json['options'] != null
          ? (json['options'] as List)
                .map((e) => ServiceOption.fromJson(e as Map<String, dynamic>))
                .toList()
          : null,
      requiresDescription: json['requiresDescription'] as bool? ?? false,
      urgent: json['urgent'] as bool? ?? false,
    );
  }

  bool get hasNestedOptions => options != null && options!.isNotEmpty;

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    nextQuestion,
    options,
    requiresDescription,
    urgent,
  ];
}

/// Represents a category in a service questionnaire
class ServiceCategory extends Equatable {
  final String id;
  final String name;
  final String? icon;
  final bool urgent;
  final bool requiresDescription;
  final List<ServiceOption>? options;

  const ServiceCategory({
    required this.id,
    required this.name,
    this.icon,
    this.urgent = false,
    this.requiresDescription = false,
    this.options,
  });

  factory ServiceCategory.fromJson(Map<String, dynamic> json) {
    return ServiceCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      urgent: json['urgent'] as bool? ?? false,
      requiresDescription: json['requiresDescription'] as bool? ?? false,
      options: json['options'] != null
          ? (json['options'] as List)
                .map((e) => ServiceOption.fromJson(e as Map<String, dynamic>))
                .toList()
          : null,
    );
  }

  bool get hasOptions => options != null && options!.isNotEmpty;

  @override
  List<Object?> get props => [
    id,
    name,
    icon,
    urgent,
    requiresDescription,
    options,
  ];
}

/// Represents a complete service questionnaire loaded from JSON
class ServiceQuestionnaire extends Equatable {
  final String service;
  final String title;
  final List<ServiceCategory> categories;

  const ServiceQuestionnaire({
    required this.service,
    required this.title,
    required this.categories,
  });

  factory ServiceQuestionnaire.fromJson(Map<String, dynamic> json) {
    return ServiceQuestionnaire(
      service: json['service'] as String,
      title: json['title'] as String,
      categories: (json['categories'] as List)
          .map((e) => ServiceCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [service, title, categories];
}

/// Represents a single step in the questionnaire flow
class QuestionStep extends Equatable {
  final String question;
  final List<ServiceOption> options;
  final bool isRequired;
  final String? categoryIcon;

  const QuestionStep({
    required this.question,
    required this.options,
    this.isRequired = true,
    this.categoryIcon,
  });

  @override
  List<Object?> get props => [question, options, isRequired, categoryIcon];
}

/// Tracks the user's selections through the questionnaire
class QuestionnaireSelection extends Equatable {
  final int stepIndex;
  final ServiceOption? selectedOption;

  const QuestionnaireSelection({required this.stepIndex, this.selectedOption});

  @override
  List<Object?> get props => [stepIndex, selectedOption];
}
