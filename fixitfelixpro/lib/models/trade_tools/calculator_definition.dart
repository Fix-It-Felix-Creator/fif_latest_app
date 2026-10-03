import 'package:flutter/material.dart';

import 'calc_field.dart';
import 'tool_tier.dart';

/// Defines a complete calculator with inputs, outputs, and calculation logic
class CalculatorDefinition {
  final String id;
  final String name;
  final String description;
  final String tradeKey;
  final ToolTier tier;
  final IconData icon;
  final List<CalcField> inputs;
  final List<CalcField> outputs;
  final Map<String, dynamic> Function(Map<String, dynamic> inputs) calculate;
  final List<String> tags;
  final String? formula;
  final String? notes;

  const CalculatorDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.tradeKey,
    this.tier = ToolTier.defaultTier,
    required this.icon,
    required this.inputs,
    required this.outputs,
    required this.calculate,
    this.tags = const [],
    this.formula,
    this.notes,
  });
}
