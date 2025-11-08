// Storage adapter to replace localStorage with server API
// Injected into the built application to provide server-side storage

(function() {
  'use strict';

  const API_BASE = '/api/files';

  // Server-backed storage implementation
  class ServerStorage {
    constructor() {
      this.cache = new Map();
      this.initialized = false;
    }

    async init() {
      if (this.initialized) return;

      try {
        // Load file list from server
        const response = await fetch(API_BASE);
        if (response.ok) {
          const data = await response.json();
          console.log('[storage-adapter] Initialized with', data.files.length, 'files');
        }
        this.initialized = true;
      } catch (err) {
        console.error('[storage-adapter] Initialization failed:', err);
      }
    }

    async getItem(key) {
      // Check if this is a file reference
      if (!key.startsWith('text0wnz_')) {
        return localStorage.getItem(key);
      }

      try {
        const filename = this.keyToFilename(key);
        const response = await fetch(`${API_BASE}/${filename}`);

        if (!response.ok) {
          return null;
        }

        const data = await response.json();
        return data.content;
      } catch (err) {
        console.error('[storage-adapter] Failed to get item:', key, err);
        return null;
      }
    }

    async setItem(key, value) {
      // Non-file keys still use localStorage
      if (!key.startsWith('text0wnz_')) {
        return localStorage.setItem(key, value);
      }

      try {
        const filename = this.keyToFilename(key);
        const response = await fetch(`${API_BASE}/${filename}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ content: value })
        });

        if (!response.ok) {
          throw new Error('Save failed');
        }

        console.log('[storage-adapter] Saved:', filename);
      } catch (err) {
        console.error('[storage-adapter] Failed to save item:', key, err);
        throw err;
      }
    }

    async removeItem(key) {
      if (!key.startsWith('text0wnz_')) {
        return localStorage.removeItem(key);
      }

      try {
        const filename = this.keyToFilename(key);
        await fetch(`${API_BASE}/${filename}`, { method: 'DELETE' });
      } catch (err) {
        console.error('[storage-adapter] Failed to delete item:', key, err);
      }
    }

    async listFiles() {
      try {
        const response = await fetch(API_BASE);
        if (!response.ok) return [];

        const data = await response.json();
        return data.files;
      } catch (err) {
        console.error('[storage-adapter] Failed to list files:', err);
        return [];
      }
    }

    keyToFilename(key) {
      // Convert storage key to filename
      // text0wnz_myart -> myart.txt
      const name = key.replace('text0wnz_', '');
      return name.endsWith('.txt') || name.endsWith('.ans') ? name : `${name}.txt`;
    }
  }

  // Create global instance
  window.serverStorage = new ServerStorage();
  window.serverStorage.init();

  // Create modal dialog for file operations
  function createFileDialog() {
    const dialog = document.createElement('div');
    dialog.id = 'server-file-dialog';
    dialog.innerHTML = `
      <div class="server-dialog-overlay">
        <div class="server-dialog-content">
          <div class="server-dialog-header">
            <h2 id="server-dialog-title">Server Files</h2>
            <button class="server-dialog-close">&times;</button>
          </div>
          <div class="server-dialog-body">
            <div id="server-file-list"></div>
            <div id="server-save-form" style="display: none;">
              <input type="text" id="server-filename-input" placeholder="Enter filename (e.g., myart.ans)" />
            </div>
          </div>
          <div class="server-dialog-footer">
            <button id="server-dialog-ok" class="server-btn-primary">OK</button>
            <button id="server-dialog-cancel" class="server-btn-secondary">Cancel</button>
          </div>
        </div>
      </div>
    `;

    // Add CSS
    const style = document.createElement('style');
    style.textContent = `
      #server-file-dialog { display: none; }
      #server-file-dialog.show { display: block; }
      .server-dialog-overlay {
        position: fixed; top: 0; left: 0; right: 0; bottom: 0;
        background: rgba(0,0,0,0.8); z-index: 10000;
        display: flex; align-items: center; justify-content: center;
      }
      .server-dialog-content {
        background: #2a2a2a; border: 2px solid #555;
        border-radius: 4px; min-width: 400px; max-width: 600px;
        max-height: 80vh; display: flex; flex-direction: column;
      }
      .server-dialog-header {
        padding: 15px 20px; border-bottom: 1px solid #555;
        display: flex; justify-content: space-between; align-items: center;
      }
      .server-dialog-header h2 {
        margin: 0; color: #fff; font-size: 18px;
      }
      .server-dialog-close {
        background: none; border: none; color: #aaa;
        font-size: 24px; cursor: pointer; padding: 0;
        width: 30px; height: 30px; line-height: 1;
      }
      .server-dialog-close:hover { color: #fff; }
      .server-dialog-body {
        padding: 20px; overflow-y: auto; flex: 1;
      }
      #server-file-list {
        list-style: none; padding: 0; margin: 0;
      }
      .server-file-item {
        padding: 10px; margin: 5px 0; background: #333;
        border: 1px solid #555; cursor: pointer;
        display: flex; justify-content: space-between;
        align-items: center;
      }
      .server-file-item:hover { background: #444; }
      .server-file-item.selected { background: #0066cc; border-color: #0088ff; }
      .server-file-name { color: #fff; }
      .server-file-meta { color: #aaa; font-size: 12px; }
      .server-file-actions {
        display: flex; gap: 5px;
      }
      .server-file-actions button {
        padding: 4px 8px; font-size: 11px;
        background: #555; border: 1px solid #666;
        color: #fff; cursor: pointer; border-radius: 3px;
      }
      .server-file-actions button:hover { background: #666; }
      #server-filename-input {
        width: 100%; padding: 10px; background: #333;
        border: 1px solid #555; color: #fff; font-size: 14px;
      }
      .server-dialog-footer {
        padding: 15px 20px; border-top: 1px solid #555;
        display: flex; justify-content: flex-end; gap: 10px;
      }
      .server-btn-primary, .server-btn-secondary {
        padding: 8px 20px; border: none; cursor: pointer;
        font-size: 14px; border-radius: 3px;
      }
      .server-btn-primary {
        background: #0066cc; color: #fff;
      }
      .server-btn-primary:hover { background: #0077dd; }
      .server-btn-secondary {
        background: #555; color: #fff;
      }
      .server-btn-secondary:hover { background: #666; }
    `;

    document.head.appendChild(style);
    document.body.appendChild(dialog);

    return dialog;
  }

  // Show file browser dialog
  async function showOpenDialog() {
    const dialog = document.getElementById('server-file-dialog') || createFileDialog();
    const title = dialog.querySelector('#server-dialog-title');
    const fileList = dialog.querySelector('#server-file-list');
    const saveForm = dialog.querySelector('#server-save-form');
    const okBtn = dialog.querySelector('#server-dialog-ok');
    const cancelBtn = dialog.querySelector('#server-dialog-cancel');
    const closeBtn = dialog.querySelector('.server-dialog-close');

    title.textContent = 'Open File from Server';
    saveForm.style.display = 'none';
    fileList.style.display = 'block';

    // Get files from server
    const files = await window.serverStorage.listFiles();

    if (files.length === 0) {
      fileList.innerHTML = '<p style="color: #aaa;">No files found on server</p>';
    } else {
      fileList.innerHTML = files.map(f => `
        <div class="server-file-item" data-filename="${f.name}">
          <div>
            <div class="server-file-name">${f.name}</div>
            <div class="server-file-meta">${(f.size / 1024).toFixed(1)} KB - ${new Date(f.modified).toLocaleString()}</div>
          </div>
          <div class="server-file-actions">
            <button class="download-btn" data-filename="${f.name}">Download</button>
          </div>
        </div>
      `).join('');

      // Handle file selection
      fileList.querySelectorAll('.server-file-item').forEach(item => {
        item.addEventListener('click', (e) => {
          if (e.target.classList.contains('download-btn')) return;
          fileList.querySelectorAll('.server-file-item').forEach(i => i.classList.remove('selected'));
          item.classList.add('selected');
        });
        item.addEventListener('dblclick', () => okBtn.click());
      });

      // Handle download buttons
      fileList.querySelectorAll('.download-btn').forEach(btn => {
        btn.addEventListener('click', async (e) => {
          e.stopPropagation();
          const filename = btn.dataset.filename;
          await downloadFile(filename);
        });
      });
    }

    dialog.classList.add('show');

    return new Promise((resolve) => {
      const cleanup = () => {
        dialog.classList.remove('show');
        okBtn.onclick = null;
        cancelBtn.onclick = null;
        closeBtn.onclick = null;
      };

      okBtn.onclick = () => {
        const selected = fileList.querySelector('.server-file-item.selected');
        cleanup();
        resolve(selected ? selected.dataset.filename : null);
      };

      cancelBtn.onclick = closeBtn.onclick = () => {
        cleanup();
        resolve(null);
      };
    });
  }

  // Show save dialog
  async function showSaveDialog(defaultName = '') {
    const dialog = document.getElementById('server-file-dialog') || createFileDialog();
    const title = dialog.querySelector('#server-dialog-title');
    const fileList = dialog.querySelector('#server-file-list');
    const saveForm = dialog.querySelector('#server-save-form');
    const filenameInput = dialog.querySelector('#server-filename-input');
    const okBtn = dialog.querySelector('#server-dialog-ok');
    const cancelBtn = dialog.querySelector('#server-dialog-cancel');
    const closeBtn = dialog.querySelector('.server-dialog-close');

    title.textContent = 'Save File to Server';
    fileList.style.display = 'none';
    saveForm.style.display = 'block';
    filenameInput.value = defaultName;

    dialog.classList.add('show');
    setTimeout(() => filenameInput.focus(), 100);

    return new Promise((resolve) => {
      const cleanup = () => {
        dialog.classList.remove('show');
        okBtn.onclick = null;
        cancelBtn.onclick = null;
        closeBtn.onclick = null;
        filenameInput.onkeypress = null;
      };

      filenameInput.onkeypress = (e) => {
        if (e.key === 'Enter') okBtn.click();
      };

      okBtn.onclick = () => {
        const filename = filenameInput.value.trim();
        cleanup();
        resolve(filename || null);
      };

      cancelBtn.onclick = closeBtn.onclick = () => {
        cleanup();
        resolve(null);
      };
    });
  }

  // Download file from server to local filesystem
  async function downloadFile(filename) {
    try {
      const response = await fetch(`${API_BASE}/${filename}`);
      if (!response.ok) throw new Error('Failed to load file');

      const data = await response.json();
      const blob = new Blob([data.content], { type: 'text/plain' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      a.click();
      URL.revokeObjectURL(url);
      console.log('[storage-adapter] Downloaded:', filename);
    } catch (err) {
      console.error('[storage-adapter] Download failed:', err);
      alert('Failed to download file: ' + err.message);
    }
  }

  // Intercept file operations
  function setupFileDialog() {
    const openButton = document.querySelector('article#open, #open');
    const fileInput = document.querySelector('#openFile');
    const saveButtons = document.querySelectorAll('article#saveAnsi, article#saveBin, article#saveXbin, #saveAnsi, #saveBin, #saveXbin');

    if (!openButton || !fileInput) {
      console.log('[storage-adapter] File dialog elements not ready, retrying...');
      setTimeout(setupFileDialog, 500);
      return;
    }

    console.log('[storage-adapter] Found elements:', {open: openButton.tagName, input: fileInput.tagName, saves: saveButtons.length});

    // Intercept Open
    openButton.addEventListener('click', async (e) => {
      e.preventDefault();
      e.stopPropagation();

      console.log('[storage-adapter] Open button clicked, showing dialog...');

      const filename = await showOpenDialog();
      if (!filename) {
        console.log('[storage-adapter] No file selected');
        return;
      }

      try {
        const response = await fetch(`${API_BASE}/${filename}`);
        if (!response.ok) throw new Error('Failed to load file');

        const data = await response.json();
        console.log('[storage-adapter] Loaded file:', filename, 'size:', data.content.length);

        // Trigger the app's file load
        const blob = new Blob([data.content], { type: 'text/plain' });
        const file = new File([blob], filename, { type: 'text/plain' });
        const dataTransfer = new DataTransfer();
        dataTransfer.items.add(file);
        fileInput.files = dataTransfer.files;
        fileInput.dispatchEvent(new Event('change', { bubbles: true }));
      } catch (err) {
        console.error('[storage-adapter] Failed to load file:', err);
        alert('Failed to load file: ' + err.message);
      }
    }, true);

    // Intercept Save buttons
    saveButtons.forEach(btn => {
      btn.addEventListener('click', async (e) => {
        e.preventDefault();
        e.stopPropagation();

        const ext = btn.id === 'saveAnsi' ? '.ans' : btn.id === 'saveBin' ? '.bin' : '.xb';
        const filename = await showSaveDialog('artwork' + ext);
        if (!filename) return;

        // Let the app handle the save, we'll intercept the download
        console.log('[storage-adapter] Save to server:', filename);

        // Trigger original save - we'll intercept via localStorage
        btn.click();
      }, true);
    });

    console.log('[storage-adapter] File dialog interceptor installed');
  }

  // Wait for DOM and setup
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', setupFileDialog);
  } else {
    setupFileDialog();
  }

  // Hide unwanted UI elements
  function cleanupUI() {
    // Change window title
    document.title = document.title.replace('[text0wnz]', '[halfduplex.io]');

    // Only hide the menu item and network button - don't mess with modals
    const hideStyle = document.createElement('style');
    hideStyle.textContent = `
      /* Hide Update Editor menu item */
      #update { display: none !important; }

      /* Hide join collaboration button */
      #networkButton { display: none !important; }
    `;
    document.head.appendChild(hideStyle);

    // Remove UI elements
    setTimeout(() => {
      const updateBtn = document.querySelector('#update');
      const networkBtn = document.querySelector('#networkButton');

      if (updateBtn) updateBtn.remove();
      if (networkBtn) networkBtn.remove();
    }, 500);

    console.log('[storage-adapter] UI cleanup applied');
  }

  // Apply UI cleanup
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', cleanupUI);
  } else {
    cleanupUI();
  }

  console.log('[storage-adapter] Server-side storage adapter loaded');
})();
