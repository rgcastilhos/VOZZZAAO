import express from 'express';
import pino from 'pino';
import pinoHttp from 'pino-http';
import { intentRouter } from './routes/intent';

const logger = pino({ level: 'info' });
const app = express();
const PORT = 5000;

app.use(pinoHttp({ logger }));
app.use(express.json());

app.get('/', (_req, res) => {
  res.json({
    name: 'VozComando Intent API',
    version: '1.0.0',
    endpoints: [
      { method: 'POST', path: '/api/intent', description: 'Parse a voice command into a structured intent' }
    ]
  });
});

app.use(intentRouter);

app.use((err: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  logger.error(err);
  res.status(500).json({ error: 'internal_server_error' });
});

app.listen(PORT, '0.0.0.0', () => {
  logger.info(`VozComando API running on port ${PORT}`);
});
