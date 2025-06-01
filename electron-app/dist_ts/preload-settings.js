"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const electron_1 = require("electron");
const exposedAPI = {
    invokeGetSettings: () => electron_1.ipcRenderer.invoke('get-settings'),
    sendSaveSettings: settings => electron_1.ipcRenderer.send('save-settings', settings),
};
electron_1.contextBridge.exposeInMainWorld('electronAPI', exposedAPI);
//# sourceMappingURL=preload-settings.js.map