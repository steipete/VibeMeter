// Define the structure of the API exposed by the preload script
// This should match or be compatible with the ElectronAPI interface in preload-settings.ts
interface ExposedElectronAPI {
  invokeGetSettings: () => Promise<{
    selectedCurrencyCode: string;
    warningLimitUSD: number;
    upperLimitUSD: number;
    refreshIntervalMinutes: number;
  }>;
  sendSaveSettings: (settings: {
    selectedCurrencyCode: string;
    warningLimitUSD: number;
    upperLimitUSD: number;
    refreshIntervalMinutes: number;
  }) => void;
}

// Extend the Window interface to include electronAPI
declare global {
  interface Window {
    electronAPI?: ExposedElectronAPI;
  }
}

export const _ = (() => {
  interface SettingsFormState {
    selectedCurrencyCode: string;
    warningLimitUSD: string; // Stored as string from input value
    upperLimitUSD: string; // Stored as string from input value
    refreshIntervalMinutes: string; // Stored as string from input value
  }

  let initialSettingsState: SettingsFormState | null = null;

  // Declare variables for DOM elements, to be assigned in DOMContentLoaded
  let errorDiv: HTMLDivElement | null = null;
  let successDiv: HTMLDivElement | null = null;
  let saveButton: HTMLButtonElement | null = null;
  let currencySelect: HTMLSelectElement | null = null;
  let warningLimitInput: HTMLInputElement | null = null;
  let upperLimitInput: HTMLInputElement | null = null;
  let refreshIntervalSelect: HTMLSelectElement | null = null;

  function getElementById<T extends HTMLElement>(id: string): T | null {
    return document.getElementById(id) as T | null;
  }

  function clearMessages(): void {
    if (errorDiv) errorDiv.style.display = 'none';
    if (successDiv) successDiv.style.display = 'none';
  }

  function showErrorMessage(message: string): void {
    clearMessages();
    if (errorDiv) {
      const messageText = errorDiv.querySelector('.message-text');
      if (messageText) {
        messageText.textContent = message;
      } else {
        errorDiv.textContent = message; // Fallback for old structure
      }
      errorDiv.style.display = 'flex';
    }
  }

  function showSuccessMessage(message: string): void {
    clearMessages();
    if (successDiv) {
      const messageText = successDiv.querySelector('.message-text');
      if (messageText) {
        messageText.textContent = message;
      } else {
        successDiv.textContent = message; // Fallback for old structure
      }
      successDiv.style.display = 'flex';
      setTimeout(clearMessages, 3000); // Clear after 3 seconds
    }
  }

  function getCurrentFormState(): SettingsFormState | null {
    if (!currencySelect || !warningLimitInput || !upperLimitInput || !refreshIntervalSelect) {
      return null;
    }
    return {
      selectedCurrencyCode: currencySelect.value,
      warningLimitUSD: warningLimitInput.value,
      upperLimitUSD: upperLimitInput.value,
      refreshIntervalMinutes: refreshIntervalSelect.value,
    };
  }

  function checkFormDirtyState(): void {
    if (!saveButton || !initialSettingsState) return;

    const currentFormState = getCurrentFormState();
    if (!currentFormState) {
      saveButton.disabled = true; // Can't determine state, disable save
      return;
    }

    const isDirty =
      currentFormState.selectedCurrencyCode !== initialSettingsState.selectedCurrencyCode ||
      currentFormState.warningLimitUSD !== initialSettingsState.warningLimitUSD ||
      currentFormState.upperLimitUSD !== initialSettingsState.upperLimitUSD ||
      currentFormState.refreshIntervalMinutes !== initialSettingsState.refreshIntervalMinutes;

    saveButton.disabled = !isDirty;
  }

  function loadSettings(): void {
    clearMessages();
    if (saveButton) saveButton.disabled = true; // Disable save button initially

    if (window.electronAPI && typeof window.electronAPI.invokeGetSettings === 'function') {
      window.electronAPI
        .invokeGetSettings()
        .then(
          (
            settings: {
              selectedCurrencyCode: string;
              warningLimitUSD: number;
              upperLimitUSD: number;
              refreshIntervalMinutes: number;
            } | null
          ) => {
            if (settings) {
              if (currencySelect) currencySelect.value = settings.selectedCurrencyCode || 'USD';
              if (warningLimitInput)
                warningLimitInput.value = String(settings.warningLimitUSD || 0);
              if (upperLimitInput) upperLimitInput.value = String(settings.upperLimitUSD || 0);
              if (refreshIntervalSelect)
                refreshIntervalSelect.value = String(settings.refreshIntervalMinutes || 5);

              initialSettingsState = getCurrentFormState();
              checkFormDirtyState();
            }
          }
        )
        .catch((err: Error) => {
          console.error('Error loading settings via electronAPI:', err);
          showErrorMessage('Error loading settings. Please try again.');
        });
    } else {
      console.error('electronAPI.invokeGetSettings is not available. Cannot load settings.');
      showErrorMessage(
        'Critical error: Cannot communicate with the main process to load settings.'
      );
    }
  }

  function saveSettings(): void {
    clearMessages();
    const currentFormState = getCurrentFormState();
    if (!currentFormState) {
      console.error('One or more settings form elements not found for saving.');
      showErrorMessage('Error saving settings: Form elements missing.');
      return;
    }

    const settingsToSave = {
      selectedCurrencyCode: currentFormState.selectedCurrencyCode,
      warningLimitUSD: parseFloat(currentFormState.warningLimitUSD) || 0,
      upperLimitUSD: parseFloat(currentFormState.upperLimitUSD) || 0,
      refreshIntervalMinutes: parseInt(currentFormState.refreshIntervalMinutes, 10) || 5,
    };

    if (window.electronAPI && typeof window.electronAPI.sendSaveSettings === 'function') {
      window.electronAPI.sendSaveSettings(settingsToSave);
      showSuccessMessage('Settings saved successfully!');
      initialSettingsState = currentFormState;
      if (saveButton) saveButton.disabled = true;
    } else {
      console.error('electronAPI.sendSaveSettings is not available. Cannot save settings.');
      showErrorMessage(
        'Critical error: Cannot communicate with the main process to save settings.'
      );
    }
  }

  document.addEventListener('DOMContentLoaded', () => {
    // Initialize DOM element variables here
    errorDiv = getElementById<HTMLDivElement>('settings-error');
    successDiv = getElementById<HTMLDivElement>('success-message');
    saveButton = getElementById<HTMLButtonElement>('save-settings-btn');
    currencySelect = getElementById<HTMLSelectElement>('currency');
    warningLimitInput = getElementById<HTMLInputElement>('warningLimit');
    upperLimitInput = getElementById<HTMLInputElement>('upperLimit');
    refreshIntervalSelect = getElementById<HTMLSelectElement>('refreshInterval');

    loadSettings();

    if (saveButton) {
      saveButton.addEventListener('click', saveSettings);
    }

    [currencySelect, warningLimitInput, upperLimitInput, refreshIntervalSelect].forEach(element => {
      if (element) {
        element.addEventListener('input', checkFormDirtyState);
        element.addEventListener('change', checkFormDirtyState);
      }
    });
  });
})();
// Export functions if needed for testing or other modules, though this script is meant for settings.html
// For Jest testing via JSDOM, these functions become globally available on `window` if not wrapped in an IIFE or module.
// export { loadSettings, saveSettings };

export {};
