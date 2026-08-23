import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const SESSIONS = path.join(ROOT, 'docs', 'validation', 'sessions');
const BOARD = path.join(ROOT, 'docs', 'validation', 'board.json');
const BRUSHES = path.join(ROOT, 'docs', 'brushes');

const readBody = (req) =>
  new Promise((resolve, reject) => {
    let raw = '';
    req.on('data', (chunk) => {
      raw += chunk;
      if (raw.length > 8 * 1024 * 1024) reject(new Error('payload too large'));
    });
    req.on('end', () => resolve(raw));
    req.on('error', reject);
  });

const send = (res, code, payload) => {
  res.statusCode = code;
  res.setHeader('Content-Type', 'application/json');
  res.end(JSON.stringify(payload));
};

/** Only [a-z0-9-] survives; keeps a filename from ever escaping the folder. */
const safeSlug = (value, fallback) => {
  const slug = String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60);
  return slug || fallback;
};

/**
 * Writes review sessions and board state straight into the repository so a
 * recorded result needs no copy/paste to reach whoever reads it next.
 */
function studioBridge() {
  return {
    name: 'sarasara-studio-bridge',
    configureServer(server) {
      fs.mkdirSync(SESSIONS, { recursive: true });

      server.middlewares.use('/api/board', async (req, res, next) => {
        try {
          if (req.method === 'GET') {
            if (!fs.existsSync(BOARD)) return send(res, 200, null);
            return send(res, 200, JSON.parse(fs.readFileSync(BOARD, 'utf8')));
          }
          if (req.method === 'PUT') {
            const board = JSON.parse(await readBody(req));
            fs.writeFileSync(BOARD, JSON.stringify(board, null, 2) + '\n');
            return send(res, 200, { ok: true });
          }
          return next();
        } catch (error) {
          return send(res, 500, { error: error.message });
        }
      });

      server.middlewares.use('/api/brushes', async (req, res, next) => {
        try {
          if (req.method === 'GET') {
            const files = fs.existsSync(BRUSHES) ? fs.readdirSync(BRUSHES).filter((f) => f.endsWith('.json')) : [];
            return send(res, 200, files.map((file) => ({
              file,
              ...JSON.parse(fs.readFileSync(path.join(BRUSHES, file), 'utf8')),
            })));
          }
          if (req.method === 'POST') {
            fs.mkdirSync(BRUSHES, { recursive: true });
            const brush = JSON.parse(await readBody(req));
            const name = `${safeSlug(brush.name, 'brush')}.json`;
            const file = path.join(BRUSHES, name);
            if (path.dirname(file) !== BRUSHES) return send(res, 400, { error: 'bad path' });
            fs.writeFileSync(file, JSON.stringify(brush, null, 2) + '\n');
            return send(res, 200, { ok: true, file: `docs/brushes/${name}` });
          }
          return next();
        } catch (error) {
          return send(res, 500, { error: error.message });
        }
      });

      server.middlewares.use('/api/sessions', async (req, res, next) => {
        try {
          if (req.method === 'GET') {
            const files = fs.existsSync(SESSIONS)
              ? fs.readdirSync(SESSIONS).filter((f) => f.endsWith('.json'))
              : [];
            const list = files
              .map((file) => {
                try {
                  const body = JSON.parse(fs.readFileSync(path.join(SESSIONS, file), 'utf8'));
                  return {
                    file,
                    recordedAt: body.recordedAt,
                    material: body.material?.id,
                    substrate: body.substrate?.id,
                    rating: body.review?.rating,
                    decision: body.review?.decision,
                    behavior: body.review?.behavior,
                  };
                } catch {
                  return { file, unreadable: true };
                }
              })
              .sort((a, b) => String(b.recordedAt).localeCompare(String(a.recordedAt)));
            return send(res, 200, list);
          }

          if (req.method === 'POST') {
            const session = JSON.parse(await readBody(req));
            const stamp = String(session.recordedAt || '').replace(/[:.]/g, '-').slice(0, 19) || 'undated';
            const name = `${safeSlug(stamp, 'undated')}-${safeSlug(session.material?.name, 'material')}.json`;
            const file = path.join(SESSIONS, name);
            if (path.dirname(file) !== SESSIONS) return send(res, 400, { error: 'bad path' });
            fs.writeFileSync(file, JSON.stringify(session, null, 2) + '\n');
            return send(res, 200, { ok: true, file: `docs/validation/sessions/${name}` });
          }
          return next();
        } catch (error) {
          return send(res, 500, { error: error.message });
        }
      });
    },
  };
}

export default defineConfig({
  root: 'app',
  plugins: [react(), tailwindcss(), studioBridge()],
  server: {
    port: 5173,
    open: true,
    // Bind to every interface so an iPad on the same Wi-Fi can reach the lab,
    // and accept the hostname a Cloudflare quick tunnel hands out. Note that
    // the bridge below writes to the repository, so anything that can reach
    // this server can write board marks, sessions and brushes.
    host: true,
    allowedHosts: ['.trycloudflare.com'],
  },
  build: { outDir: '../dist', emptyOutDir: true },
});
