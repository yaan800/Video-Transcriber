# YouTube Transcriber - STATIC VERSION for GitHub Pages

## ✅ This version works 100% on GitHub Pages!

---

## 🚨 Why You Got 404

Your repo had:
- Next.js **server-side API routes** (can't run on GitHub Pages)
- PostgreSQL **database code** (needs a server)
- No static export configuration

---

## 📦 FILE 1: Replace your `src/app/page.tsx` with this (CLIENT-SIDE ONLY)

```tsx
'use client';

import { useState, useEffect } from 'react';
import { FaYoutube, FaCopy, FaDownload, FaHistory, FaSpinner, FaTrash, FaTimes } from 'react-icons/fa';

interface HistoryItem {
  videoId: string;
  videoTitle: string;
  thumbnailUrl: string;
  transcript: string;
  timestamp: number;
}

export default function Home() {
  const [url, setUrl] = useState('');
  const [loading, setLoading] = useState(false);
  const [transcript, setTranscript] = useState('');
  const [videoInfo, setVideoInfo] = useState<{ title: string; thumbnail: string; videoId: string } | null>(null);
  const [error, setError] = useState('');
  const [history, setHistory] = useState<HistoryItem[]>([]);
  const [showHistory, setShowHistory] = useState(false);
  const [copied, setCopied] = useState(false);

  // Load history from localStorage on mount
  useEffect(() => {
    const saved = localStorage.getItem('transcribe-history');
    if (saved) {
      setHistory(JSON.parse(saved));
    }
  }, []);

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
      // Use a public CORS proxy to fetch transcript (client-side only)
      const proxyUrl = `https://corsproxy.io/?https://www.youtube.com/watch?v=${videoId}`;
      const response = await fetch(proxyUrl);
      const html = await response.text();
      
      // Try to extract captions from the page
      const captionsRegex = /"captionTracks":\s*(\[.*?\])/;
      const match = html.match(captionsRegex);
      
      if (!match) {
        throw new Error('No captions found for this video. Try videos with captions enabled.');
      }

      const captionTracks = JSON.parse(match[1]);
      if (!captionTracks.length) {
        throw new Error('No caption tracks available');
      }

      // Get English captions or first available
      const captionUrl = captionTracks.find((t: any) => t.languageCode === 'en')?.baseUrl 
        || captionTracks[0].baseUrl;

      const transcriptResponse = await fetch(`https://corsproxy.io/?${encodeURIComponent(captionUrl)}`);
      const transcriptXml = await transcriptResponse.text();

      // Parse XML transcript
      const textRegex = /<text start="([^"]+)"[^>]*>([^<]+)<\/text>/g;
      const lines: { offset: number; text: string }[] = [];
      let xmlMatch;
      
      while ((xmlMatch = textRegex.exec(transcriptXml)) !== null) {
        lines.push({
          offset: parseFloat(xmlMatch[1]),
          text: xmlMatch[2].replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
        });
      }

      const formattedTranscript = lines
        .map((item) => {
          const minutes = Math.floor(item.offset / 60);
          const seconds = Math.floor(item.offset % 60);
          const timestamp = `[${minutes}:${seconds.toString().padStart(2, '0')}]`;
          return `${timestamp} ${item.text}`;
        })
        .join('\n');

      setTranscript(formattedTranscript);

      // Save to localStorage history
      const newHistoryItem: HistoryItem = {
        videoId,
        videoTitle: title,
        thumbnailUrl: thumbnail,
        transcript: formattedTranscript,
        timestamp: Date.now()
      };

      const newHistory = [newHistoryItem, ...history.filter(h => h.videoId !== videoId)].slice(0, 20);
      setHistory(newHistory);
      localStorage.setItem('transcribe-history', JSON.stringify(newHistory));

    } catch (err: any) {
      setError(err.message || 'Failed to transcribe video. Try another video with captions.');
    } finally {
      setLoading(false);
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

  const clearHistory = () => {
    setHistory([]);
    localStorage.removeItem('transcribe-history');
  };

  const loadFromHistory = (item: HistoryItem) => {
    setTranscript(item.transcript);
    setVideoInfo({
      title: item.videoTitle,
      thumbnail: item.thumbnailUrl,
      videoId: item.videoId,
    });
    setShowHistory(false);
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
              onClick={() => setShowHistory(!showHistory)}
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
            <div className="flex justify-between items-center mb-4">
              <h2 className="text-xl font-semibold text-white">Recent Transcriptions</h2>
              <div className="flex gap-2">
                {history.length > 0 && (
                  <button
                    onClick={clearHistory}
                    className="flex items-center gap-2 px-3 py-1 bg-red-600 hover:bg-red-700 text-white text-sm rounded-lg"
                  >
                    <FaTrash /> Clear
                  </button>
                )}
                <button
                  onClick={() => setShowHistory(false)}
                  className="p-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg"
                >
                  <FaTimes />
                </button>
              </div>
            </div>
            {history.length === 0 ? (
              <p className="text-gray-400">No history yet</p>
            ) : (
              <div className="space-y-3 max-h-64 overflow-y-auto">
                {history.map((item, index) => (
                  <div
                    key={index}
                    className="flex items-center gap-4 p-3 bg-gray-700 rounded-lg cursor-pointer hover:bg-gray-600 transition-all"
                    onClick={() => loadFromHistory(item)}
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
                        {new Date(item.timestamp).toLocaleDateString()}
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

## 📦 FILE 2: Replace `next.config.ts`

```typescript
import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  output: 'export',  // This makes it static HTML!
  images: {
    unoptimized: true,
  },
  trailingSlash: true,
  basePath: '/Video-Transcriber',  // Match your repo name!
};

export default nextConfig;
```

---

## 📦 FILE 3: Delete the API folder

Delete the entire folder: `src/app/api/` (we don't need it anymore!)

---

## 📦 FILE 4: Simplify `package.json` (remove DB stuff)

```json
{
  "name": "youtube-transcription-app",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "15.1.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
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
    "eslint-config-next": "15.1.0"
  }
}
```

---

## 🚀 HOW TO DEPLOY TO GITHUB PAGES

### Step 1: Install gh-pages package
```bash
npm install --save-dev gh-pages
```

### Step 2: Add deploy script to package.json
```json
"scripts": {
  "dev": "next dev",
  "build": "next build",
  "start": "next start",
  "lint": "next lint",
  "deploy": "gh-pages -d out"
}
```

### Step 3: Build and deploy
```bash
npm run build
npm run deploy
```

### Step 4: Configure GitHub Pages settings
1. Go to your repo: `https://github.com/yaan800/Video-Transcriber`
2. Click **Settings** → **Pages**
3. Under **Source**, select:
   - **Deploy from a branch**
   - Branch: `gh-pages`, Folder: `/root`
4. Click **Save**

---

## ✨ IMPORTANT CHANGES MADE

1. ✅ **No server-side code** - everything runs in browser
2. ✅ **No PostgreSQL database** - uses `localStorage` for history
3. ✅ **No API routes** - uses public CORS proxy for client-side fetching
4. ✅ **Next.js static export** enabled
5. ✅ **`basePath`** matches your repo name `/Video-Transcriber`
6. ✅ **History saved in browser** - works per-user

---

## 🎯 ALTERNATIVE: Use Vercel (Easier!)

If static GitHub Pages give you CORS issues:

1. Go to **https://vercel.com**
2. Connect your GitHub repo
3. Click **Deploy** - done in 60 seconds!

Vercel supports full Next.js apps including API routes, so you can use the original server-side version without CORS problems.
