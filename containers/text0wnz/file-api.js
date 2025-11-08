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

// Sanitize filename to prevent directory traversal while allowing subdirectories
function sanitizeFilename(filename) {
  // Normalize path and prevent ".." traversal
  const normalized = path.normalize(filename).replace(/^(\.\.[\/\\])+/, '');
  // Ensure path doesn't escape FILES_DIR
  const fullPath = path.join(FILES_DIR, normalized);
  if (!fullPath.startsWith(FILES_DIR)) {
    throw new Error('Invalid file path');
  }
  return normalized;
}

// Recursively find all art files in subdirectories
async function findArtFiles(dir, baseDir = dir) {
  const fileList = [];
  
  try {
    const entries = await fs.readdir(dir, { withFileTypes: true });
    
    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      
      if (entry.isDirectory()) {
        // Recursively scan subdirectories
        const subFiles = await findArtFiles(fullPath, baseDir);
        fileList.push(...subFiles);
      } else if (entry.isFile()) {
        // Check if file has a valid extension
        if (entry.name.endsWith('.txt') || entry.name.endsWith('.ans') || entry.name.endsWith('.asc')) {
          const stats = await fs.stat(fullPath);
          // Store relative path from base directory
          const relativePath = path.relative(baseDir, fullPath);
          fileList.push({
            name: relativePath,
            size: stats.size,
            modified: stats.mtime.toISOString()
          });
        }
      }
    }
  } catch (err) {
    console.error(`Error scanning directory ${dir}:`, err);
  }
  
  return fileList;
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

  // List all files (recursively)
  app.get('/api/files', async (req, res) => {
    try {
      const fileList = await findArtFiles(FILES_DIR);
      log(`Listed ${fileList.length} files`);
      res.json({ files: fileList });
    } catch (err) {
      log('Error listing files:', err);
      res.status(500).json({ error: 'Failed to list files' });
    }
  });

  // Load a file
  app.get(/^\/api\/files\/(.+)/, async (req, res) => {
    try {
      // Extract filename from regex capture group
      const filename = req.params[0];
      const sanitized = sanitizeFilename(filename);
      const filepath = path.join(FILES_DIR, sanitized);
      const content = await fs.readFile(filepath, 'utf8');
      log(`Loaded file: ${sanitized}`);
      res.json({ name: sanitized, content });
    } catch (err) {
      log(`Error loading file ${req.path}:`, err);
      res.status(404).json({ error: 'File not found' });
    }
  });

  // Save a file
  app.post(/^\/api\/files\/(.+)/, async (req, res) => {
    try {
      // Extract filename from regex capture group
      const filename = req.params[0];
      const sanitized = sanitizeFilename(filename);
      const filepath = path.join(FILES_DIR, sanitized);
      const content = req.body.content || '';

      // Ensure parent directory exists
      const dir = path.dirname(filepath);
      await fs.mkdir(dir, { recursive: true });

      await fs.writeFile(filepath, content, 'utf8');
      log(`Saved file: ${sanitized} (${content.length} bytes)`);
      res.json({ success: true, name: sanitized });
    } catch (err) {
      log(`Error saving file ${req.path}:`, err);
      res.status(500).json({ error: 'Failed to save file' });
    }
  });

  // Delete a file
  app.delete(/^\/api\/files\/(.+)/, async (req, res) => {
    try {
      // Extract filename from regex capture group
      const filename = req.params[0];
      const sanitized = sanitizeFilename(filename);
      const filepath = path.join(FILES_DIR, sanitized);
      await fs.unlink(filepath);
      log(`Deleted file: ${sanitized}`);
      res.json({ success: true });
    } catch (err) {
      log(`Error deleting file ${req.path}:`, err);
      res.status(404).json({ error: 'File not found' });
    }
  });

  log('File API routes registered');
}
