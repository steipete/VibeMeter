## Software Specification: Vibe Meter
https://aistudio.google.com/prompts/1K2XHHytMLpeecOT1sjHqmRXdpodqT-ge
https://www.cursor.com/settings

**Version:** 1.2
**Date:** October 26, 2023 (Placeholder - Reflects latest updates)

**1. Overview & Purpose**

Vibe Meter is a macOS menu bar application designed to help users monitor their monthly spending on the Cursor AI service. It provides at-a-glance cost information, configurable warning and upper spending limits with notifications, and multi-currency display options. The application requires users to log into their Cursor account via an embedded web view to obtain session cookies for data fetching. The application aims for a user-friendly and slightly "vibey" tone in its auxiliary communications, keeping it positive and approachable.

**2. Target Platform**

*   **Operating System:** Latest generally available (GA) version of macOS.
*   **Architecture:** Universal Binary (Apple Silicon & Intel).

**3. Core Components & Modules**

1.  **Menu Bar Controller:** Manages the status bar item, its icon, text display, and the dropdown menu.
2.  **Login Manager:** Handles the embedded web view for Cursor login, cookie extraction, and secure cookie storage/retrieval (macOS Keychain). Manages session state (logged in/out).
3.  **Cursor API Client:** Makes authenticated requests to the Cursor API to fetch team, user, and monthly invoice data. Handles request construction, response parsing, and error handling.
4.  **Exchange Rate Manager:** Fetches and caches exchange rates from a public API for currency conversion. Manages a list of supported currencies. Handles failures by defaulting display to USD.
5.  **Settings Manager:** Manages application settings (limits, selected currency, refresh interval, etc.) using `UserDefaults`.
6.  **UI Manager:** Handles the Settings dialog window and system notifications. Uses SwiftUI preferentially for these windows.
7.  **Startup Manager:** Manages the "Launch at Login" functionality.
8.  **Logging Service:** Manages logging of key events and errors to Console.app.

**4. Detailed Feature Specifications**

**4.1. Application Icon & Menu Bar Display**

*   **Icon:** Use the `menubar-icon.png` asset (to be provided as a file).
*   **Text Display:**
    *   Format: `[CUR_SYMBOL][Current Spending] / [CUR_SYMBOL][Warning Limit]`
        *   Example (USD): `$12.34 / $200.00`
        *   Example (EUR): `€11.50 / €184.00`
    *   Current Spending: Fetched from Cursor API (originally in USD cents), converted to selected currency.
    *   Warning Limit: User-defined, converted to selected currency for display.
    *   **If Exchange Rate Service Fails:** All monetary values in the menu bar (and throughout the app) will be displayed in USD ($) regardless of the user's selected currency preference, until the exchange rate service becomes available again.
    *   If not logged in: Display "Login Required".
    *   If data fetch error post-login (e.g., API error, network error, `teamId` fetch failure): Display "Error".
    *   Updates periodically based on a user-configurable interval (default 5 minutes) and on manual refresh.
    *   After successful login: Briefly (2-3 seconds) display "Vibe synced! ✨" before switching to spending data.

**4.2. Dropdown Menu**

*   **Logged In As:** `[User's Email]` (fetched from `/api/auth/me`).
    *   If user info fetch fails but login is active: Display "Logged In".
*   **Current Spending:** `Current: [CUR_SYMBOL][Amount]` (converted to selected currency; defaults to USD if rates unavailable).
*   **Warning Limit:** `Warning at: [CUR_SYMBOL][Amount]` (user-defined, converted; defaults to USD if rates unavailable).
*   **Upper Limit (Cursor Cap):** `Max: [CUR_SYMBOL][Amount]` (user-defined, converted; defaults to USD if rates unavailable).
*   **Team:** `Vibing with: [Team Name]` (fetched from `/api/dashboard/teams`).
*   --- (Separator) ---
*   **Refresh Now:**
    *   Action: Immediately triggers a data fetch sequence (team info, user info, invoice data) and updates display.
    *   If not logged in, **always** triggers the login prompt.
*   **Vibe Meter Status/Error Messages (Contextual, displayed at the top if applicable):**
    *   If `teamId` fetch failed post-login: `"Hmm, can't find your team vibe right now. 😕 Try a refresh?"` Other data fields will be blank or show loading state.
    *   If exchange rates are unavailable: `"Rates MIA! Showing USD for now. ✨"`
*   **Settings...:**
    *   Action: Opens the Settings dialog window.
*   **Log Out:**
    *   Action:
        1.  Clears `WorkosCursorSessionToken` from macOS Keychain.
        2.  Clears stored `teamId` (Int), `teamName` (String), and `userEmail` (String) from `UserDefaults`.
        3.  Updates menu bar display to "Login Required".
        4.  Sets internal state to logged-out.
*   --- (Separator) ---
*   **Launch at Login:** (Checkbox menu item)
    *   Action: Toggles adding/removing the application from system login items. State reflects current setting.
*   **Quit Vibe Meter:**
    *   Action: Terminates the application.

