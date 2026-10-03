# Firebase Request Inventory — by domain

_Branch: `feature/firebase-cost-optimization` · Status: PLAN/REFERENCE — no code changed_

Purpose: list **every** Firebase communication, grouped by feature domain, with the
data shared and all listeners — so we can decide what moves to a local SQLite mirror.

Legend — **Op**: `LISTEN` = live `onValue` (cost driver), `READ` = one-shot get,
`WRITE` = set/update/push/remove, `HTTP` = Cloud Function, `STORAGE` = Cloud Storage.
**Local?**: ✅ cache in SQLite · ⚠️ partial/needs delta · ❌ keep direct (auth/payment/realtime).

---

## 1. Customers — `customers_repository.dart`

| Method | Path | Op | Data shared | Local? |
|---|---|---|---|---|
| `watchAll()` :15 | `customers/{uid}` | **LISTEN (broad)** | whole collection: name,email,phone,address*,city,county,postcode,lat,lng,company,notes,formattedAddress,createdAt,updatedAt | ✅ |
| `create(c)` :33 | `customers/{uid}` push+set | WRITE | full Customer | ✅ write-through |
| `update(c)` :47 | `customers/{uid}/{id}` | WRITE update | full Customer (updatedAt=now) | ✅ write-through |
| `delete(id)` :61 | `customers/{uid}/{id}` | WRITE remove | — | ✅ tombstone |

## 2. Jobs — `jobs_repository.dart`

| Method | Path | Op | Data shared | Local? |
|---|---|---|---|---|
| `findById(id)` :22 | `jobs/{uid}/{id}` | READ | full Job | ✅ from SQLite |
| `watchAll()` :38 | `jobs/{uid}` | **LISTEN (broad)** | whole collection: reference,title,description,status,startDate,createdAt,updatedAt,customer(snap),expenses[],attached{Photos,Videos,Files,Notes}[],linked{Quote,Invoice}Ids[] | ✅ |
| `create(job)` :53 | `jobs/{uid}` push+set | WRITE | full Job | ✅ write-through |
| `update(job)` :67 | `jobs/{uid}/{id}` | WRITE set | full Job | ✅ write-through |
| `updateStatus(id,s)` :79 | `jobs/{uid}/{id}` | WRITE update | `{status}` | ✅ write-through |
| `delete(id)` :91 | `jobs/{uid}/{id}` | WRITE remove | — | ✅ tombstone |
| `nextSequence()` :106 | `jobs/{uid}` | READ (full scan) | scans all `reference` | ⚠️ compute from SQLite |

## 3. Staff — `staff_repository.dart`

| Method | Path | Op | Data shared | Local? |
|---|---|---|---|---|
| `watchAll()` :15 | `staff/{uid}` | **LISTEN (broad)** | name,email,phone,defaultPayType,rate,unitMarkup,createdAt,updatedAt | ✅ |
| `create(s)` :33 | `staff/{uid}` push+set | WRITE | full Staff | ✅ write-through |
| `update(s)` :47 | `staff/{uid}/{id}` | WRITE update | full Staff | ✅ write-through |
| `delete(id)` :61 | `staff/{uid}/{id}` | WRITE remove | — | ✅ tombstone |

## 4. Pricing — `pricing_repository.dart`

| Method | Path | Op | Data shared | Local? |
|---|---|---|---|---|
| `watchAll()` :17 | `pricing/{uid}` | **LISTEN (broad)** | kind,name,unitCost,unitMarkup,itemCode,createdAt,updatedAt | ✅ |
| `create/update/delete` :35/49/63 | `pricing/{uid}[/{id}]` | WRITE | full PricingItem / — | ✅ write-through |

## 5. To-Dos — `todo_repository.dart`

| Method | Path | Op | Data shared | Local? |
|---|---|---|---|---|
| `watchAll()` :18 | `todos/{uid}` | **LISTEN (broad)** | title,notes?,dueAt?,tagColor?,completed,createdAt,updatedAt | ✅ |
| `create` :32 | `todos/{uid}` push+set | WRITE | todo fields | ✅ write-through |
| `update` :60 | `todos/{uid}/{id}` | WRITE update | title,notes,updatedAt,dueAt?,tagColor? | ✅ write-through |
| `setCompleted` :96 | `todos/{uid}/{id}` | WRITE update | completed,completedAt,updatedAt | ✅ write-through |
| `delete` :113 | `todos/{uid}/{id}` | WRITE remove | — | ✅ tombstone |

## 6. Quotes — `quotes_repository.dart`

