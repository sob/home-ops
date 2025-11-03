// File API for server-side storage
// Adds REST endpoints for file management to replace localStorage

import { promises as fs } from 'fs';
import path from 'path';

const FILES_DIR = process.env.FILES_DIR || '/art';

// Ensure files directory exists
async function ensureFilesDir() {
  try {
    await fs.mkdir(FILES_DIR, { recursive: true });
  } catch (err) {
    console.error('Failed to create files directory:', err);
  }
}

// Sanitize filename to prevent directory traversal
function sanitizeFilename(filename) {
  return path.basename(filename).replace(/[^a-zA-Z0-9._-]/g, '_');
}

// Setup file API routes
export function setupFileAPI(app, debug = false) {
  ensureFilesDir();

  const log = (...args) => debug && console.log('[file-api]', ...args);

  // Log configuration on startup
  console.log('[file-api] Server-side file storage enabled');
  console.log('[file-api] Configuration:');
  console.log(`  FILES_DIR: ${FILES_DIR}`);
  console.log(`  DEBUG: ${debug}`);
  console.log(`  TZ: ${process.env.TZ || 'UTC'}`);

  // List all files
  app.get('/api/files', async (req, res) => {
    try {
      const files = await fs.readdir(FILES_DIR);
      const fileList = await Promise.all(
        files
          .filter(f => f.endsWith('.txt') || f.endsWith('.ans') || f.endsWith('.asc'))
          .map(async (filename) => {
            const filepath = path.join(FILES_DIR, filename);
            const stats = await fs.stat(filepath);
            return {
              name: filename,
              size: stats.size,
              modified: stats.mtime.toISOString()
            };
          })
      );
      log(`Listed ${fileList.length} files`);
      res.json({ files: fileList });
    } catch (err) {
      log('Error listing files:', err);
      res.status(500).json({ error: 'Failed to list files' });
    }
  });

  // Load a file
  app.get('/api/files/:filename', async (req, res) => {
    try {
      const filename = sanitizeFilename(req.params.filename);
      const filepath = path.join(FILES_DIR, filename);
      const content = await fs.readFile(filepath, 'utf8');
      log(`Loaded file: ${filename}`);
      res.json({ name: filename, content });
    } catch (err) {
      log(`Error loading file ${req.params.filename}:`, err);
      res.status(404).json({ error: 'File not found' });
    }
  });

  // Save a file
  app.post('/api/files/:filename', async (req, res) => {
    try {
      const filename = sanitizeFilename(req.params.filename);
      const filepath = path.join(FILES_DIR, filename);
      const content = req.body.content || '';

      await fs.writeFile(filepath, content, 'utf8');
      log(`Saved file: ${filename} (${content.length} bytes)`);
      res.json({ success: true, name: filename });
    } catch (err) {
      log(`Error saving file ${req.params.filename}:`, err);
      res.status(500).json({ error: 'Failed to save file' });
    }
  });

  // Delete a file
  app.delete('/api/files/:filename', async (req, res) => {
    try {
      const filename = sanitizeFilename(req.params.filename);
      const filepath = path.join(FILES_DIR, filename);
      await fs.unlink(filepath);
      log(`Deleted file: ${filename}`);
      res.json({ success: true });
    } catch (err) {
      log(`Error deleting file ${req.params.filename}:`, err);
      res.status(404).json({ error: 'File not found' });
    }
  });

  log('File API routes registered');
}
