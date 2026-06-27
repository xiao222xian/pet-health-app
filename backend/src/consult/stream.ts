import { Response } from 'express';
import { ConsultEvent } from './contract.js';

export function setupSse(res: Response) {
  res.status(200);
  res.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
  res.setHeader('Cache-Control', 'no-cache, no-transform');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders?.();
}

export function writeSse(res: Response, event: ConsultEvent) {
  if (res.writableEnded || res.destroyed) return;
  try {
    res.write(`event: ${event.event}\n`);
    res.write(`data: ${JSON.stringify(event.data)}\n\n`);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.warn('failed to write sse event', message);
  }
}

export function writeSseError(res: Response, code: string, message: string) {
  writeSse(res, { event: 'error', data: { code, message } });
  writeSse(res, { event: 'done', data: { ok: false } });
  if (!res.writableEnded && !res.destroyed) res.end();
}
