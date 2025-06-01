"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.settingsWindow = exports.loginWindow = void 0;
exports.createLoginWindow = createLoginWindow;
exports.createSettingsWindow = createSettingsWindow;
exports.sendCurrentSettingsToRenderer = sendCurrentSettingsToRenderer;
const electron_1 = require("electron");
const path_1 = __importDefault(require("path"));
const keytar_1 = __importDefault(require("keytar"));
const store_1 = require("./store");
const api_1 = require("./api");
const notifications_1 = require("./notifications");
exports.loginWindow = null;
exports.settingsWindow = null;
async function checkForSessionCookie(session, url) {
    try {
        const cookies = await session.cookies.get({
            domain: 'cursor.com',
            name: 'WorkosCursorSessionToken',
        });
        if (cookies.length > 0) {
            const token = cookies[0].value;
            console.log('WorkosCursorSessionToken found:', token.substring(0, 20) + '...');
            try {
                await keytar_1.default.setPassword('VibeMeter', 'WorkosCursorSessionToken', token);
                console.log('Token stored securely.');
                store_1.store.set('userEmail', 'Fetching...');
                if (exports.loginWindow) {
                    exports.loginWindow.close();
                }
                // Call /me endpoint and billing endpoint
                await (0, api_1.fetchData)();
                (0, notifications_1.showLoginSuccessNotification)();
            }
            catch (keytarError) {
                console.error('Failed to store session token with keytar:', keytarError);
                electron_1.dialog.showErrorBox('Login Storage Failed', 'Could not securely store your session credentials.');
            }
        }
    }
    catch (cookieError) {
        console.error('Error accessing session token:', cookieError);
    }
}
function createLoginWindow() {
    if (exports.loginWindow) {
        exports.loginWindow.focus();
        return;
    }
    exports.loginWindow = new electron_1.BrowserWindow({
        width: 800,
        height: 600,
        webPreferences: {
            webviewTag: true,
            nodeIntegration: false,
            contextIsolation: true,
            sandbox: true,
        },
    });
    exports.loginWindow.loadFile(path_1.default.join(__dirname, '../../renderer/login.html'));
    exports.loginWindow.on('closed', () => {
        exports.loginWindow = null;
    });
    const session = exports.loginWindow.webContents.session;
    // Monitor URL changes during login
    exports.loginWindow.webContents.on('did-navigate', async (event, url) => {
        console.log('Navigation detected:', url);
        await checkForSessionCookie(session, url);
    });
    exports.loginWindow.webContents.on('did-navigate-in-page', async (event, url) => {
        console.log('In-page navigation detected:', url);
        await checkForSessionCookie(session, url);
    });
    // Also keep the original callback detection as backup
    session.webRequest.onCompleted({ urls: ['https://www.cursor.com/api/auth/callback*'] }, async () => {
        console.log('Login callback detected via webRequest');
        await checkForSessionCookie(session);
    });
}
function createSettingsWindow() {
    if (exports.settingsWindow) {
        exports.settingsWindow.focus();
        return;
    }
    exports.settingsWindow = new electron_1.BrowserWindow({
        width: 900,
        height: 800,
        minWidth: 600,
        minHeight: 700,
        webPreferences: {
            nodeIntegration: false,
            contextIsolation: true,
            sandbox: true,
            preload: path_1.default.join(__dirname, '../preload-settings.js'),
        },
    });
    exports.settingsWindow.loadFile(path_1.default.join(__dirname, '../../renderer/settings.html'));
    exports.settingsWindow.on('closed', () => {
        exports.settingsWindow = null;
    });
    exports.settingsWindow.webContents.on('did-finish-load', () => {
        sendCurrentSettingsToRenderer();
    });
}
function sendCurrentSettingsToRenderer() {
    if (exports.settingsWindow) {
        const settings = {
            selectedCurrencyCode: store_1.store.get('selectedCurrencyCode', 'USD'),
            warningLimitUSD: store_1.store.get('warningLimitUSD', 0),
            upperLimitUSD: store_1.store.get('upperLimitUSD', 0),
            refreshIntervalMinutes: store_1.store.get('refreshIntervalMinutes', 5),
        };
        exports.settingsWindow.webContents.send('load-settings', settings);
    }
}
//# sourceMappingURL=windows.js.map