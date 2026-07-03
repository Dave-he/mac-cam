import express from 'express';
import cors from 'cors';
import multer from 'multer';
import sqlite3 from 'sqlite3';
import path from 'path';
import fs from 'fs';

const app = express();
const port = 3000;

// Setup database
const db = new sqlite3.Database('events.db');
db.serialize(() => {
  db.run(`CREATE TABLE IF NOT EXISTS events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    filename TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);
});

// Setup multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = 'uploads';
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir);
    }
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    cb(null, file.originalname);
  }
});
const upload = multer({ storage });

app.use(cors());
app.use(express.json());

// Serve static files (the uploaded videos)
app.use('/videos', express.static(path.join(__dirname, '../uploads')));

// API: Upload video event
app.post('/api/upload', upload.single('video'), (req, res) => {
  if (!req.file) {
    return res.status(400).send('No file uploaded.');
  }

  const filename = req.file.filename;
  console.log(`Received upload: ${filename}`);

  db.run(`INSERT INTO events (filename) VALUES (?)`, [filename], function(err) {
    if (err) {
      console.error(err.message);
      return res.status(500).send('Database error');
    }
    res.status(200).json({ message: 'Upload successful', id: this.lastID });
  });
});

// API: List events
app.get('/api/events', (req, res) => {
  db.all(`SELECT * FROM events ORDER BY timestamp DESC`, [], (err, rows) => {
    if (err) {
      return res.status(500).send('Database error');
    }
    res.json(rows);
  });
});

app.listen(port, () => {
  console.log(`Central Server running at http://localhost:${port}`);
});