**4.3. Login Process**

*   **Trigger:** On app start if no valid session cookie, on auth error during data fetch, or manual refresh while logged out.
*   **Mechanism:**
    1.  Display a modal window (preferentially SwiftUI) containing a `WKWebView`.
    2.  Load `https://authenticator.cursor.sh/`.
    3.  User authenticates.
    4.  Monitor `WKNavigationDelegate` for redirect to URL starting with `https://www.cursor.com/api/auth/callback`.
    5.  On successful completion of callback navigation:
        *   Extract `WorkosCursorSessionToken` cookie (for `cursor.com` domain) from `WKWebView`'s cookie store.
        *   Store cookie value securely in macOS Keychain.
        *   Close login window.
        *   Proceed to fetch team info, user info, then invoice data.
        *   Update menu bar display (brief "Vibe synced! ✨" then spending data).
    *   No additional introductory pop-ups beyond showing the login window are required for first launch.

**4.4. Data Fetching (Cursor API)**

*   **Definition of "Current Month/Year":** Based on the user's local machine time.
*   **A. Team Information:**
    *   Endpoint: `POST https://www.cursor.com/api/dashboard/teams`
    *   Request Body: Empty JSON (`{}`).
    *   Headers: `Cookie: WorkosCursorSessionToken=[TOKEN]`, `Content-Type: application/json`.
    *   Response: `{"teams": [{"id": TEAM_ID_INT, "name": "Team Name", ...}]}`.
    *   Logic: Use `teams[0].id` (as Int) for `teamId` and `teams[0].name` (as String) for `teamName`. Store in `UserDefaults`. If `teams` array is empty or request fails, handle as a `teamId` fetch error (menu bar "Error", specific message in dropdown).
*   **B. User Information:**
    *   Endpoint: `GET https://www.cursor.com/api/auth/me`
    *   Headers: `Cookie: WorkosCursorSessionToken=[TOKEN]`.
    *   Response: `{"email": "user@example.com", ...}`.
    *   Logic: Extract `email`. Store as `userEmail` (String) in `UserDefaults`.
*   **C. Monthly Invoice Data:**
    *   Endpoint: `POST https://www.cursor.com/api/dashboard/get-monthly-invoice`
    *   Request Body (JSON):
        ```json
        {
            "teamId": <INTEGER_TEAM_ID_FROM_USERDEFAULTS>,
            "month": <CURRENT_MONTH_INTEGER_LOCAL_TIME>, // 1-12
            "year": <CURRENT_YEAR_INTEGER_LOCAL_TIME>,
            "includeUsageEvents": false
        }
        ```
    *   Headers: `Cookie: WorkosCursorSessionToken=[TOKEN]`, `Content-Type: application/json`.
    *   Response: `{"items": [{"description": "...", "cents": ...}, ...], "pricingDescription": ...}`.
    *   Total Calculation: Sum all `cents` values from the `items` array. This sum is `totalSpendingCents`.
    *   Convert `totalSpendingCents` to `currentSpendingUSD` (Double, divide by 100.0).
*   **Frequency:** Periodically (user-configurable `refreshIntervalMinutes`, default 5 minutes) and on "Refresh Now". Fetch sequence: Team Info -> User Info -> Invoice Data.

**4.5. Settings Dialog (Preferentially SwiftUI)**

*   **Layout:** Standard macOS settings window.
*   **Fields:**
    1.  **Currency:**
        *   UI: Dropdown/Picker.
        *   Values: List of supported currencies (see 4.6).
        *   Storage: `selectedCurrencyCode` (String) in `UserDefaults`. Remains on user's selection even if rates fail.
    2.  **Warning Limit:**
        *   UI: Number Input Field. Label shows selected currency symbol or "$" if rates unavailable (e.g., "Warning Limit (€):" or "Warning Limit ($):").
        *   Behavior: User enters value in the displayed currency. If rates are unavailable, input is explicitly in USD.
        *   Display: If re-opening, shows the re-converted value of stored USD limit to the selected currency using the current rate (or the USD value if rates unavailable).
        *   Storage: On save, convert input to USD and store as `warningLimitUSD` (Double) in `UserDefaults`. Default: `200.0` (USD).
    3.  **Upper Limit:** (Same UI/Behavior/Display/Storage logic as Warning Limit). Default: `1000.0` (USD).
    4.  **Automatic Refresh Interval:**
        *   UI: Dropdown/Picker.
        *   Label: "Auto-Refresh Vibe Every:"
        *   Values: 5 minutes (Default), 10 minutes, 15 minutes, 30 minutes, 60 minutes.
        *   Storage: `refreshIntervalMinutes` (Int) in `UserDefaults`.
*   **Buttons:**
    *   **Save:** Persists all settings. Triggers display/timer refresh if relevant settings changed. Closes dialog.
    *   **Cancel:** Discards changes made since dialog opened/last saved. Closes dialog.
*   **Status:** Label: "Logged in as [userEmail]" or "Login Required."

**4.6. Currency Management**

