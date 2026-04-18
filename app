# YouTube Video Transcription App - Complete Code

## Everything you need to recreate this app

---

### 📋 STEP 1: Create these files in your project

---

## FILE 1: package.json
```json
{
  "name": "youtube-transcription-app",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "db:push": "drizzle-kit push",
    "db:studio": "drizzle-kit studio"
  },
  "dependencies": {
    "next": "15.1.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "drizzle-orm": "^0.33.0",
    "postgres": "^3.4.4",
    "youtube-transcript": "^1.2.1",
    "react-icons": "^5.3.0"
  },
  "devDependencies": {
    "@types/node": "^22",
    "@types/react": "^19",
    "@types/react-dom": "^19",
    "typescript": "^5",
    "tailwindcss": "^3.4.14",
    "postcss": "^8",
    "eslint": "^9",
    "eslint-config-next": "15.1.0",
    "drizzle-kit": "^0.24.2"
  }
}
```

---

## FILE 2: .env.example
```env
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/youtube_transcriber?sslmode=disable"
```

---

## FILE 3: drizzle.config.ts
```typescript
import { defineConfig } from 'drizzle-kit';

export default defineConfig({
  schema: './src/db/schema.ts',
  dialect: 'postgresql',
  dbCredentials: {
    url: process.env.DATABASE_URL!,
  },
});
```

---

## FILE 4: src/db/schema.ts
```typescript
import { pgTable, serial, text, timestamp, varchar } from 'drizzle-orm/pg-core';

export const transcriptions = pgTable('transcriptions', {
  id: serial('id').primaryKey(),
  videoId: varchar('video_id', { length: 255 }).notNull(),
  videoTitle: text('video_title'),
  thumbnailUrl: text('thumbnail_url'),
  transcript: text('transcript').notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export type Transcription = typeof transcriptions.$inferSelect;
```

---

## FILE 5: src/db/index.ts
```typescript
import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';

const client = postgres(process.env.DATABASE_URL!);
export const db = drizzle(client);
```

---

## FILE 6: src/app/api/transcribe/route.ts
```typescript
import { NextResponse } from 'next/server';
import { YoutubeTranscript } from 'youtube-transcript';
import { db } from '@/db';
import { transcriptions } from '@/db/schema';

export async function POST(request: Request) {
  try {
    const { videoId, videoTitle, thumbnailUrl } = await request.json();

    if (!videoId) {
      return NextResponse.json(
        { error: 'Video ID is required' },
        { status: 400 }
      );
    }

    const transcript = await YoutubeTranscript.fetchTranscript(videoId);

    const formattedTranscript = transcript
      .map((item) => {
        const minutes = Math.floor(item.offset / 60);
        const seconds = Math.floor(item.offset % 60);
        const timestamp = `[${minutes}:${seconds.toString().padStart(2, '0')}]`;
        return `${timestamp} ${item.text}`;
      })
      .join('\n');

    await db.insert(transcriptions).values({
      videoId,
      videoTitle,
      thumbnailUrl,
      transcript: formattedTranscript,
    });

    return NextResponse.json({
      success: true,
      transcript: formattedTranscript,
      transcriptArray: transcript,
    });
  } catch (error) {
    console.error('Transcription error:', error);
    return NextResponse.json(
      { error: 'Failed to fetch transcript. Make sure the video has captions available.' },
      { status: 500 }
    );
  }
}

export async function GET() {
  try {
    const history = await db
      .select()
      .from(transcriptions)
      .orderBy(transcriptions.createdAt)
      .limit(10);

    return NextResponse.json({ success: true, history });
  } catch (error) {
    console.error('Fetch history error:', error);
    return NextResponse.json(
      { error: 'Failed to fetch history' },
      { status: 500 }
    );
  }
}
```

---

