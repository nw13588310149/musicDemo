import { openDB } from 'idb';

const dbPromise = openDB('my-database', 1, {
    upgrade(db) {
        if (!db.objectStoreNames.contains('audioFiles')) {
            db.createObjectStore('audioFiles', { keyPath: 'id' });
        }
    },
});

export async function addAudio(id, audioBlob) {
    const db = await dbPromise;
    await db.put('audioFiles', { id, audioBlob });
}

export async function getAudio(id) {
    const db = await dbPromise;
    const result = await db.get('audioFiles', id);
    return result ? result.audioBlob : null;
}

export async function getAllAudioIds() {
    const db = await dbPromise;
    const tx = db.transaction('audioFiles', 'readonly');
    const store = tx.objectStore('audioFiles');
    const allKeys = await store.getAllKeys();
    await tx.done;
    return allKeys;
}
