## Software Specification: Vibe Meter (Electron Edition)

**Version:** 1.2-E
**Date:** October 26, 2023 (Placeholder - Reflects Electron porting)

**1. Overview & Purpose**

Vibe Meter is a **cross-platform menu bar/system tray** application designed to help users monitor their monthly spending on the Cursor AI service. It provides at-a-glance cost information, configurable warning and upper spending limits with notifications, and multi-currency display options. The application requires users to log into their Cursor account via an embedded web view to obtain session cookies for data fetching. The application aims for a user-friendly and slightly "vibey" tone in its auxiliary communications.

**2. Target Platforms**

*   **Operating Systems:** Latest macOS, latest Windows (10/11), common Linux distributions (e.g., Ubuntu LTS).
*   **Architecture:** Build targets for common architectures (e.g., x64, arm64 for macOS).

**3. Core Components & Modules (Electron Architecture)**

1.  **Main Process (Node.js):**
    *   Manages application lifecycle, system tray icon, context menu.
    *   Handles inter-process communication (IPC) with Renderer processes.
    *   Orchestrates background tasks (API calls, exchange rate fetching).
    *   Manages secure storage (using `electron-store` or `node-keytar`).
    *   Handles native system features (notifications, launch at login).
2.  **Renderer Process(es) (Chromium - HTML/CSS/JavaScript):**
    *   **Login Window:** `BrowserWindow` with a `<webview>` tag or `BrowserView` for Cursor login.
    *   **Settings Window:** `BrowserWindow` displaying the settings UI (built with web technologies).
    *   (The menu bar display itself is often managed by the Main process, but might get data from a hidden renderer or directly).
3.  **Cursor API Client (Node.js in Main Process):** Uses `axios` or `node-fetch` for authenticated requests.
4.  **Exchange Rate Manager (Node.js in Main Process):** Fetches and caches rates.
5.  **Settings Manager (Node.js in Main Process):** Uses `electron-store` for application settings.
6.  **UI Manager (IPC & Renderer):** Main process triggers native notifications. Renderer processes build window UIs.
7.  **Startup Manager (Node.js in Main Process):** Uses Electron's `app.setLoginItemSettings()` API.

**4. Detailed Feature Specifications**

**4.1. Application Icon & System Tray/Menu Bar Display**

*   **Icon:** Use the `menubar-icon.png` asset (should be suitable for various OS tray icon styles).
*   **Text Display (System Tray Tooltip / Menu Bar Item Text):**
    *   Format: `[CUR_SYMBOL][Current Spending] / [CUR_SYMBOL][Warning Limit]`
    *   Implementation: The Main process will update the tray icon's tooltip (Windows/Linux) or the `Tray` item's title (macOS, if text is directly supported, otherwise via an image).
    *   **If Exchange Rate Service Fails:** Display defaults to USD.
    *   If not logged in: Tooltip/text indicates "Login Required".
    *   If error: Tooltip/text indicates "Error".
    *   Updates periodically (user-configurable, default 5 minutes) and on manual refresh.
    *   After successful login: Briefly (2-3 seconds) display "Vibe synced! ✨" as tooltip/title.

**4.2. Context Menu (Right-click on Tray Icon / Click on Menu Bar Icon)**

*   **Logged In As:** `[User's Email]`
    *   If user info fetch fails: Display "Logged In".
*   **Current Spending:** `Current: [CUR_SYMBOL][Amount]`
*   **Warning Limit:** `Warning at: [CUR_SYMBOL][Amount]`
*   **Upper Limit (Cursor Cap):** `Max: [CUR_SYMBOL][Amount]`
*   **Team:** `Vibing with: [Team Name]`
*   --- (Separator) ---
*   **Refresh Now:**
    *   Action: Triggers data fetch in Main process via IPC.
    *   If not logged in, **always** triggers the login window.
*   **Vibe Meter Status/Error Messages (Contextual):**
    *   If `teamId` fetch failed: `"Hmm, can't find your team vibe right now. 😕 Try a refresh?"`
    *   If exchange rates unavailable: `"Rates MIA! Showing USD for now. ✨"`
*   **Settings...:**
    *   Action: Opens the Settings `BrowserWindow`.
*   **Log Out:**
    *   Action: Clears session token (from `node-keytar`), clears relevant settings from `electron-store`, updates tray display.
*   --- (Separator) ---
*   **Launch at Login:** (Checkbox menu item)
    *   Action: Toggles `app.setLoginItemSettings()`.
*   **Quit Vibe Meter:**
    *   Action: `app.quit()`.

**4.3. Login Process**

*   **Trigger:** Similar to macOS version.
*   **Mechanism:**
    1.  Main process creates and shows a `BrowserWindow`.
    2.  This window loads a renderer HTML page containing a `<webview>` tag (or uses a `BrowserView`) pointing to `https://authenticator.cursor.sh/`.
    3.  User authenticates.
    4.  The `<webview>`'s session or the main app's default session (if `BrowserView` and shared session) is monitored for navigations (e.g., `did-navigate` event on `<webview>`).
    5.  Monitor for redirect to URL starting with `https://www.cursor.com/api/auth/callback`.
    6.  On successful completion of callback navigation:
        *   Access the relevant cookie store (e.g., `webview.session.cookies` or `session.defaultSession.cookies`).
        *   Get `WorkosCursorSessionToken` for `cursor.com` domain.
        *   Store cookie value securely using `node-keytar` (cross-platform Keychain/Credentials Manager access).
        *   Close login window.
        *   Proceed with data fetching sequence in Main process.

