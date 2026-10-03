import 'tradesman_services.dart';

/// Helper to get a TradesmanServiceItem by its key
TradesmanServiceItem? getTradesmanServiceByKey(String key) {
  try {
    return tradesmanServices.firstWhere((s) => s.key == key);
  } catch (_) {
    return null;
  }
}

/// All trade keys that have calculators
const List<String> tradeKeysWithTools = [
  'plumber',
  'electrician',
  'roofer',
  'builder',
  'gardener',
  'painter',
  'landscaper',
  'carpenter',
  'plasterer',
  'tree_surgeon',
  'handyman',
  'locksmith',
  'tiler',
  'central_heating',
  'boiler_repair',
  'mechanic',
  'cleaner',
  'glazier',
  'gas_engineer',
  'hvac_technician',
  'scaffolder',
  'welder',
  'kitchen_fitter',
  'hairdresser',
];