| Method | Path / Endpoint | Op | Data shared | Local? |
|---|---|---|---|---|
| `findById(id)` :44 | `quotes/{uid}/{id}` | READ | full Quote | ✅ from SQLite |
| `watchAll()` :73 | `quotes/{uid}` | **LISTEN (broad)** | full Quote incl. denormalized customer, lines(+pricing), staff, terms, attached* | ✅ |
| `create(q)` :91 | `quotes/{uid}` push+set | WRITE | serialized Quote | ✅ write-through |
| `update(q)` :105 | `quotes/{uid}/{id}` | WRITE set | full Quote | ✅ write-through |
| `updateStatus` :117 | `quotes/{uid}/{id}` | WRITE update | `{status}` | ✅ write-through |
| `markAsSent` :134 | `quotes/{uid}/{id}` | READ+WRITE | `{status:sent,sentAt}` | ✅ write-through |
| `delete(id)` :164 | POST `/quotes/delete` | HTTP | `{quoteId}` | ❌ keep (server cleans shares) |
| `sendQuoteEmail` :200 | POST `/quotes/send-email` | HTTP | `{quoteId,message?}` | ❌ keep |
| `getShareLink` :243 | POST `/quotes/share-link` | HTTP | `{quoteId}` | ❌ keep |

## 7. Quote Settings — `quote_settings_repository.dart`

| Method | Path | Op | Data shared | Local? |
|---|---|---|---|---|
| `watchSettings()` :21 | `quoteSettings/{uid}` | **LISTEN (narrow, 1 obj)** | QuoteSettings | ✅ small, cache+delta |
| `updateSettings` :31 | `quoteSettings/{uid}` | WRITE set | QuoteSettings | ✅ write-through |
| `watchTerms()` :43 | `quoteTerms/{uid}` | **LISTEN (broad)** | QuoteTerm list | ✅ |
| `createTerm/updateTerm/deleteTerm` :58/72/86 | `quoteTerms/{uid}[/{id}]` | WRITE | name,details,createdAt,updatedAt / — | ✅ write-through |

## 8. Invoices — `invoices_repository.dart`

| Method | Path / Endpoint | Op | Data shared | Local? |
|---|---|---|---|---|
| `findById(id)` :34 | `invoices/{uid}/{id}` | READ | full Invoice | ✅ from SQLite |
| `watchAll()` :53 | `invoices/{uid}` | **LISTEN (broad)** | full Invoice incl. denormalized customer, lines, staff, bankSnapshot, terms, attached* | ✅ |
| `create` :70 | `invoices/{uid}` push+set | WRITE | serialized Invoice | ✅ write-through |
| `update` :84 | `invoices/{uid}/{id}` | WRITE set | full Invoice | ✅ write-through |
| `updateStatus` :96 | `invoices/{uid}/{id}` | WRITE update | `{status}` | ✅ write-through |
| `markAsSent` :114 | `invoices/{uid}/{id}` | READ+WRITE | `{status:sent,sentAt}` | ✅ write-through |
| `markAsPaid` :139 | `invoices/{uid}/{id}` | WRITE update | `{status:paid,paidAt}` | ✅ write-through |
| `delete` :159 | POST `/invoices/delete` | HTTP | `{invoiceId}` | ❌ keep |
| `sendInvoiceEmail` :194 | POST `/invoices/send-email` | HTTP | `{invoiceId,message?}` | ❌ keep |
| `getShareLink` :237 | POST `/invoices/share-link` | HTTP | `{invoiceId}` | ❌ keep |

## 9. Tools — Notes / Files / Photos / Videos

| Method | RTDB / Storage | Op | Data shared | Local? |
|---|---|---|---|---|
| Notes `watchAll()` :17 | `userTools/{uid}/notes` | **LISTEN (broad)** | id,title,body,createdAt,updatedAt | ✅ |
| Notes `create/update/delete` :35/58/74 | `userTools/{uid}/notes[/{id}]` | WRITE | title,body,timestamps | ✅ write-through |
| Files `watchAll()` :17 | `userTools/{uid}/files` | **LISTEN (broad)** | id,title,description,url,storagePath,fileName,mimeType,sizeBytes,createdAt | ✅ (metadata only) |
| Files `upload()` :34 | RTDB push + Storage `users/{uid}/tools/files/{id}/{fn}` | WRITE+STORAGE | metadata + file bytes; **progress listener not cancelled** | ⚠️ metadata ✅, blob ❌ |
| Files `delete()` :84 | RTDB + Storage | WRITE+STORAGE del | — | ✅ tombstone + ❌ blob del |
| Photos `watchAll()` :20 | `userTools/{uid}/photos` | **LISTEN (broad)** | id,title,description,url,storagePath,sizeBytes,createdAt | ✅ (metadata only) |
| Photos `upload` :40 / `updateMeta` :86 / `delete` :105 | RTDB + Storage `users/{uid}/tools/photos/...` | WRITE+STORAGE | metadata + bytes; **progress listener not cancelled** | ⚠️ as files |
| Videos `watchAll()` :25 | `userTools/{uid}/videos` | **LISTEN (broad)** | +thumbnailUrl,thumbnailStoragePath | ✅ (metadata only) |
| Videos `upload` :42 / `delete` :117 | RTDB + Storage video + thumb | WRITE+STORAGE x2 | metadata + bytes; **progress listener not cancelled** | ⚠️ as files |

