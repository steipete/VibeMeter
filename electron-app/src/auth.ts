import keytar from 'keytar';
import { store } from './store';

export async function logOut(): Promise<void> {
  console.log('Logging out...');
  try {
    await keytar.deletePassword('VibeMeter', 'WorkosCursorSessionToken');
  } catch (error) {
    console.error('Failed to delete token from keytar (it might not exist):', error);
  }
  store.delete('userEmail');
  store.delete('teamId');
  store.delete('teamName');
  store.delete('currentSpendingUSD');
  console.log('User data cleared from store.');
  // updateTray will be called from main.ts or api.ts
}
