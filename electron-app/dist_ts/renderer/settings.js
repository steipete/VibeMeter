"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports._ = void 0;
exports._ = (() => {
    let initialSettingsState = null;
    // Declare variables for DOM elements, to be assigned in DOMContentLoaded
    let errorDiv = null;
    let successDiv = null;
    let saveButton = null;
    let currencySelect = null;
    let warningLimitInput = null;
    let upperLimitInput = null;
    let refreshIntervalSelect = null;
    function getElementById(id) {
        return document.getElementById(id);
    }
    function clearMessages() {
        if (errorDiv)
            errorDiv.style.display = 'none';
        if (successDiv)
            successDiv.style.display = 'none';
    }
    function showErrorMessage(message) {
        clearMessages();
        if (errorDiv) {
            const messageText = errorDiv.querySelector('.message-text');
            if (messageText) {
                messageText.textContent = message;
            }
            else {
                errorDiv.textContent = message; // Fallback for old structure
            }
            errorDiv.style.display = 'flex';
        }
    }
    function showSuccessMessage(message) {
        clearMessages();
        if (successDiv) {
            const messageText = successDiv.querySelector('.message-text');
            if (messageText) {
                messageText.textContent = message;
            }
            else {
                successDiv.textContent = message; // Fallback for old structure
            }
            successDiv.style.display = 'flex';
            setTimeout(clearMessages, 3000); // Clear after 3 seconds
        }
    }
    function getCurrentFormState() {
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
    function checkFormDirtyState() {
        if (!saveButton || !initialSettingsState)
            return;
        const currentFormState = getCurrentFormState();
        if (!currentFormState) {
            saveButton.disabled = true; // Can't determine state, disable save
            return;
        }
        const isDirty = currentFormState.selectedCurrencyCode !== initialSettingsState.selectedCurrencyCode ||
            currentFormState.warningLimitUSD !== initialSettingsState.warningLimitUSD ||
            currentFormState.upperLimitUSD !== initialSettingsState.upperLimitUSD ||
            currentFormState.refreshIntervalMinutes !== initialSettingsState.refreshIntervalMinutes;
        saveButton.disabled = !isDirty;
    }
    function loadSettings() {
        clearMessages();
        if (saveButton)
            saveButton.disabled = true; // Disable save button initially
        if (window.electronAPI && typeof window.electronAPI.invokeGetSettings === 'function') {
            window.electronAPI
                .invokeGetSettings()
                .then((settings) => {
                if (settings) {
                    if (currencySelect)
                        currencySelect.value = settings.selectedCurrencyCode || 'USD';
                    if (warningLimitInput)
                        warningLimitInput.value = String(settings.warningLimitUSD || 0);
                    if (upperLimitInput)
                        upperLimitInput.value = String(settings.upperLimitUSD || 0);
                    if (refreshIntervalSelect)
                        refreshIntervalSelect.value = String(settings.refreshIntervalMinutes || 5);
                    initialSettingsState = getCurrentFormState();
                    checkFormDirtyState();
                }
            })
                .catch((err) => {
                console.error('Error loading settings via electronAPI:', err);
                showErrorMessage('Error loading settings. Please try again.');
            });
        }
        else {
            console.error('electronAPI.invokeGetSettings is not available. Cannot load settings.');
            showErrorMessage('Critical error: Cannot communicate with the main process to load settings.');
        }
    }
    function saveSettings() {
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
            if (saveButton)
                saveButton.disabled = true;
        }
        else {
            console.error('electronAPI.sendSaveSettings is not available. Cannot save settings.');
            showErrorMessage('Critical error: Cannot communicate with the main process to save settings.');
        }
    }
    document.addEventListener('DOMContentLoaded', () => {
        // Initialize DOM element variables here
        errorDiv = getElementById('settings-error');
        successDiv = getElementById('success-message');
        saveButton = getElementById('save-settings-btn');
        currencySelect = getElementById('currency');
        warningLimitInput = getElementById('warningLimit');
        upperLimitInput = getElementById('upperLimit');
        refreshIntervalSelect = getElementById('refreshInterval');
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
//# sourceMappingURL=settings.js.map