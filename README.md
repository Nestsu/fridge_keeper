# Fridge Keeper V0.5

Offline-first Android Flutter app to track food, quantities, storage locations, and expiry dates. Thai UI. No login, cloud, or product key.

## Run on Windows

1. Install Flutter SDK and Android Studio. Run `flutter doctor`.
2. Extract this source archive, open a terminal in the `fridge_keeper` folder.
3. Create missing platform boilerplate: `flutter create --platforms=android --project-name fridge_keeper .`
4. Install dependencies: `flutter pub get`
5. Connect Android phone with USB debugging: `flutter run`
6. Build installable APK: `flutter build apk --release`.

**Note:** The Flutter and Dart SDK are not installed in the build environment used to prepare this archive; therefore compilation and device testing could not be run here. Android platform boilerplate is generated on your computer in step 3. Start with `flutter analyze` and `flutter test` locally.

## V0.4 features

- Dashboard with counts, urgent items, sorted expiry-first.
- Add, edit, search, filter, and delete food.
- Separate batches of same product with different dates.
- Quantity/units, purchase date, optional expiry date, storage location, photos.
- Consume one unit, mark finished, mark discarded. Each action creates a dated usage history event.
- Dashboard distinguishes item count from stock quantities, grouped by unit (boxes, bottles, grams, etc.).
- SQLite schema automatically migrates from v1 to v2, retaining existing food rows.
- Compact dashboard and small add button that no longer covers food cards.
- Quick-use minus button directly on each food card, with a confirmation snackbar.
- Usage history grouped by day, with totals for used and discarded actions.
- Undo from the confirmation snackbar or the latest event for each item in History.
- Undo restores stock, reactivates a depleted item, and removes the reversed usage event atomically.
- Enter a custom amount to consume from an item's action menu (e.g. use 3 eggs at once).
- Dashboard is shorter: removed the redundant grouped-unit summary panel.
- Confirm before consuming the last available quantity or discarding an item; regular partial use remains one tap with Undo.
- Android offline expiry reminders, optional 1/3/7-day lead time at approximately 09:00.
- Notification settings through the bell in the app bar, including permission request and instant test.
- Scheduled reminders are refreshed when food changes and after reopening the app; boot receiver reschedules after restart.

## Android notification setup and tests

- After `git pull`, run `flutter pub get` and `flutter run`. The native Android Gradle and Manifest changes are included.
- Tap the bell icon and enable notifications; allow the Android notification permission prompt.
- Tap **Test notification** to verify delivery to the notification shade.
- Select 1, 3 or 7 days; choose a future expiry date and close the app. Reminders are scheduled for about 09:00 local device time; Android may delay inexact alarms.
- No exact-alarm permission is requested. Notification permission, Android battery policy and user settings may affect delivery.
- App data is still local-only: uninstalling or clearing app storage removes inventory. Backup/restore is planned next.
- SQLite local persistence and local permanent photo copies.
- No account, internet, or push notifications required.

## Limitations

- Local app storage is lost on uninstall or clearing app data; backup/export is planned for V0.2.
- Dates are entered manually. Shelf life is not automatically inferred; follow product-specific storage guidance.
- No barcode scanning, shared family storage, or cloud sync yet.
