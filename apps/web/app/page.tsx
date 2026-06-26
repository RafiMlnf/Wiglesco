"use client";

import React, { useState, useRef, useEffect } from "react";

interface ProcessResult {
  output_url: string;
  depth_map_url: string;
  thumbnail_url: string;
  processing_time: number;
}

interface HistoryItem {
  id: string;
  filename: string;
  thumbnail_url: string;
  output_url: string;
  depth_map_url: string;
  processing_time: number;
  style: string;
}

const STYLES = ["normal", "nishika", "analog", "cinematic", "glitch", "cyberpunk"];
const STYLE_LABELS: Record<string, string> = {
  normal: "Normal",
  nishika: "Nishika N8000",
  analog: "Analog Film",
  cinematic: "Cinematic",
  glitch: "Glitch",
  cyberpunk: "Cyberpunk",
};

export default function WiggleEditor() {
  const [image, setImage] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [frames, setFrames] = useState(6);
  const [strength, setStrength] = useState(0.6);
  const [style, setStyle] = useState("nishika");
  const [format, setFormat] = useState("mp4");
  const [fps, setFps] = useState(15);
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState("Ready");
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<ProcessResult | null>(null);
  const [tab, setTab] = useState<"original" | "depth" | "output">("original");
  const [history, setHistory] = useState<HistoryItem[]>([]);
  const fileRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    fetch("http://localhost:8000/").catch(() =>
      setError("Backend offline — run uvicorn inside apps/api")
    );
  }, []);

  const onFile = (file: File) => {
    setImage(file);
    setPreview(URL.createObjectURL(file));
    setResult(null);
    setTab("original");
    setError(null);
  };

  const onInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0];
    if (f) onFile(f);
  };

  const onDrop = (e: React.DragEvent) => {
    e.preventDefault();
    const f = e.dataTransfer.files?.[0];
    if (f && f.type.startsWith("image/")) onFile(f);
  };

  const STEPS = ["Uploading...", "Estimating depth...", "Synthesizing frames...", "Applying style...", "Encoding video..."];

  const submit = async () => {
    if (!image) return;
    setLoading(true);
    setError(null);
    let stepIdx = 0;
    setStatus(STEPS[0]);
    const interval = setInterval(() => {
      stepIdx = Math.min(stepIdx + 1, STEPS.length - 1);
      setStatus(STEPS[stepIdx]);
    }, 5000);
    const fd = new FormData();
    fd.append("file", image);
    fd.append("num_frames", frames.toString());
    fd.append("parallax_strength", strength.toString());
    fd.append("effect_style", style);
    fd.append("export_format", format);
    fd.append("fps", fps.toString());
    try {
      const res = await fetch("http://localhost:8000/api/v1/process/direct", { method: "POST", body: fd });
      if (!res.ok) {
        const err = await res.json();
        throw new Error(err.detail || "Processing failed");
      }
      const data: ProcessResult = await res.json();
      setResult(data);
      setTab("output");
      setHistory((prev) => [{
        id: Math.random().toString(36).slice(2, 9),
        filename: image.name,
        thumbnail_url: data.thumbnail_url,
        output_url: data.output_url,
        depth_map_url: data.depth_map_url,
        processing_time: data.processing_time,
        style,
      }, ...prev.slice(0, 9)]);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      clearInterval(interval);
      setLoading(false);
      setStatus("Ready");
    }
  };

  return (
    <div className="app-shell">

      <header className="app-header">
        <div className="header-brand">
          <span className="brand-dot" />
          <span className="brand-name">WiggleAI</span>
          <span className="brand-badge">local</span>
        </div>
        <div className="header-right">
          {error && <span className="header-error">{error}</span>}
          <span className="gpu-pill">
            <span className="gpu-dot" />
            CUDA
          </span>
        </div>
      </header>

      <div className="app-body">

        <aside className="panel-left">
          <div className="section">
            <div className="section-label">Source</div>
            <div
              className={"drop-zone" + (preview ? " has-preview" : "")}
              onClick={() => fileRef.current?.click()}
              onDragOver={(e) => e.preventDefault()}
              onDrop={onDrop}
            >
              {preview
                ? <img src={preview} alt="src" className="drop-preview" />
                : <span className="drop-hint">Click or drag image</span>
              }
            </div>
            <input ref={fileRef} type="file" accept="image/*" className="hidden-input" onChange={onInputChange} />
          </div>

          <div className="divider" />

          <div className="section controls-section">
            <div className="ctrl-row">
              <span className="ctrl-label">Displacement</span>
              <span className="ctrl-value">{strength.toFixed(1)}</span>
            </div>
            <input type="range" min={0.1} max={1.0} step={0.1} value={strength}
              onChange={(e) => setStrength(parseFloat(e.target.value))} className="slider" />

            <div className="ctrl-row" style={{ marginTop: "10px" }}>
              <span className="ctrl-label">Frames</span>
            </div>
            <div className="btn-row">
              {[3, 4, 6, 8].map((f) => (
                <button key={f} onClick={() => setFrames(f)} className={"chip" + (frames === f ? " chip-active" : "")}>
                  {f}
                </button>
              ))}
            </div>

            <div className="ctrl-row" style={{ marginTop: "10px" }}>
              <span className="ctrl-label">Frame Rate</span>
              <span className="ctrl-value">{fps} fps</span>
            </div>
            <input type="range" min={6} max={30} step={1} value={fps}
              onChange={(e) => setFps(parseInt(e.target.value))} className="slider" />

            <div className="ctrl-row" style={{ marginTop: "10px" }}>
              <span className="ctrl-label">Style</span>
            </div>
            <select value={style} onChange={(e) => setStyle(e.target.value)} className="select">
              {STYLES.map((s) => (
                <option key={s} value={s}>{STYLE_LABELS[s]}</option>
              ))}
            </select>

            <div className="ctrl-row" style={{ marginTop: "10px" }}>
              <span className="ctrl-label">Format</span>
            </div>
            <div className="btn-row">
              {["mp4", "gif", "webp"].map((f) => (
                <button key={f} onClick={() => setFormat(f)} className={"chip" + (format === f ? " chip-active" : "")}>
                  {f.toUpperCase()}
                </button>
              ))}
            </div>
          </div>

          <div className="divider" />

          <div className="section">
            <button onClick={submit} disabled={!image || loading}
              className={"btn-render" + (image && !loading ? " btn-render-on" : "")}>
              {loading && <span className="spinner" />}
              {loading ? "Processing" : "Render Parallax"}
            </button>
          </div>
        </aside>

        <main className="panel-center">
          <div className="tab-bar">
            {(["original", "depth", "output"] as const).map((t) => (
              <button key={t} disabled={t !== "original" && !result} onClick={() => setTab(t)}
                className={"tab" + (tab === t ? " tab-active" : "") + (t !== "original" && !result ? " tab-disabled" : "")}>
                {t === "original" ? "Original" : t === "depth" ? "Depth Map" : "3D Parallax"}
              </button>
            ))}
          </div>

          <div className="canvas-area">
            {loading && (
              <div className="loading-overlay">
                <div className="shimmer-bar">
                  <div className="shimmer-fill" />
                </div>
                <span className="loading-text">{status}</span>
              </div>
            )}

            {!preview ? (
              <div className="empty-state">
                <div className="empty-icon">+</div>
                <span>No source selected</span>
              </div>
            ) : (
              <div style={{ width: "100%", height: "100%", display: "flex", alignItems: "center", justifyContent: "center" }}>
                {tab === "original" && <img src={preview} alt="Original" className="canvas-media" />}
                {tab === "depth" && result && <img src={result.depth_map_url} alt="Depth" className="canvas-media" />}
                {tab === "output" && result && (
                  <video key={result.output_url} src={result.output_url} autoPlay loop muted playsInline className="canvas-media" />
                )}
              </div>
            )}
          </div>
        </main>

        <aside className="panel-right">
          <div className="section">
            <div className="section-label">Stats</div>
            <div className="stats-grid">
              <span className="stat-key">Time</span>
              <span className="stat-val">{result ? result.processing_time.toFixed(1) + "s" : "—"}</span>
              <span className="stat-key">Format</span>
              <span className="stat-val">{result ? format.toUpperCase() : "—"}</span>
              <span className="stat-key">Max res</span>
              <span className="stat-val">1280px</span>
              <span className="stat-key">Backend</span>
              <span className="stat-val">CUDA FP16</span>
            </div>
          </div>

          <div className="divider" />

          <div className="section history-section">
            <div className="section-label">
              History <span className="history-count">{history.length}</span>
            </div>
            <div className="history-list">
              {history.length === 0 && <span className="empty-history">No renders yet</span>}
              {history.map((item) => (
                <div key={item.id} className="history-item" onClick={() => {
                  setResult({ output_url: item.output_url, depth_map_url: item.depth_map_url, thumbnail_url: item.thumbnail_url, processing_time: item.processing_time });
                  setTab("output");
                }}>
                  <div className="history-thumb">
                    <img src={item.thumbnail_url} alt="thumb" />
                  </div>
                  <div className="history-meta">
                    <span className="history-name">{item.filename.replace(/\.[^/.]+$/, "")}</span>
                    <span className="history-sub">{item.style} · {item.processing_time.toFixed(1)}s</span>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="divider" />

          {result && (
            <div className="section">
              <a href={result.output_url} download={"wiggle_" + Date.now() + "." + format}
                target="_blank" rel="noreferrer" className="btn-save">
                Save Output
              </a>
            </div>
          )}
        </aside>

      </div>
    </div>
  );
}