*   **Supported Currencies:** USD (Default), EUR, GBP, JPY, CAD, AUD, CHF, CNY, INR, PHP. (Defined list).
*   **Base Currency:** USD. Limits stored in USD. API data received as USD cents.
*   **Exchange Rate API:** Frankfurter.app (`https://api.frankfurter.app/latest?from=USD&to=EUR,GBP,...`). No API key.
*   **Caching:** Store `cachedExchangeRates: [String: Double]` and `lastExchangeRateFetchTimestamp` in `UserDefaults`. Refresh daily or if older than 24h.
*   **Failure Handling:** If exchange rate API fails or rates are unavailable:
    *   All monetary display defaults to USD ($).
    *   Settings dialog limit inputs show currency symbol as "$" and expect USD values, even if currency dropdown shows another selection.
    *   Dropdown menu includes: `"Rates MIA! Showing USD for now. ✨"`
*   **Fallback Rates:** Hardcode fallback rates (sourced at development time, infrequent updates to codebase needed).

**4.7. User Notifications**

*   **Framework:** macOS User Notifications.
*   **Triggers:**
    1.  Warning Limit Reached: `currentSpendingUSD >= warningLimitUSD`.
    2.  Upper Limit Reached: `currentSpendingUSD >= upperLimitUSD`.
*   **Content (Vibey):**
    *   Warning: `"Heads up! Your Cursor spend ([CUR_SYMBOL][Amount]) is getting close to your [CUR_SYMBOL][Limit] warning vibe!"`
    *   Upper: `"Whoa! Your Cursor spend ([CUR_SYMBOL][Amount]) is hitting the [CUR_SYMBOL][Limit] max vibe! Time to chill?"`
    *   Amounts displayed in selected currency (or USD if rates unavailable).
*   **Frequency:** Notify once per limit type (Warning/Upper) per app session, *unless spending dips below that specific limit and then crosses it again*. If spending goes below a limit for which a notification was sent, the "notified" state for that limit is reset for the current session.

**4.8. Launch at Login**

*   Use `SMLoginItemSetEnabled` or equivalent for latest macOS. Checkbox in menu controls state.

**5. Data Storage Summary (`UserDefaults` & Keychain)**

*   **macOS Keychain:**
    *   `WorkosCursorSessionToken` (String).
*   **`UserDefaults`:**
    *   `selectedCurrencyCode` (String, e.g., "USD").
    *   `warningLimitUSD` (Double).
    *   `upperLimitUSD` (Double).
    *   `teamId` (Int).
    *   `teamName` (String).
    *   `userEmail` (String).
    *   `cachedExchangeRates` ([String: Double]).
    *   `lastExchangeRateFetchTimestamp` (Date/Timestamp).
    *   `refreshIntervalMinutes` (Int, default 5).
    *   `launchAtLoginEnabled` (Bool).
    *   (Internal flags for notification state per limit, per session - not persisted across app restarts).

**6. Error Handling & Edge Cases**

*   **No Internet:** Graceful fetch failure, "Error" in menu bar. Log.
*   **Cursor API Down/Error:** "Error" in menu bar. Log details (URL, status, error message).
*   **Invalid Session Cookie (401/403):** Clear cookie, prompt re-login. Log.
*   **Exchange Rate API Down:** Default to USD display. Log.
*   **`teamId` Fetch Failure (post-login):** Menu bar "Error", specific message in dropdown. Log.
*   **First Launch:** Automatically show login window. Sensible defaults for settings.

**7. UI/UX Considerations**

*   Clear, at-a-glance info. Responsive. Minimalist. Friendly "vibey" tone in auxiliary text (notifications, contextual error messages); core data display remains standard. Privacy awareness.

**8. Technical Implementation Details**

*   **Language:** Swift 6 (or latest stable).
*   **IDE:** Xcode (latest).
*   **macOS Target:** Latest GA macOS version.
*   **Architecture:** MVVM, Service/Manager classes, Swift Concurrency (`async/await`).
*   **Frameworks:** AppKit, WebKit (for `WKWebView`, `WKNavigationDelegate`, cookie store), Security (Keychain), Foundation, UserNotifications, ServiceManagement. **SwiftUI preferred for Settings and Login windows.**
*   **Menu Bar Only App:** `LSUIElement` set to `true` in `Info.plist`.
*   **Testing:** XCTest for unit tests (core logic, data handling, services with mocks). High coverage desired. UI tests optional.
*   **Dependencies:** Minimize.
*   **Code Style:** Swift API Design Guidelines, linters (e.g., SwiftLint).
*   **Logging:** Use `os_log` or `Logger` API to log key events and errors to Console.app for developer debugging. No user-facing log retrieval for V1.

**9. Assumptions & Dependencies**

*   Stability of specified (unofficial) Cursor API endpoints, request/response structures, and `WorkosCursorSessionToken` usage. This is the primary external risk.
*   Frankfurter.app exchange rate API remains available and free without keys.
*   User has an active Cursor account.
*   `menubar-icon.png` asset will be provided.