import { contextBridge, ipcRenderer } from 'electron';

// Define the shape of the API exposed to the renderer process
interface Settings {
  selectedCurrencyCode: string;
  warningLimitUSD: number;
  upperLimitUSD: number;
  refreshIntervalMinutes: number;
}

export interface ElectronAPI {
  invokeGetSettings: () => Promise<Settings>;
  sendSaveSettings: (settings: Settings) => void;
  // If you had a synchronous 'load-settings' listener in the renderer before,
  // it's better to use invoke for request-response patterns like getting settings.
  // If 'load-settings' was purely one-way from main to renderer, the renderer would use ipcRenderer.on directly.
}

const exposedAPI: ElectronAPI = {
  invokeGetSettings: () => ipcRenderer.invoke('get-settings'),
  sendSaveSettings: settings => ipcRenderer.send('save-settings', settings),
};

contextBridge.exposeInMainWorld('electronAPI', exposedAPI);
