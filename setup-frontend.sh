#!/bin/bash

# Create Next.js app
npx create-next-app@latest frontend --typescript --tailwind --eslint --app --no-src-dir --use-npm

cd frontend

# Install axios
npm install axios

# Create directories
mkdir -p components lib types app/submit app/status

# Create files with content

# types/index.ts
cat > types/index.ts << 'EOF'
export interface ReportSubmission {
  category: string;
  description: string;
  file?: File | null;
}

export interface ReportResponse {
  token: string;
  credibility_score: number;
  summary: string;
  category: string;
}

export interface ReportStatus {
  token: string;
  category: string;
  description: string;
  credibility_score: number;
  summary: string;
  created_at: string;
  status: string;
}
EOF

# lib/api.ts
cat > lib/api.ts << 'EOF'
import axios from 'axios';
import { ReportSubmission, ReportResponse, ReportStatus } from '@/types';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000';

const api = axios.create({
  baseURL: API_URL,
  headers: {
    'Content-Type': 'multipart/form-data',
  },
});

export const submitReport = async (data: ReportSubmission): Promise<ReportResponse> => {
  const formData = new FormData();
  formData.append('category', data.category);
  formData.append('description', data.description);
  
  if (data.file) {
    formData.append('file', data.file);
  }

  const response = await api.post('/submit-report', formData);
  return response.data;
};

export const getReportStatus = async (token: string): Promise<ReportStatus> => {
  const response = await axios.get(`${API_URL}/report/${token}`);
  return response.data;
};
EOF

# lib/utils.ts
cat > lib/utils.ts << 'EOF'
export const formatDate = (dateString: string): string => {
  return new Date(dateString).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });
};

export const getCredibilityColor = (score: number): string => {
  if (score >= 70) return '#22c55e';
  if (score >= 40) return '#eab308';
  return '#ef4444';
};

export const getCategoryLabel = (category: string): string => {
  const labels: Record<string, string> = {
    bribery: 'Bribery / Extortion',
    fraud: 'Fraud / Embezzlement',
    harassment: 'Workplace Harassment',
    environmental: 'Environmental Violation',
    discrimination: 'Discrimination',
    other: 'Other Illegal Activity'
  };
  return labels[category] || category;
};
EOF

# components/Loading.tsx
cat > components/Loading.tsx << 'EOF'
'use client';