**4.4. Data Fetching (Cursor API - Performed in Main Process)**

*   **Definition of "Current Month/Year":** User's local machine time.
*   **HTTP Client:** `axios` or `node-fetch`.
*   **A. Team Information:** (Endpoint, Request, Response, Logic same as macOS version, executed in Node.js). Store `teamId` (Int) and `teamName` in `electron-store`.
*   **B. User Information:** (Endpoint, Request, Response, Logic same as macOS version, executed in Node.js). Store `userEmail` in `electron-store`.
*   **C. Monthly Invoice Data:** (Endpoint, Request, Response, Total Calculation same as macOS version, executed in Node.js).
*   **Frequency:** Same as macOS version.

**4.5. Settings Dialog (Renderer Process - BrowserWindow with Web UI)**

*   **UI Technology:** HTML, CSS, JavaScript (potentially with a framework like React, Vue, or Svelte for structure, or plain JS).
*   **Fields:**
    1.  **Currency:** HTML `<select>` dropdown.
    2.  **Warning Limit:** HTML `<input type="number">`. Label includes currency symbol.
    3.  **Upper Limit:** HTML `<input type="number">`.
    4.  **Automatic Refresh Interval:** HTML `<select>` dropdown.
*   **Behavior & Logic:** Similar to macOS version, but UI updates and data persistence involve IPC to the Main process to save to `electron-store`. When dialog opens, Main process sends current settings to Renderer. On save, Renderer sends new settings to Main.

**4.6. Currency Management (Main Process)**

*   **Supported Currencies, Base Currency, Exchange Rate API, Caching, Failure Handling, Fallback Rates:** All logic is identical to the macOS spec, but implemented in Node.js in the Main process. Exchange rates stored in `electron-store`.

**4.7. User Notifications (Main Process)**

*   **Framework:** Electron's `Notification` API (provides native notifications cross-platform).
*   **Triggers, Content (Vibey), Frequency Logic:** Identical to macOS spec.

**4.8. Launch at Login (Main Process)**

*   Use Electron's `app.setLoginItemSettings({ openAtLogin: true/false })`.

**5. Data Storage Summary (Main Process)**

*   **Secure Credential Storage (e.g., `node-keytar`):**
    *   `WorkosCursorSessionToken` (String).
*   **Application Settings (e.g., `electron-store`):**
    *   `selectedCurrencyCode` (String).
    *   `warningLimitUSD` (Double).
    *   `upperLimitUSD` (Double).
    *   `teamId` (Int).
    *   `teamName` (String).
    *   `userEmail` (String).
    *   `cachedExchangeRates` (Object: `{[key: string]: number}`).
    *   `lastExchangeRateFetchTimestamp` (Number - e.g., `Date.now()`).
    *   `refreshIntervalMinutes` (Int, default 5).
    *   `launchAtLoginEnabled` (Bool).

**6. Error Handling & Edge Cases**

*   Logic is generally the same as the macOS spec, with UI feedback managed via tray tooltips/titles and context menu updates, all driven by the Main process. Logging to main process console.

**7. UI/UX Considerations**

*   Aim for a consistent feel across platforms, while respecting native conventions for tray icons and context menus. Web UI for Settings should be clean and responsive.

**8. Technical Implementation Details (Electron Specific)**

*   **Core Framework:** Electron (latest stable).
*   **Language:** JavaScript/TypeScript for both Main and Renderer processes.
*   **Main Process Logic:** Node.js APIs, Electron APIs.
*   **Renderer Process UI:** HTML, CSS, JavaScript. (Consider a lightweight UI framework like Svelte, Vue, or Preact if preferred over vanilla JS, or even React if the team is comfortable).
*   **Inter-Process Communication (IPC):** `ipcMain` and `ipcRenderer` for communication between Main and Renderer processes (e.g., for settings, triggering actions).
*   **System Tray/Menu Bar:** Electron `Tray` API.
*   **Packaging & Distribution:** Use `electron-builder` or `electron-forge` for creating installers/packages for macOS, Windows, and Linux.
*   **Security:** Be mindful of Electron security best practices (e.g., `contextIsolation`, `sandbox`, limiting Node.js integration in renderers where not needed). For the login `<webview>`, ensure `nodeIntegration` is off.
*   **Testing:**
    *   **Unit Tests (Main Process):** Jest or Mocha/Chai for Node.js modules (API clients, services). Mock external dependencies.
    *   **Unit Tests (Renderer Process):** Jest (with JSDOM) or framework-specific testing tools for UI components/logic.
    *   **End-to-End Tests:** Spectron or Playwright for Electron to test application flows.
*   **Dependencies (Examples):** `axios`/`node-fetch`, `electron-store`, `node-keytar`, `electron-log` (for more robust logging if needed beyond console).

**9. Assumptions & Dependencies**

*   Same as macOS spec regarding Cursor API stability and Exchange Rate API.
*   User has a desktop environment capable of running Electron apps.