## 10. Journal — `journal_repository.dart`

| Method | Path | Op | Data shared | Local? |
|---|---|---|---|---|
| `watchAll()` :16 | `journalEvents/{uid}` | **LISTEN (broad, unbounded)** | id,title,date,allDay,startAt,endAt,customerId,customerName,location,notes,createdAt,updatedAt | ✅ + retention |
| `create/update/delete` :41/78/112 | `journalEvents/{uid}[/{id}]` | WRITE | event fields / — | ✅ write-through |

## 11. Notifications — `notifications_repository.dart`

| Method | Path / Endpoint | Op | Data shared | Local? |
|---|---|---|---|---|
| `watchAll()` :32 | `notifications/{uid}` | **LISTEN (broad, unbounded)** | id,createdAt,body,… | ⚠️ cache + delta; server-pushed |
| `markRead/markAllRead` :52/55 | POST `/notifications/mark-read` | HTTP | `{notificationId}` / `{all:true}` | ❌ keep |
| `clear/clearAll` :58/61 | POST `/notifications/clear` | HTTP | `{notificationId}` / `{}` | ❌ keep |

## 12. Usage / Limits — `usage_repository.dart`

| Method | Path | Op | Data shared | Local? |
|---|---|---|---|---|
| `getUserLimits` :77 | `users/{uid}` + `config/subscriptions/...` | READ x2 | reads **whole user** for accountType+planType | ⚠️ cache user; read narrow path |
| `getUserUsageStats` :139 | `users/{uid}` + `usages/{uid}` | READ x2 | whole user + all usage counts | ⚠️ cache |
| `watchUsageStats` :269 | `usages/{uid}` | **LISTEN (narrow)** + async\* (leak risk) | ~14 usage counters | ⚠️ keep narrow listener or poll |
| `canAdd*` x6 :376-415 | (derived) | READ (repeat) | repeatedly calls getUserUsageStats | ⚠️ use cached |
| `*UsageCount*` increment/decrement :664-871 | `usages/{uid|userId}` | WRITE (ServerValue.increment); decrement does READ+WRITE | `{field:±1}` | ❌ keep server-atomic (quota integrity) |
| `getUserUsageStatsForUser` :571 | `users/{userId}`+`usages/{userId}` | READ x2 | whole other-user object | ❌ keep (cross-user) |
| `resetUsage` :817 | `usages/{uid}` | WRITE update | counts→0 | ❌ keep |
| `saveUsageStats` :496 | `usages/{uid}` | WRITE update | 7 counts | ⚠️ |

## 13. Subscription / Config

| Method | Path | Op | Data shared | Local? |
|---|---|---|---|---|
| `subscription_repository.getPlans` :64 | `config/subscriptions/{type}` | READ (in-mem cache) | all plans | ✅ cache long |
| `subscription_repository.watchPlans` :109 | `config/subscriptions/{type}` | **LISTEN (broad)** — **LEAKS** (`_subscriptions` map never populated) | all plans | ⚠️ replace w/ cached get |
| `commission_repository.getRates` :48 | `config/commissionRates` | READ (in-mem cache) | rates | ✅ cache long |
| `commission_repository.watchRates` :84 | `config/commissionRates` | **LISTEN** — re-call leaks prior sub | rates | ⚠️ replace w/ cached get |
| `subscription_config_service.getAllPlanConfigs` :52 | `config/subscriptions` | READ (30-min cache) | whole subs tree | ✅ extend cache |
| `subscription_config_service.getVideoLimits` :202 | `config/videoLimits` | READ (not cached) | video limits | ✅ cache |
| `app_config_service.initialize` :45 | `config` (whole tree) | READ (once/session cache) | entire config | ✅ already cached; persist locally |
| `subscription_listener_service.startListening` :42 | `users/{uid}/subscription/{member,tool}` | **LISTEN x2 (narrow)** | planDisplayName,status / name,status | ❌ keep (small, realtime billing-critical) |

## 14. Auth / User — `authentication_repository.dart`