export default function Loading() {
  return (
    <div className="loading">
      <div className="spinner"></div>
      <p>Analyzing report with AI...</p>
      
      <style jsx>{\`
        .loading {
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          padding: 40px;
        }
        .spinner {
          width: 40px;
          height: 40px;
          border: 4px solid #e5e7eb;
          border-top: 4px solid #3b82f6;
          border-radius: 50%;
          animation: spin 1s linear infinite;
          margin-bottom: 16px;
        }
        @keyframes spin {
          0% { transform: rotate(0deg); }
          100% { transform: rotate(360deg); }
        }
        p {
          color: #6b7280;
          font-size: 14px;
        }
      \`}</style>
    </div>
  );
}
EOF

# components/ReportForm.tsx
cat > components/ReportForm.tsx << 'EOF'
'use client';

import { useState } from 'react';
import { ReportSubmission } from '@/types';
import { submitReport } from '@/lib/api';

interface ReportFormProps {
  onSuccess: (data: any) => void;
}

export default function ReportForm({ onSuccess }: ReportFormProps) {
  const [category, setCategory] = useState('');
  const [description, setDescription] = useState('');
  const [file, setFile] = useState<File | null>(null);
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setSubmitting(true);

    try {
      const result = await submitReport({
        category,
        description,
        file
      });
      onSuccess(result);
    } catch (err) {
      setError('Failed to submit report. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="report-form">
      <div className="field">
        <label htmlFor="category">Type of Incident *</label>
        <select
          id="category"
          value={category}
          onChange={(e) => setCategory(e.target.value)}
          required
        >
          <option value="">Select category</option>
          <option value="bribery">Bribery / Extortion</option>
          <option value="fraud">Fraud / Embezzlement</option>
          <option value="harassment">Workplace Harassment</option>
          <option value="environmental">Environmental Violation</option>
          <option value="discrimination">Discrimination</option>
          <option value="other">Other Illegal Activity</option>
        </select>
      </div>

      <div className="field">
        <label htmlFor="description">Description *</label>
        <textarea
          id="description"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder="Describe what happened in detail..."
          rows={6}
          required
        />
      </div>

      <div className="field">
        <label htmlFor="file">Evidence (optional)</label>
        <input
          id="file"
          type="file"
          onChange={(e) => setFile(e.target.files?.[0] || null)}
          accept="image/*,audio/*,video/*,.pdf,.doc,.docx"
        />
        <small>Supported: Images, audio, video, PDF, Word</small>
      </div>

      {error && <div className="error">{error}</div>}

      <button type="submit" disabled={submitting}>
        {submitting ? 'Submitting...' : 'Submit Report Securely'}
      </button>

      <style jsx>{\`
        .report-form {
          display: flex;
          flex-direction: column;
          gap: 20px;
        }
        .field {
          display: flex;
          flex-direction: column;
          gap: 6px;
        }
        label {
          font-weight: 500;
          font-size: 14px;
          color: #374151;
        }
        select, textarea, input[type="file"] {
          padding: 10px;
          border: 1px solid #d1d5db;
          border-radius: 6px;
          font-size: 14px;
        }
        textarea {
          resize: vertical;
          font-family: inherit;
        }
        small {
          font-size: 12px;
          color: #6b7280;
        }
        button {
          background: #2563eb;
          color: white;
          padding: 12px 24px;
          border: none;
          border-radius: 6px;
          font-size: 16px;
          cursor: pointer;
          font-weight: 500;
        }
        button:hover:not(:disabled) {
          background: #1d4ed8;
        }
        button:disabled {
          opacity: 0.6;
          cursor: not-allowed;
        }
        .error {
          color: #dc2626;
          font-size: 14px;
          padding: 10px;
          background: #fee2e2;
          border-radius: 6px;
        }
      \`}</style>
    </form>
  );
}
EOF

# components/ReportResult.tsx
cat > components/ReportResult.tsx << 'EOF'
'use client';

import { ReportResponse } from '@/types';
import { getCredibilityColor, getCategoryLabel } from '@/lib/utils';

interface ReportResultProps {
  data: ReportResponse;
  onNewReport: () => void;
}

export default function ReportResult({ data, onNewReport }: ReportResultProps) {
  const scoreColor = getCredibilityColor(data.credibility_score);

  const copyToken = () => {
    navigator.clipboard.writeText(data.token);
    alert('Token copied to clipboard!');
  };

  return (
    <div className="result">
      <h2>Report Submitted Successfully</h2>
      
      <div className="token-section">
        <p className="label">Your Case Token (save this!)</p>
        <div className="token" onClick={copyToken} title="Click to copy">
          {data.token}
        </div>
        <p className="hint">Click to copy. You'll need this to check status.</p>
      </div>

      <div className="stats">
        <div className="stat">
          <span className="stat-label">Credibility Score</span>
          <span className="stat-value" style={{ color: scoreColor }}>
            {data.credibility_score}/100
          </span>
        </div>
        <div className="stat">
          <span className="stat-label">Category</span>
          <span className="stat-value">{getCategoryLabel(data.category)}</span>
        </div>
      </div>

      <div className="ai-summary">
        <h3>AI Analysis</h3>
        <p>{data.summary}</p>
      </div>

      <button onClick={onNewReport} className="new-report-btn">
        Submit Another Report
      </button>

      <style jsx>{\`
        .result {
          padding: 20px;
        }
        h2 {
          margin-bottom: 20px;
          color: #111827;
        }
        .token-section {
          background: #f3f4f6;
          padding: 16px;
          border-radius: 8px;
          margin-bottom: 20px;
          text-align: center;
        }
        .label {
          font-size: 12px;
          color: #6b7280;
          text-transform: uppercase;
          letter-spacing: 0.05em;
          margin-bottom: 8px;
        }
        .token {
          font-family: monospace;
          font-size: 24px;
          font-weight: bold;
          color: #2563eb;
          cursor: pointer;
          padding: 8px;
          background: white;
          border-radius: 4px;
          border: 2px dashed #d1d5db;
        }
        .hint {
          font-size: 12px;
          color: #6b7280;
          margin-top: 8px;
        }
        .stats {
          display: grid;
          grid-template-columns: 1fr 1fr;
          gap: 16px;
          margin-bottom: 20px;
        }
        .stat {
          background: white;
          padding: 16px;
          border-radius: 8px;
          border: 1px solid #e5e7eb;
        }
        .stat-label {
          display: block;
          font-size: 12px;
          color: #6b7280;
          margin-bottom: 4px;
        }
        .stat-value {
          display: block;
          font-size: 20px;
          font-weight: 600;
        }
        .ai-summary {
          background: #eff6ff;
          padding: 16px;
          border-radius: 8px;
          margin-bottom: 20px;
          border-left: 4px solid #3b82f6;
        }
        .ai-summary h3 {
          margin: 0 0 8px 0;
          font-size: 14px;
          color: #1e40af;
        }
        .ai-summary p {
          margin: 0;
          color: #1e3a8a;
          font-size: 14px;
          line-height: 1.5;
        }
        .new-report-btn {
          width: 100%;
          background: #059669;
          color: white;
          padding: 12px;
          border: none;
          border-radius: 6px;
          font-size: 16px;
          cursor: pointer;
        }
        .new-report-btn:hover {
          background: #047857;
        }
      \`}</style>
    </div>
  );
}
EOF

# components/StatusChecker.tsx
cat > components/StatusChecker.tsx << 'EOF'
'use client';

import { useState } from 'react';
import { getReportStatus } from '@/lib/api';
import { ReportStatus } from '@/types';
import { formatDate, getCredibilityColor, getCategoryLabel } from '@/lib/utils';

export default function StatusChecker() {
  const [token, setToken] = useState('');
  const [report, setReport] = useState<ReportStatus | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleCheck = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    setReport(null);

    try {
      const result = await getReportStatus(token);
      setReport(result);
    } catch (err) {
      setError('Report not found. Check your token and try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="status-checker">
      <form onSubmit={handleCheck}>
        <input
          type="text"
          value={token}
          onChange={(e) => setToken(e.target.value.toUpperCase())}
          placeholder="Enter case token (e.g., A1B2C3D4)"
          maxLength={8}
        />
        <button type="submit" disabled={loading || token.length !== 8}>
          {loading ? 'Checking...' : 'Check Status'}
        </button>
      </form>

      {error && <div className="error">{error}</div>}

      {report && (
        <div className="report-details">
          <div className="detail-row">
            <span>Status</span>
            <span className="status-badge">{report.status.replace('_', ' ')}</span>
          </div>
          <div className="detail-row">
            <span>Category</span>
            <span>{getCategoryLabel(report.category)}</span>
          </div>
          <div className="detail-row">
            <span>Submitted</span>
            <span>{formatDate(report.created_at)}</span>
          </div>
          <div className="detail-row">
            <span>Credibility Score</span>
            <span style={{ color: getCredibilityColor(report.credibility_score) }}>
              {report.credibility_score}/100
            </span>
          </div>
          <div className="description">
            <h4>Description</h4>
            <p>{report.description}</p>
          </div>
        </div>
      )}

      <style jsx>{\`
        .status-checker {
          max-width: 500px;
        }
        form {
          display: flex;
          gap: 8px;
          margin-bottom: 20px;
        }
        input {
          flex: 1;
          padding: 10px;
          border: 1px solid #d1d5db;
          border-radius: 6px;
          font-size: 14px;
          text-transform: uppercase;
        }
        button {
          background: #2563eb;
          color: white;
          padding: 10px 20px;
          border: none;
          border-radius: 6px;
          cursor: pointer;
        }
        button:disabled {
          opacity: 0.5;
          cursor: not-allowed;
        }
        .error {
          color: #dc2626;
          padding: 10px;
          background: #fee2e2;
          border-radius: 6px;
          margin-bottom: 16px;
        }
        .report-details {
          background: white;
          border: 1px solid #e5e7eb;
          border-radius: 8px;
          padding: 16px;
        }
        .detail-row {
          display: flex;
          justify-content: space-between;
          padding: 12px 0;
          border-bottom: 1px solid #f3f4f6;
        }
        .detail-row:last-of-type {
          border-bottom: none;
        }
        .status-badge {
          background: #fef3c7;
          color: #92400e;
          padding: 4px 12px;
          border-radius: 12px;
          font-size: 12px;
          text-transform: capitalize;
        }
        .description {
          margin-top: 16px;
          padding-top: 16px;
          border-top: 1px solid #e5e7eb;
        }
        .description h4 {
          margin: 0 0 8px 0;
          font-size: 14px;
          color: #6b7280;
        }
        .description p {
          margin: 0;
          color: #374151;
          line-height: 1.5;
        }
      \`}</style>
    </div>
  );
}
EOF

# app/globals.css
cat > app/globals.css << 'EOF'
* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
  background: #f9fafb;
  color: #111827;
  line-height: 1.5;
}

.container {
  max-width: 800px;
  margin: 0 auto;
  padding: 40px 20px;
}

header {
  text-align: center;
  margin-bottom: 40px;
}

header h1 {
  font-size: 32px;
  margin-bottom: 8px;
  color: #111827;
}

header p {
  color: #6b7280;
}

.card {
  background: white;
  border-radius: 12px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.1);
  padding: 24px;
}

nav {
  display: flex;
  gap: 16px;
  justify-content: center;
  margin-bottom: 24px;
}

nav a {
  color: #2563eb;
  text-decoration: none;
  padding: 8px 16px;
  border-radius: 6px;
}

nav a:hover {
  background: #eff6ff;
}
EOF

# app/layout.tsx
cat > app/layout.tsx << 'EOF'
export const metadata = {
  title: 'SafeReport - Anonymous Corruption Reporting',
  description: 'AI-powered platform for reporting corruption and illegal activities',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <div className="container">
          <header>
            <h1>SafeReport</h1>
            <p>Anonymous corruption reporting powered by AI</p>
          </header>
          {children}
        </div>
      </body>
    </html>
  );
}
EOF

# app/page.tsx
cat > app/page.tsx << 'EOF'
import Link from 'next/link';

export default function Home() {
  return (
    <div className="card">
      <nav>
        <Link href="/submit">Submit Report</Link>
        <Link href="/status">Check Status</Link>
      </nav>
      
      <div style={{ textAlign: 'center', padding: '40px 0' }}>
        <h2 style={{ marginBottom: '16px' }}>Welcome to SafeReport</h2>
        <p style={{ color: '#6b7280', marginBottom: '24px' }}>
          Report corruption and illegal activities anonymously. 
          Our AI analyzes submissions to help investigators prioritize credible reports.
        </p>
        <Link 
          href="/submit" 
          style={{
            display: 'inline-block',
            background: '#2563eb',
            color: 'white',
            padding: '12px 32px',
            borderRadius: '6px',
            textDecoration: 'none',
            fontWeight: 500
          }}
        >
          Make a Report
        </Link>
      </div>
    </div>
  );
}
EOF

# app/submit/page.tsx
cat > app/submit/page.tsx << 'EOF'
'use client';

import { useState } from 'react';
import ReportForm from '@/components/ReportForm';
import ReportResult from '@/components/ReportResult';
import Loading from '@/components/Loading';
import { ReportResponse } from '@/types';
import Link from 'next/link';

export default function SubmitPage() {
  const [step, setStep] = useState<'form' | 'loading' | 'result'>('form');
  const [result, setResult] = useState<ReportResponse | null>(null);

  const handleSuccess = (data: ReportResponse) => {
    setResult(data);
    setStep('result');
  };

  const handleNewReport = () => {
    setResult(null);
    setStep('form');
  };

  return (
    <div className="card">
      <div style={{ marginBottom: '20px' }}>
        <Link href="/" style={{ color: '#2563eb', textDecoration: 'none' }}>
          ← Back to home
        </Link>
      </div>

      <h2 style={{ marginBottom: '24px' }}>Submit Anonymous Report</h2>

      {step === 'form' && <ReportForm onSuccess={handleSuccess} />}
      {step === 'loading' && <Loading />}
      {step === 'result' && result && (
        <ReportResult data={result} onNewReport={handleNewReport} />
      )}
    </div>
  );
}
EOF

# app/status/page.tsx
cat > app/status/page.tsx << 'EOF'
import StatusChecker from '@/components/StatusChecker';
import Link from 'next/link';

export default function StatusPage() {
  return (
    <div className="card">
      <div style={{ marginBottom: '20px' }}>
        <Link href="/" style={{ color: '#2563eb', textDecoration: 'none' }}>
          ← Back to home
        </Link>
      </div>

      <h2 style={{ marginBottom: '24px' }}>Check Report Status</h2>
      <p style={{ color: '#6b7280', marginBottom: '24px' }}>
        Enter your case token to view the status of your report.
      </p>

      <StatusChecker />
    </div>
  );
}
EOF

# next.config.js
cat > next.config.js << 'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'export',
  distDir: 'dist',
  images: {
    unoptimized: true
  }
}

module.exports = nextConfig
EOF

# .env.local
cat > .env.local << 'EOF'
NEXT_PUBLIC_API_URL=http://localhost:8000
EOF

echo "✅ Frontend setup complete!"
echo "Run: cd frontend && npm run dev"