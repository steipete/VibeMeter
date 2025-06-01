"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.logOut = logOut;
const keytar_1 = __importDefault(require("keytar"));
const store_1 = require("./store");
async function logOut() {
    console.log('Logging out...');
    try {
        await keytar_1.default.deletePassword('VibeMeter', 'WorkosCursorSessionToken');
    }
    catch (error) {
        console.error('Failed to delete token from keytar (it might not exist):', error);
    }
    store_1.store.delete('userEmail');
    store_1.store.delete('teamId');
    store_1.store.delete('teamName');
    store_1.store.delete('currentSpendingUSD');
    console.log('User data cleared from store.');
    // updateTray will be called from main.ts or api.ts
}
//# sourceMappingURL=auth.js.map