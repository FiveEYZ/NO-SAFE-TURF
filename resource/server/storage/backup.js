'use strict';

const fs = require('node:fs/promises');
const path = require('node:path');
const {randomUUID} = require('node:crypto');

class BackupError extends Error {
  constructor() {
    super('Verified pre-wipe backup unavailable');
    this.code = 'BACKUP_UNAVAILABLE';
  }
}

async function syncDirectory(directory) {
  // Windows does not support opening a directory for fsync through Node.
  if (process.platform === 'win32') return;
  const handle = await fs.open(directory, 'r');
  try { await handle.sync(); } finally { await handle.close(); }
}

function createBackupWriter(resourceRoot, directoryName) {
  if (!directoryName) return null;
  if (!/^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$/.test(directoryName) ||
      ['client', 'server', 'shared', 'web', 'node_modules'].includes(directoryName.toLowerCase())) {
    throw new BackupError();
  }
  const directory = path.join(resourceRoot, directoryName);

  return async archive => {
    const filename = `${archive.root}-${randomUUID()}.backup.json`;
    const pending = path.join(directory, `${filename}.pending`);
    const destination = path.join(directory, filename);
    let created = false;
    try {
      try { await fs.mkdir(directory, {mode: 0o700}); }
      catch (error) { if (error?.code !== 'EEXIST') throw error; }
      if (!(await fs.lstat(directory)).isDirectory()) throw new BackupError();

      const bytes = Buffer.from(JSON.stringify(archive), 'utf8');
      const file = await fs.open(pending, 'wx', 0o600);
      created = true;
      try {
        await file.writeFile(bytes);
        await file.sync();
      } finally { await file.close(); }

      await fs.rename(pending, destination);
      created = false;
      if (!(await fs.readFile(destination)).equals(bytes)) throw new BackupError();
      await syncDirectory(directory);
      await syncDirectory(resourceRoot);
      return filename;
    } catch {
      if (created) await fs.unlink(pending).catch(() => {});
      throw new BackupError();
    }
  };
}

module.exports = {BackupError, createBackupWriter};
