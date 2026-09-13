'use client';

import { useEffect, useState } from 'react';

export default function Home() {
  const [items, setItems] = useState([]);
  const [name, setName] = useState('');
  const [error, setError] = useState('');

  // Same-origin call: the Application Load Balancer forwards /api/* to the
  // Python backend, so the browser never needs the backend's address.
  async function load() {
    try {
      const res = await fetch('/api/items');
      if (!res.ok) throw new Error('HTTP ' + res.status);
      setItems(await res.json());
      setError('');
    } catch (e) {
      setError('Backend not reachable: ' + e.message);
    }
  }

  async function addItem() {
    if (!name.trim()) return;
    await fetch('/api/items', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name }),
    });
    setName('');
    load();
  }

  useEffect(() => {
    load();
  }, []);

  return (
    <main style={{ maxWidth: 640 }}>
      <h1>AWS DevOps Assessment</h1>
      <p>Next.js frontend &rarr; ALB &rarr; FastAPI backend &rarr; RDS PostgreSQL</p>

      <div style={{ display: 'flex', gap: 8, margin: '24px 0' }}>
        <input
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="New item name"
          style={{ flex: 1, padding: 8 }}
        />
        <button onClick={addItem} style={{ padding: '8px 16px' }}>
          Add
        </button>
      </div>

      {error && <p style={{ color: '#b00' }}>{error}</p>}

      <ul>
        {items.map((it) => (
          <li key={it.id}>
            {it.name} <small style={{ color: '#666' }}>({it.added})</small>
          </li>
        ))}
      </ul>
    </main>
  );
}
