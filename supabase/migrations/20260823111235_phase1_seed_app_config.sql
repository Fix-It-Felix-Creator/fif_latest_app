-- Phase 1 follow-up — seed app_config from the Firebase Remote Config backup.
--
-- Source: remote_config_backup_2026-05-14_v13.json — the 10 keys ConfigService reads.
-- Values are stored verbatim so ConfigService keeps its current parsing; only the
-- transport changes in Phase 7. Scalar keys are wrapped as {"value": ...} so every
-- row has a consistent jsonb shape.
--
-- Idempotent: re-running refreshes values without duplicating keys.

insert into public.app_config (key, value, description) values  ('prod_variable', '{"databaseUrl": "https://fifcloud-production.europe-west1.firebasedatabase.app", "stripeBackendUrl": "https://europe-west1-fifcloud.cloudfunctions.net/api", "stripePublishableKey": "pk_live_51SQwfQB9IngLGsue96qhsoPmtmg1N8rH4TCP8L1iYDIckXLmjRBPybZZ8u757kwTfBS1MVJhNcJ7BijzfUpUv0rV00uwHBioga", "debug": false, "privacyPolicyUrl": "https://fixitfelixsoftwaresolutions.com/privacy", "termsAndConditionsUrl": "https://fixitfelixsoftwaresolutions.com/terms", "helpCenterUrl": "https://fixitfelixsoftwaresolutions.com/help", "supportEmail": "info@fixitfelixsoftwaresolutions.com", "supportPhone": "0141 737 6868", "supportWhatsApp": "", "supportHours": "", "chatAgentBaseUrl": "", "youtubeChannelUrl": "https://www.youtube.com/@fixitfelixapp", "facebookGroupUrl": "https://www.facebook.com/groups/4486563368245907/"}'::jsonb, 'Migrated from Firebase Remote Config (backup v13)'),
  ('dev_variable', '{"databaseUrl": "https://fifcloud-default-rtdb.europe-west1.firebasedatabase.app", "stripeBackendUrl": "https://europe-west1-fifcloud.cloudfunctions.net/api", "stripePublishableKey": "pk_test_51SQwfXB46ng1aWFPGhydrBCj9ZrPFqnvgMTN2jo5kt0BqIIW9i6B2ViwqwtZc9Uorm2B8mnBJ04CY8SNRWp4pCA000jd0Xci5G", "debug": true, "privacyPolicyUrl": "https://fixitfelixsoftwaresolutions.com/privacy", "termsAndConditionsUrl": "https://fixitfelixsoftwaresolutions.com/terms", "helpCenterUrl": "https://fixitfelixsoftwaresolutions.com/help", "supportEmail": "info@fixitfelixsoftwaresolutions.com", "supportPhone": "0141 737 6868", "supportWhatsApp": "", "supportHours": "", "chatAgentBaseUrl": "", "youtubeChannelUrl": "https://www.youtube.com/@fixitfelixapp", "facebookGroupUrl": "https://www.facebook.com/groups/4486563368245907/"}'::jsonb, 'Migrated from Firebase Remote Config (backup v13)'),
  ('appstore_link', '{"value": ""}'::jsonb, 'Migrated from Firebase Remote Config (backup v13)'),
  ('playstore_link', '{"value": ""}'::jsonb, 'Migrated from Firebase Remote Config (backup v13)'),
  ('android_app_version', '{"value": "1.0.0"}'::jsonb, 'Migrated from Firebase Remote Config (backup v13)'),
  ('ios_app_version', '{"value": "1.0.0"}'::jsonb, 'Migrated from Firebase Remote Config (backup v13)'),
  ('force_app_update', '{"value": "false"}'::jsonb, 'Migrated from Firebase Remote Config (backup v13)'),
  ('dev_force_app_update', '{"value": "false"}'::jsonb, 'Migrated from Firebase Remote Config (backup v13)'),
  ('prod_maintenance', '{"isEnabled": false, "title": "Under Maintenance", "message": "We are currently performing maintenance.", "estimatedEndTime": null, "allowBypass": false}'::jsonb, 'Migrated from Firebase Remote Config (backup v13)'),
  ('dev_maintenance', '{"isEnabled": false, "title": "Under Maintenance", "message": "We are currently performing maintenance.", "estimatedEndTime": null, "allowBypass": false}'::jsonb, 'Migrated from Firebase Remote Config (backup v13)')
on conflict (key) do update
  set value       = excluded.value,
      description = excluded.description,
      updated_at  = now();
