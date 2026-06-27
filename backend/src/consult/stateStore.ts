import Redis from 'ioredis';

interface StoredValue<T> {
  expiresAt: number;
  value: T;
}

export interface ConsultSessionState {
  session_id: string;
  pet_id: string;
  user_id: string;
  state: string;
  updated_at: string;
  trace_id?: string;
  last_response_type?: string;
  last_risk_level?: string;
}

export interface ConsultStateStore {
  mode: 'redis' | 'memory';
  get<T>(key: string): Promise<T | null>;
  set<T>(key: string, value: T, ttlSeconds: number): Promise<void>;
  appendEvent(sessionId: string, event: unknown, ttlSeconds: number): Promise<void>;
  getEvents(sessionId: string): Promise<unknown[]>;
  setSession(state: ConsultSessionState, ttlSeconds: number): Promise<void>;
}

class MemoryConsultStateStore implements ConsultStateStore {
  mode: 'memory' = 'memory';
  private values = new Map<string, StoredValue<unknown>>();
  private events = new Map<string, StoredValue<unknown[]>>();

  async get<T>(key: string): Promise<T | null> {
    const item = this.values.get(key);
    if (!item || item.expiresAt < Date.now()) {
      this.values.delete(key);
      return null;
    }
    return item.value as T;
  }

  async set<T>(key: string, value: T, ttlSeconds: number): Promise<void> {
    this.values.set(key, {
      value,
      expiresAt: Date.now() + ttlSeconds * 1000,
    });
  }

  async appendEvent(sessionId: string, event: unknown, ttlSeconds: number): Promise<void> {
    const key = eventKey(sessionId);
    const current = await this.getEvents(sessionId);
    current.push(event);
    this.events.set(key, {
      value: current.slice(-100),
      expiresAt: Date.now() + ttlSeconds * 1000,
    });
  }

  async getEvents(sessionId: string): Promise<unknown[]> {
    const item = this.events.get(eventKey(sessionId));
    if (!item || item.expiresAt < Date.now()) {
      this.events.delete(eventKey(sessionId));
      return [];
    }
    return [...item.value];
  }

  async setSession(state: ConsultSessionState, ttlSeconds: number): Promise<void> {
    await this.set(sessionKey(state.session_id), state, ttlSeconds);
  }
}

class RedisConsultStateStore implements ConsultStateStore {
  mode: 'redis' = 'redis';
  constructor(private readonly client: Redis) {}

  async get<T>(key: string): Promise<T | null> {
    const raw = await this.client.get(key);
    return raw ? JSON.parse(raw) as T : null;
  }

  async set<T>(key: string, value: T, ttlSeconds: number): Promise<void> {
    await this.client.set(key, JSON.stringify(value), 'EX', ttlSeconds);
  }

  async appendEvent(sessionId: string, event: unknown, ttlSeconds: number): Promise<void> {
    const key = eventKey(sessionId);
    await this.client
      .multi()
      .rpush(key, JSON.stringify(event))
      .ltrim(key, -100, -1)
      .expire(key, ttlSeconds)
      .exec();
  }

  async getEvents(sessionId: string): Promise<unknown[]> {
    const rows = await this.client.lrange(eventKey(sessionId), 0, -1);
    return rows.map((row) => JSON.parse(row));
  }

  async setSession(state: ConsultSessionState, ttlSeconds: number): Promise<void> {
    await this.set(sessionKey(state.session_id), state, ttlSeconds);
  }
}

class FallbackConsultStateStore implements ConsultStateStore {
  mode: 'redis' | 'memory' = 'redis';
  constructor(
    private readonly primary: ConsultStateStore,
    private readonly fallback: ConsultStateStore,
  ) {}

  async get<T>(key: string): Promise<T | null> {
    if (this.mode === 'memory') return this.fallback.get<T>(key);
    try {
      return await this.primary.get<T>(key);
    } catch (error) {
      this.switchToMemory(error);
      return this.fallback.get<T>(key);
    }
  }

  async set<T>(key: string, value: T, ttlSeconds: number): Promise<void> {
    if (this.mode === 'memory') return this.fallback.set(key, value, ttlSeconds);
    try {
      await this.primary.set(key, value, ttlSeconds);
    } catch (error) {
      this.switchToMemory(error);
      await this.fallback.set(key, value, ttlSeconds);
    }
  }

  async appendEvent(sessionId: string, event: unknown, ttlSeconds: number): Promise<void> {
    if (this.mode === 'memory') return this.fallback.appendEvent(sessionId, event, ttlSeconds);
    try {
      await this.primary.appendEvent(sessionId, event, ttlSeconds);
    } catch (error) {
      this.switchToMemory(error);
      await this.fallback.appendEvent(sessionId, event, ttlSeconds);
    }
  }

  async getEvents(sessionId: string): Promise<unknown[]> {
    if (this.mode === 'memory') return this.fallback.getEvents(sessionId);
    try {
      return await this.primary.getEvents(sessionId);
    } catch (error) {
      this.switchToMemory(error);
      return this.fallback.getEvents(sessionId);
    }
  }

  async setSession(state: ConsultSessionState, ttlSeconds: number): Promise<void> {
    if (this.mode === 'memory') return this.fallback.setSession(state, ttlSeconds);
    try {
      await this.primary.setSession(state, ttlSeconds);
    } catch (error) {
      this.switchToMemory(error);
      await this.fallback.setSession(state, ttlSeconds);
    }
  }

  private switchToMemory(error: unknown) {
    this.mode = 'memory';
    const message = error instanceof Error ? error.message : String(error);
    console.warn('consult state store falling back to memory', message);
  }
}

let store: ConsultStateStore | null = null;

export function getConsultStateStore(): ConsultStateStore {
  if (store) return store;
  if (process.env.NODE_ENV === 'test' || !process.env.REDIS_URL) {
    store = new MemoryConsultStateStore();
    return store;
  }

  const client = new Redis(process.env.REDIS_URL, {
    maxRetriesPerRequest: 1,
  });
  client.on('error', (error) => {
    console.warn('consult redis error', error.message);
  });
  store = new FallbackConsultStateStore(new RedisConsultStateStore(client), new MemoryConsultStateStore());
  return store;
}

export function resetConsultStateStoreForTests(nextStore?: ConsultStateStore) {
  store = nextStore ?? null;
}

export function sessionKey(sessionId: string) {
  return `consult:session:${sessionId}`;
}

function eventKey(sessionId: string) {
  return `consult:events:${sessionId}`;
}
