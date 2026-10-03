import 'config_service.dart';

const kSupportPhone = '01417376868';
const kSupportEmail = 'info@fixitfelixsoftwaresolution.com';
const kAppStoreId = '0000000000';
const kPlayStorePackage = 'com.techkushx.fixitfelix';

/// Default URLs used when the remote config (`helpCenterUrl`,
/// `termsAndConditionsUrl`, `privacyPolicyUrl`) is empty — keep these
/// in sync with the public site.
const _kHelpCenterFallback =
    'https://fixitfelixsoftwaresolutions.com/help';
const _kTermsFallback =
    'https://fixitfelixsoftwaresolutions.com/terms';
const _kPrivacyFallback =
    'https://fixitfelixsoftwaresolutions.com/privacy';

/// Public Help Center URL. Pulled from Firebase Remote Config
/// (`helpCenterUrl`) at runtime, falls back to the production site
/// when the key isn't set.
String resolveHelpCenterUrl() {
  final v = ConfigService().helpCenterUrl.trim();
  return v.isEmpty ? _kHelpCenterFallback : v;
}

/// Public Terms & Conditions URL. Pulled from Firebase Remote Config
/// (`termsAndConditionsUrl`), falls back to the production site.
String resolveTermsUrl() {
  final v = ConfigService().termsAndConditionsUrl.trim();
  return v.isEmpty ? _kTermsFallback : v;
}

/// Public Privacy Policy URL. Pulled from Firebase Remote Config
/// (`privacyPolicyUrl`), falls back to the production site.
String resolvePrivacyPolicyUrl() {
  final v = ConfigService().privacyPolicyUrl.trim();
  return v.isEmpty ? _kPrivacyFallback : v;
}