| Method | Path | Op | Data shared | Local? |
|---|---|---|---|---|
| `signInWith{Email,Google,Apple}` :79/134/182 | FirebaseAuth + `users/{uid}` | WRITE auth + READ/WRITE | accountType / id,email,first,last | ❌ keep |
| `_persistOAuthNameIfMissing` :241 | `users/{uid}` | READ+WRITE | reads whole user to check name | ⚠️ read narrow |
| `getUserDetails` :464 | `users/{uid}` | READ (cache-aware) | whole user | ⚠️ already cached; back with SQLite |
| `streamUserDetails` :611 | `users/{uid}` | **LISTEN (narrow, 1 obj)** — caller cancels | whole user | ❌ keep (small, drives auth/UI) |
| `saveUserDetails/updateUserDetails` :427/448 | `users/{uid}` | WRITE update | full / partial | ❌ keep |
| `updateSubscription` :714 | `users/{uid}` | WRITE update | subscription, usage resets | ❌ keep |
| `getUserRole/_validateAccountType/isAccountDisabled` :588/1002/986 | `users/{uid}/{role,accountType,accountStatus}` | READ (narrow ✅) | single field | ✅ already narrow; cache |
| `handleAuthentication` :813 | `users/{uid}` + accountStatus | READ x2 (whole user x2) | whole user | ⚠️ read narrow / reuse cache |
| `uploadProfileImage` :747 | `users/{uid}/profileImage` + Storage | WRITE+STORAGE | image url | ❌ keep |
| `deleteAccount*` :399/691 | `users/{uid}` + Storage | WRITE remove | whole user | ❌ keep |

## 15. Device / Session — `device_info_repository.dart`

| Method | Path | Op | Data shared | Local? |
|---|---|---|---|---|
| `saveDeviceInfo` :156 | `users/{uid}/devices/{deviceId}` | READ+WRITE | device meta | ❌ keep (security) |
| `createLoginSession` :286 | `users/{uid}/sessions/{sid}` | WRITE set | session record | ❌ keep |
| `updateSessionActivity` :337 | `…/sessions/{sid}` | WRITE update | lastActivityAt | ⚠️ **throttle** |
| `setSessionActive` :361 | session + device | WRITE x2 | status+lastActivityAt | ⚠️ **throttle** (2 writes/foreground) |
| `setSessionInactive` :389 | `…/sessions/{sid}` | WRITE update | status=inactive | ⚠️ throttle |
| `onAppOpened` :857 | device + session | WRITE x2 | lastActiveAt | ⚠️ throttle |
| `getUserDevices/getActiveSessions/getSessionHistory` :216/481/528 | `…/devices`,`/sessions`,`/sessionHistory` | READ (broad/query) | device & session lists | ❌ keep (security view) |
| `startForceLogoutListener` :750 | `users/{uid}/devices/{deviceId}` | **LISTEN (narrow)** — cancelled on logout | forceLogoutAt,isActive,reason | ❌ keep (security realtime) |
| `_forceLogoutAllOtherDevices` :675 | sessions + devices + per-device | READ x2 + WRITE xN | clears tokens | ❌ keep |

## 16. Push Notifications — `push_notifications_service.dart`

| Method | Path | Op | Data shared | Local? |
|---|---|---|---|---|
| `initialise` :32 | FCM + Auth | **LISTEN x3** (authStateChanges, onTokenRefresh, onMessageOpenedApp) — **no `dispose()`** | — | ❌ keep; **add dispose** |
| `syncToken/_persistToken` :79/107 | `users/{uid}/fcmTokens/{key}` | WRITE set | token,platform,createdAt,lastSeenAt | ⚠️ skip if token unchanged |
| `clearToken` :93 | `users/{uid}/fcmTokens/{key}` | WRITE remove | — | ❌ keep |

---

## Summary — what moves local

**✅ Full SQLite mirror (write-through + delta):** customers, jobs, staff, pricing,
todos, quotes, quote terms/settings, invoices, journal, tool metadata
(notes/files/photos/videos). → eliminates **~14 broad `onValue` listeners**.

**✅ Long-lived local cache (rarely changes):** all `config/*`
(subscriptions, commissionRates, video/image limits) — read once, persist locally.

**⚠️ Cache + narrow read / delta:** user object (`users/{uid}` — read narrow paths,
back with SQLite), usage counters (keep one narrow listener or poll), notifications
(server-pushed — cache + delta).

**❌ Keep direct (do NOT cache):** all FirebaseAuth, payment/Stripe HTTP,
share-link/email/delete Cloud Functions, usage increment/decrement
(server-atomic for quota integrity), device/session security writes,
force-logout listener, subscription member/tool listener, profile image upload.

**Leaks to fix regardless of SQLite:** `subscription_repository.watchPlans`,
`commission_repository.watchRates`, `usage_repository.watchUsageStats`,
`push_notifications_service` (no dispose), tool upload progress listeners.

**Cloud Storage blobs** (photos/videos/files binary) stay in Storage — only their
**metadata rows** move to SQLite.
