import express from 'express';
import session from 'express-session';
import expressWs from 'express-ws';
import { createServer } from 'http';
import { setupFileAPI } from './file-api.js';

const PORT = process.env.PORT || 3000;
const DEBUG = process.env.DEBUG === 'true';

// Create Express app and HTTP server
const app = express();
const server = createServer(app);

// Initialize WebSocket support
expressWs(app, server);

// Middleware
app.use(express.json({ limit: '10mb' }));
app.use(session({
  resave: false,
  saveUninitialized: true,
  secret: 'sauce'
}));

// Setup file management API
setupFileAPI(app, DEBUG);

// Serve static files from dist
app.use(express.static('dist'));

// Basic WebSocket endpoint (for the drawing app to work)
app.ws('/server', (ws, req) => {
  if (DEBUG) console.log('WebSocket connection established');

  ws.on('message', (msg) => {
    if (DEBUG) console.log('WebSocket message:', msg);
    // Echo back for now - the drawing tool uses this for real-time collaboration
    ws.send(msg);
  });

  ws.on('close', () => {
    if (DEBUG) console.log('WebSocket connection closed');
  });
});

// Start server
server.listen(PORT, () => {
  console.log(`* Server listening on port ${PORT}`);
  if (DEBUG) console.log('* Debug mode enabled');
});
