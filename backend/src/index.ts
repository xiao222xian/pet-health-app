import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { consultRouter } from './routes/consult.js';
import { nutritionRouter } from './routes/nutrition.js';

const app = express();
const PORT = process.env.PORT ?? 3000;

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10mb' }));

app.get('/health', (_req, res) => res.json({ status: 'ok' }));
app.use('/api/v1/consult', consultRouter);
app.use('/api/v1/nutrition', nutritionRouter);

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

export default app;