## FILE 7: src/app/page.tsx
```typescript
'use client';

import { useState } from 'react';
import { FaYoutube, FaCopy, FaDownload, FaHistory, FaSpinner, FaTrash } from 'react-icons/fa';

interface Transcription {
  id: number;
  videoId: string;
  videoTitle: string | null;
  thumbnailUrl: string | null;
  transcript: string;
  createdAt: string;
}

export default function Home() {
  const [url, setUrl] = useState('');
  const [loading, setLoading] = useState(false);
  const [transcript, setTranscript] = useState('');
  const [videoInfo, setVideoInfo] = useState<{ title: string; thumbnail: string; videoId: string } | null>(null);
  const [error, setError] = useState('');
  const [history, setHistory] = useState<Transcription[]>([]);
  const [showHistory, setShowHistory] = useState(false);
  const [copied, setCopied] = useState(false);

  const extractVideoId = (url: string): string | null => {
    const patterns = [
      /(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([^&\n?#]+)/,
    ];
    for (const pattern of patterns) {
      const match = url.match(pattern);
      if (match) return match[1];
    }
    return null;
  };

  const handleTranscribe = async () => {
    setLoading(true);
    setError('');
    setTranscript('');

    const videoId = extractVideoId(url);
    if (!videoId) {
      setError('Please enter a valid YouTube URL');
      setLoading(false);
      return;
    }

    const thumbnail = `https://img.youtube.com/vi/${videoId}/maxresdefault.jpg`;
    const title = `YouTube Video (${videoId})`;
    setVideoInfo({ title, thumbnail, videoId });

    try {
      const response = await fetch('/api/transcribe', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ videoId, videoTitle: title, thumbnailUrl: thumbnail }),
      });

      const data = await response.json();
      if (!response.ok) throw new Error(data.error);

      setTranscript(data.transcript);
    } catch (err: any) {
      setError(err.message || 'Failed to transcribe video');
    } finally {
      setLoading(false);
    }
  };

  const loadHistory = async () => {
    try {
      const response = await fetch('/api/transcribe');
      const data = await response.json();
      if (data.success) {
        setHistory(data.history);
      }
    } catch (err) {
      console.error('Failed to load history');
    }
  };

  const copyToClipboard = () => {
    navigator.clipboard.writeText(transcript);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const downloadTranscript = () => {
    const blob = new Blob([transcript], { type: 'text/plain' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `transcript-${videoInfo?.videoId || 'video'}.txt`;
    a.click();
  };

  const toggleHistory = () => {
    setShowHistory(!showHistory);
    if (!showHistory) loadHistory();
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900">
      <div className="container mx-auto px-4 py-8 max-w-4xl">
        {/* Header */}
        <div className="text-center mb-10">
          <div className="flex items-center justify-center gap-3 mb-4">
            <FaYoutube className="text-red-600 text-5xl" />
            <h1 className="text-4xl font-bold text-white">
              YouTube Transcriber
            </h1>
          </div>
          <p className="text-gray-400 text-lg">
            Extract transcripts from any YouTube video with captions
          </p>
        </div>

        {/* Input Section */}
        <div className="bg-gray-800 rounded-2xl p-6 shadow-xl mb-8">
          <div className="flex gap-3">
            <input
              type="text"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              onKeyPress={(e) => e.key === 'Enter' && handleTranscribe()}
              placeholder="Paste YouTube URL here..."
              className="flex-1 px-5 py-4 rounded-xl bg-gray-700 text-white placeholder-gray-400 border border-gray-600 focus:border-red-500 focus:outline-none focus:ring-2 focus:ring-red-500/20 transition-all"
            />
            <button
              onClick={handleTranscribe}
              disabled={loading}
              className="px-8 py-4 bg-red-600 hover:bg-red-700 disabled:bg-red-800 disabled:cursor-not-allowed text-white font-semibold rounded-xl transition-all flex items-center gap-2"
            >
              {loading ? <FaSpinner className="animate-spin" /> : 'Transcribe'}
            </button>
            <button
              onClick={toggleHistory}
              className="px-4 py-4 bg-gray-700 hover:bg-gray-600 text-white rounded-xl transition-all"
              title="Show History"
            >
              <FaHistory />
            </button>
          </div>
          {error && (
            <p className="mt-4 text-red-400 text-center">{error}</p>
          )}
        </div>

        {/* History Panel */}
        {showHistory && (
          <div className="bg-gray-800 rounded-2xl p-6 shadow-xl mb-8">
            <h2 className="text-xl font-semibold text-white mb-4">Recent Transcriptions</h2>
            {history.length === 0 ? (
              <p className="text-gray-400">No history yet</p>
            ) : (
              <div className="space-y-3 max-h-64 overflow-y-auto">
                {history.map((item) => (
                  <div
                    key={item.id}
                    className="flex items-center gap-4 p-3 bg-gray-700 rounded-lg cursor-pointer hover:bg-gray-600 transition-all"
                    onClick={() => {
                      setTranscript(item.transcript);
                      setVideoInfo({
                        title: item.videoTitle || 'Unknown',
                        thumbnail: item.thumbnailUrl || '',
                        videoId: item.videoId,
                      });
                    }}
                  >
                    {item.thumbnailUrl && (
                      <img
                        src={item.thumbnailUrl}
                        alt="thumbnail"
                        className="w-16 h-10 object-cover rounded"
                      />
                    )}
                    <div className="flex-1 overflow-hidden">
                      <p className="text-white truncate">{item.videoTitle}</p>
                      <p className="text-gray-400 text-sm">
                        {new Date(item.createdAt).toLocaleDateString()}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* Video Info */}
        {videoInfo && (
          <div className="bg-gray-800 rounded-2xl p-6 shadow-xl mb-8">
            <div className="flex gap-4 items-start">
              {videoInfo.thumbnail && (
                <img
                  src={videoInfo.thumbnail}
                  alt="Video thumbnail"
                  className="w-48 rounded-lg shadow-lg"
                />
              )}
              <div className="flex-1">
                <h2 className="text-xl font-semibold text-white mb-2">
                  {videoInfo.title}
                </h2>
                <p className="text-gray-400">Video ID: {videoInfo.videoId}</p>
              </div>
            </div>
          </div>
        )}

        {/* Transcript Output */}
        {transcript && (
          <div className="bg-gray-800 rounded-2xl p-6 shadow-xl">
            <div className="flex justify-between items-center mb-4">
              <h2 className="text-xl font-semibold text-white">Transcript</h2>
              <div className="flex gap-2">
                <button
                  onClick={copyToClipboard}
                  className="flex items-center gap-2 px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition-all"
                >
                  <FaCopy />
                  {copied ? 'Copied!' : 'Copy'}
                </button>
                <button
                  onClick={downloadTranscript}
                  className="flex items-center gap-2 px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg transition-all"
                >
                  <FaDownload />
                  Download
                </button>
              </div>
            </div>
            <div className="bg-gray-900 rounded-xl p-4 max-h-96 overflow-y-auto">
              <pre className="text-gray-300 whitespace-pre-wrap font-mono text-sm leading-relaxed">
                {transcript}
              </pre>
            </div>
          </div>
        )}

        {/* Footer */}
        <div className="text-center mt-12 text-gray-500 text-sm">
          <p>Note: Only works with videos that have captions enabled</p>
        </div>
      </div>
    </div>
  );
}
```

---

## FILE 8: src/app/layout.tsx
```typescript
import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import './globals.css';

const inter = Inter({ subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'YouTube Transcriber',
  description: 'Extract transcripts from YouTube videos',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={inter.className}>{children}</body>
    </html>
  );
}
```

---

## FILE 9: src/app/globals.css
```css
@tailwind base;
@tailwind components;
@tailwind utilities;

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  min-height: 100vh;
}
```

---

## FILE 10: tailwind.config.ts
```typescript
import type { Config } from 'tailwindcss';

export default {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {},
  },
  plugins: [],
} satisfies Config;
```

---

## FILE 11: tsconfig.json
```json
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [
      {
        "name": "next"
      }
    ],
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

---

## FILE 12: next.config.ts
```typescript
import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  /* config options here */
};

export default nextConfig;
```

---

## FILE 13: postcss.config.js
```js
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
```

---

## 🚀 HOW TO USE THIS CODE

### Option 1: Quick Setup
1. Create a new Next.js project:
   ```bash
   npx create-next-app@latest youtube-transcriber
   ```
2. Replace the files in your new project with the code above
3. Install dependencies:
   ```bash
   npm install youtube-transcript react-icons drizzle-orm postgres
   npm install -D drizzle-kit
   ```
4. Set up your `.env` file with DATABASE_URL
5. Push schema: `npx drizzle-kit push`
6. Run: `npm run dev`

### Option 2: No Database (Simpler!)
If you don't want to use PostgreSQL, just:
1. Remove all database code from the API route and page
2. The transcription functionality will still work perfectly!
3. Only history feature will be disabled

---

## ✨ FEATURES INCLUDED

- ✅ YouTube URL input with validation
- ✅ Video thumbnail display
- ✅ Transcript extraction with timestamps
- ✅ Copy transcript to clipboard
- ✅ Download transcript as text file
- ✅ Transcription history (with PostgreSQL)
- ✅ Beautiful dark UI with gradient
- ✅ Responsive design

---

## 📝 NOTES

- The app uses `youtube-transcript` library to extract captions
- Only works with videos that have captions enabled
- For production deployment to Vercel, use Neon or Supabase for PostgreSQL
- No YouTube API key required - works via web scraping of captions
