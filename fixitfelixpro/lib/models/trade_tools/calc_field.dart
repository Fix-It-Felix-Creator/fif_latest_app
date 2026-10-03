/// Types of input/output fields in a calculator
enum FieldType {
  number,
  integer,
  dropdown,
  slider,
  toggle,
  calculated,
}

/// Defines a single input or output field for a calculator
class CalcField {
  final String id;
  final String label;
  final String? unit;
  final FieldType type;
  final double? min;
  final double? max;
  final dynamic defaultValue;
  final String? helpText;
  final String? group;
  final int decimalPlaces;
  final List<String>? options;
  final String? prefix;

  const CalcField({
    required this.id,
    required this.label,
    this.unit,
    this.type = FieldType.number,
    this.min,
    this.max,
    this.defaultValue,
    this.helpText,
    this.group,
    this.decimalPlaces = 2,
    this.options,
    this.prefix,
  });
}
