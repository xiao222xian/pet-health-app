import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { consultRouter } from './routes/consult.js';
import { nutritionRouter } from './routes/nutrition.js';
import { authRouter } from './routes/auth.js';
import { petsRouter } from './routes/pets.js';

const app = express();
const PORT = process.env.PORT ?? 3000;

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10mb' }));

app.get('/health', (_req, res) => res.json({ status: 'ok' }));
app.use('/api/v1/auth', authRouter);
app.use('/api/v1/pets', petsRouter);
app.use('/api/v1/consult', consultRouter);
app.use('/api/v1/nutrition', nutritionRouter);

if (process.env.NODE_ENV !== 'test') {
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
}

export default app;
