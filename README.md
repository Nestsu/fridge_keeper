# Fridge Keeper V0.6

Offline-first Android Flutter app to track food, quantities, storage locations, and expiry dates. Thai UI. No login, cloud, or product key.

## Run on Windows

1. Install Flutter SDK and Android Studio. Run `flutter doctor`.
2. Extract this source archive, open a terminal in the `fridge_keeper` folder.
3. Create missing platform boilerplate: `flutter create --platforms=android --project-name fridge_keeper .`
4. Install dependencies: `flutter pub get`
5. Connect Android phone with USB debugging: `flutter run`
6. Build installable APK: `flutter build apk --release`.

**Note:** The Flutter and Dart SDK are not installed in the build environment used to prepare this archive; therefore compilation and device testing could not be run here. Android platform boilerplate is generated on your computer in step 3. Start with `flutter analyze` and `flutter test` locally.

## V0.6 — Custom Fridge Layout

- Tap the **fridge icon** in the Home app bar to manage multiple fridges.
- Add, rename, remove fridges; add, rename, reorder, remove shelves/zones.
- Expand a shelf to see its active food, and tap the move icon to relocate food.
- In Add/Edit Food, choose a precise **fridge › shelf** location.
- SQLite migration v2 → v3 creates the default fridge and maps previous
  location labels to zones without deleting foods, usage history, or photos.
- Zone deletion is blocked while ACTIVE food remains there; move it first.
  Completed/discarded records retain their old text location and usage history.
- Fridge deletion is blocked while active food remains, or if it is the last fridge.
- No login or network connection required.
- This is a location-list UI, not a scaled 3D or drag-and-drop fridge diagram.

## Test V0.6

1. `git pull origin main`, `flutter pub get`, `flutter analyze`, `flutter test`.
2. Run `flutter run` on the same Android installation **without uninstalling**.
3. Check that previously saved food and usage history still exist.
4. Tap the fridge icon, create a shelf, rename/reorder it and create a second fridge.
5. Edit food, choose the new fridge/shelf and save; verify the location on the food card.
6. Tap fridge icon again; expand the new shelf and move food to another shelf.
7. Attempt to delete an occupied shelf: it must be blocked.
8. Verify expiry notifications still work.

**Important:** App data will be lost if the app is uninstalled or its data is cleared.
Backup / Restore is still a planned follow-up feature.

## Existing features

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

- Local app storage is lost on uninstall or clearing app data; backup/export is planned for a later release.
- Dates are entered manually. Shelf life is not automatically inferred; follow product-specific storage guidance.
- No barcode scanning, shared family storage, or cloud sync yet.
