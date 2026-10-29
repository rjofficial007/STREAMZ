// data/network/modern_web_html.dart
// ============================================================================
// STREAMZ — Built-in Web Interface HTML (Modern Studio Edition)
// ============================================================================

const String kModernWebInterfaceHtml = r"""
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
<title>STREAMZ // STUDIO</title>
<link href="https://fonts.googleapis.com/css2?family=Manrope:wght@200;300;400;500;600;700;800&display=swap" rel="stylesheet">
<style>
  :root {
    --black: #000000;
    --white: #ffffff;
    --accent: #ffffff;
    --white-dim: rgba(235,240,255,0.04);
    --white-mid: rgba(235,240,255,0.09);
    --white-border: rgba(220,228,245,0.12);
    --white-text: rgba(241,243,248,0.72);
    --white-muted: rgba(190,198,214,0.48);
    --surface: #080a10;
    --surface-2: #10131b;
    --font-display: 'Manrope', sans-serif;
    --font-mono: 'Manrope', sans-serif;
    --font-body: 'Manrope', sans-serif;
    --transition-snap: 0.15s cubic-bezier(0.16, 1, 0.3, 1);
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background: linear-gradient(180deg, #10182a 0%, #060910 8%, #010102 22%, #000000 100%);
    color: var(--white);
    font-family: var(--font-body);
    font-weight: 300;
    overflow: hidden;
    height: 100vh;
    height: 100dvh; /* For modern mobile browsers */
    display: flex;
    flex-direction: column;
    cursor: default;
    -webkit-font-smoothing: antialiased;
  }
  ::-webkit-scrollbar { width: 4px; }
  ::-webkit-scrollbar-track { background: var(--black); }
  ::-webkit-scrollbar-thumb { background: var(--white-border); }
  ::-webkit-scrollbar-thumb:hover { background: var(--white); }

  /* ================== TOP DASHBOARD ================== */
  .top-dashboard {
    display: flex;
    justify-content: space-between;
    align-items: stretch;
    height: 72px;
    border-bottom: 1px solid var(--white-border);
    background: var(--surface);
    z-index: 100;
    flex-shrink: 0;
  }
  .branding {
    padding: 0 30px;
    display: flex;
    align-items: center;
    border-right: 1px solid var(--white-border);
  }
  .brand-title {
    font-family: var(--font-display);
    font-size: 24px;
    font-weight: 500;
    letter-spacing: 0.8px;
    color: var(--white);
    text-transform: uppercase;
  }
  .status-badge {
    background: var(--white);
    color: var(--black);
    padding: 4px 10px;
    font-family: var(--font-mono);
    font-size: 9px;
    font-weight: 500;
    letter-spacing: 0.5px;
    margin-left: 16px;
    white-space: nowrap;
  }
  .nav-switches { display: flex; flex-grow: 1; }
  .nav-btn {
    flex: 1;
    background: transparent;
    border: none;
    border-right: 1px solid var(--white-border);
    color: var(--white-text);
    font-family: var(--font-mono);
    font-size: 11px;
    letter-spacing: 0.5px;
    text-transform: uppercase;
    cursor: crosshair;
    transition: all var(--transition-snap);
    outline: none;
  }
  .nav-btn:hover, .nav-btn:focus { background: var(--white-dim); color: var(--white); }
  .nav-btn.active { background: var(--white); color: var(--black); font-weight: 500; }
  
  .search-container { display: flex; align-items: center; min-width: 300px; background: var(--black); position: relative; }
  .search-box {
    background: transparent;
    border: none;
    color: var(--white);
    font-family: var(--font-mono);
    font-size: 11px;
    letter-spacing: 0.2px;
    width: 100%;
    height: 100%;
    padding: 0 40px;
    outline: none;
    text-transform: uppercase;
  }
  .search-box::placeholder { color: var(--white-muted); }
  .search-box:focus { background: var(--white-dim); }
  .search-icon { position: absolute; left: 16px; font-size: 14px; color: var(--white-muted); }

  /* ================== WORKSPACE & GRID ================== */
  .workspace { display: flex; flex-grow: 1; overflow: hidden; position: relative; }
  .content-area {
    flex-grow: 1;
    padding: 0; /* Edge to edge */
    overflow-y: auto;
    position: relative;
    scroll-behavior: smooth;
  }

  .grid-container {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: 1px;
    background: var(--white-border);
    border: 1px solid var(--white-border);
    border-left: none;
    border-right: none;
  }
  .card {
    background: var(--surface-2);
    position: relative;
    cursor: crosshair;
    aspect-ratio: 1;
    outline: none;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    transition: background var(--transition-snap);
  }
  .card:hover, .card:focus { background: var(--white); }
  .card-poster-wrap {
    width: 100%;
    height: 78%;
    position: relative;
    overflow: hidden;
    border-bottom: 1px solid var(--white-border);
    background: var(--black);
  }
  .card-poster {
    width: 100%;
    height: 100%;
    object-fit: cover;
    filter: opacity(0.5) grayscale(1);
    transition: filter var(--transition-snap), transform 0.8s cubic-bezier(0.16, 1, 0.3, 1);
  }
  .card:hover .card-poster, .card:focus .card-poster {
    filter: opacity(1) grayscale(0);
    transform: scale(1.1);
  }
  .card-info { padding: 0 20px; display: flex; justify-content: space-between; align-items: center; height: 22%; }
  .card-title {
    font-family: var(--font-mono);
    font-size: 10px;
    letter-spacing: 0.2px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    color: var(--white-text);
    text-transform: uppercase;
    flex-grow: 1;
  }
  .card:hover .card-title, .card:focus .card-title { color: var(--black); font-weight: 500; }
  .action-btn {
    color: var(--white-muted);
    text-decoration: none;
    font-family: var(--font-mono);
    font-size: 9px;
    letter-spacing: 0.5px;
    outline: none;
    text-transform: uppercase;
    margin-left: 12px;
    border: 1px solid var(--white-border);
    padding: 4px 8px;
  }
  .card:hover .action-btn, .card:focus .action-btn { color: var(--black); font-weight: bold; border-color: var(--black); }

  /* ================== LIST VIEW ================== */
  .list-container { display: flex; flex-direction: column; border-top: 1px solid var(--white-border); }
  .list-item {
    display: flex;
    align-items: center;
    padding: 20px 32px;
    border-bottom: 1px solid var(--white-border);
    background: transparent;
    cursor: crosshair;
    transition: all var(--transition-snap);
    outline: none;
  }
  .list-item:hover, .list-item:focus { background: var(--white); color: var(--black); }
  .list-index { font-family: var(--font-mono); width: 80px; font-size: 10px; color: var(--white-muted); letter-spacing: 0.5px; }
  .list-item:hover .list-index, .list-item:focus .list-index { color: var(--black); }
  .list-art { width: 40px; height: 40px; object-fit: cover; margin-right: 32px; filter: grayscale(1) opacity(0.5); border: 1px solid var(--white-border); }
  .list-item:hover .list-art { filter: grayscale(0) opacity(1); border-color: var(--black); }
  .list-title { flex-grow: 1; font-family: var(--font-mono); font-size: 13px; font-weight: 400; letter-spacing: 0.2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; text-transform: uppercase; }
  .list-meta { font-family: var(--font-mono); font-size: 10px; width: 140px; text-align: right; margin-right: 48px; color: var(--white-text); letter-spacing: 0.2px; }
  .list-item:hover .list-meta { color: var(--black); }
  .list-download-icon { color: var(--white-text); text-decoration: none; font-family: var(--font-mono); font-size: 10px; letter-spacing: 0.5px; outline: none; text-transform: uppercase; border: 1px solid var(--white-border); padding: 4px 8px; }
  .list-item:hover .list-download-icon { color: var(--black); font-weight: bold; border-color: var(--black); }

  /* ================== PLAYER CONSOLE ================== */
  .player-console {
    height: 100px;
    border-top: 1px solid var(--white-border);
    background: var(--surface);
    display: flex;
    align-items: stretch;
    z-index: 100;
    flex-shrink: 0;
  }
  .now-playing-lcd {
    flex-grow: 1;
    background: transparent;
    border-right: 1px solid var(--white-border);
    padding: 0 40px;
    display: flex;
    align-items: center;
    gap: 40px;
  }
  .lcd-art { width: 64px; height: 64px; border: 1px solid var(--white-border); overflow: hidden; background: var(--black); }
  .lcd-art img { width: 100%; height: 100%; object-fit: cover; filter: grayscale(1); }
  .lcd-data { display: flex; flex-direction: column; justify-content: center; flex-grow: 1; overflow: hidden; }
  .lcd-label { font-family: var(--font-mono); font-size: 9px; letter-spacing: 0.8px; color: var(--white-muted); margin-bottom: 8px; text-transform: uppercase; }
  .lcd-title { font-family: var(--font-display); font-size: 32px; font-weight: 500; color: var(--white); line-height: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; text-transform: uppercase; letter-spacing: 0.2px; }
  .lcd-progress-wrapper { height: 4px; background: rgba(255,255,255,0.1); margin-top: 16px; width: 100%; position: relative; display: none; cursor: crosshair; }
  .lcd-progress-bar { height: 100%; width: 0%; background: var(--white); pointer-events: none; }

  .hardware-controls { display: flex; align-items: stretch; }
  .hw-btn {
    width: 100px;
    background: transparent;
    border: none;
    border-left: 1px solid var(--white-border);
    color: var(--white-text);
    font-family: var(--font-mono);
    font-size: 12px;
    letter-spacing: 0.5px;
    cursor: crosshair;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all var(--transition-snap);
    outline: none;
    text-transform: uppercase;
  }
  .hw-btn:hover, .hw-btn:focus { background: var(--white-dim); color: var(--white); }
  .hw-btn.play { width: 140px; background: var(--white); color: var(--black); font-weight: 500; }
  .hw-btn.play:hover, .hw-btn.play:focus { background: rgba(255,255,255,0.9); }

  /* ================== FULLSCREEN PLAYER ================== */
  .fs-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0,0,0,0.98);
    z-index: 2000;
    display: none;
    align-items: center;
    justify-content: center;
  }
  .fs-overlay.active { display: flex; animation: fadeIn 0.3s cubic-bezier(0.16, 1, 0.3, 1); }
  @keyframes fadeIn { from { opacity: 0; transform: scale(1.05); } to { opacity: 1; transform: scale(1); } }

  .video-container {
    width: 95vw;
    height: 90vh;
    border: 1px solid var(--white-border);
    position: relative;
    background: var(--black);
    overflow: hidden;
  }
  .video-container:fullscreen { width: 100vw; height: 100vh; border: none; }

  .window-controls { position: absolute; top: 0; right: 0; display: flex; z-index: 2001; }
  .window-btn {
    width: 64px;
    height: 64px;
    background: var(--white);
    color: var(--black);
    font-family: var(--font-mono);
    font-size: 16px;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: crosshair;
    border: none;
    outline: none;
    border-left: 1px solid var(--black);
  }
  .window-btn:hover { background: rgba(255,255,255,0.8); }

  video { width: 100%; height: 100%; object-fit: contain; outline: none; cursor: crosshair; }
  img#fs-img { width: 100%; height: 100%; object-fit: contain; }

  .vid-controls-overlay {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: 100px;
    background: linear-gradient(to top, rgba(0,0,0,1), transparent);
    display: flex;
    align-items: center;
    padding: 0 48px;
    gap: 32px;
    opacity: 0;
    transition: opacity 0.4s ease;
    z-index: 2002;
  }
  .video-container:hover .vid-controls-overlay { opacity: 1; }

  .playback-error { position: fixed; inset: 0; z-index: 4000; display: grid; place-items: center; padding: 24px; background: rgba(0,0,0,0.78); }
  .playback-error[hidden] { display: none; }
  .playback-error-card { width: min(100%, 560px); padding: 28px; color: var(--white); background: rgba(16,18,24,0.98); border: 1px solid var(--white-border); border-radius: 18px; box-shadow: 0 24px 80px rgba(0,0,0,0.55); font-family: var(--font-body); }
  .playback-error-kicker { display: block; margin-bottom: 10px; color: var(--white-muted); font-size: 11px; letter-spacing: 1.4px; }
  .playback-error-title { margin: 0 0 12px; font-size: clamp(22px, 3vw, 30px); font-weight: 600; }
  .playback-error-message { margin: 0; color: var(--white-text); font-size: 15px; line-height: 1.55; }
  .playback-error-status { margin-top: 14px; color: var(--white); font-size: 13px; }
  .playback-error-actions { display: flex; flex-wrap: wrap; gap: 12px; margin-top: 24px; }
  .playback-error-actions button { min-height: 46px; padding: 0 18px; border: 1px solid var(--white-border); border-radius: 12px; color: var(--white); background: #151821; font: 600 13px var(--font-body); cursor: pointer; }
  .playback-error-actions button:first-child { color: #05070b; background: var(--white); }
  .playback-error-actions button:focus-visible { outline: 3px solid #8cb2ff; outline-offset: 3px; }

  .empty-state {
    padding: 160px 20px;
    text-align: center;
    color: var(--white-muted);
    font-family: var(--font-mono);
    font-size: 14px;
    letter-spacing: 0.8px;
    text-transform: uppercase;
    border: 1px dashed var(--white-border);
    margin-top: 40px;
  }

  /* ================== BOTTOM NAV (MOBILE) ================== */
  .bottom-navbar {
    display: none;
    height: 60px;
    border-top: 1px solid var(--white-border);
    background: var(--surface);
    z-index: 100;
    flex-shrink: 0;
  }
  .bottom-navbar .nav-btn {
    font-size: 12px;
    font-weight: 500;
  }
  .bottom-navbar .nav-btn:last-child {
    border-right: none;
  }

  /* ================== RESPONSIVE MEDIA QUERIES ================== */
  
  /* Tablet / Smaller Desktop */
  @media (max-width: 1024px) {
    .content-area { padding: 0; }
  }

  /* Mobile Device */
  @media (max-width: 768px) {
    /* Top Bar adjustments */
    .branding { display: none; }
    .nav-switches { display: none; }
    .top-dashboard { height: 56px; }
    .search-container { min-width: 0; flex-grow: 1; }
    
    /* Enable Bottom Navbar */
    .bottom-navbar { display: flex; }
    
    /* Workspace adjustments */
    .content-area { padding: 0; }
    
    /* Request: 4 Grid Items on Mobile */
    .grid-container { grid-template-columns: repeat(4, 1fr); gap: 1px; }
    .card-info { padding: 0 4px; justify-content: center; height: 25%; }
    .card-poster-wrap { height: 75%; }
    .card-title { font-size: 8px; text-align: center; width: 100%; white-space: nowrap; }
    .action-btn { display: none; } /* Hidden to allow 4 items to fit cleanly */

    /* List View adjustments */
    .list-item { padding: 16px 12px; }
    .list-index { width: 40px; font-size: 8px; letter-spacing: 0.2px; }
    .list-art { width: 32px; height: 32px; margin-right: 12px; }
    .list-title { font-size: 10px; }
    .list-meta { display: none; } /* Hidden for space */
    .list-download-icon { font-size: 8px; padding: 4px; margin-left: 8px; }

    /* Player Console Mobile Flow */
    .player-console { height: auto; flex-direction: column; }
    .now-playing-lcd { border-right: none; border-bottom: 1px solid var(--white-border); padding: 16px; gap: 16px; }
    .lcd-art { width: 48px; height: 48px; }
    .lcd-title { font-size: 20px; }
    .lcd-label { font-size: 8px; margin-bottom: 4px; }
    
    .hardware-controls { height: 50px; }
    .hw-btn { flex: 1; border-left: none; border-right: 1px solid var(--white-border); font-size: 10px; }
    .hw-btn:last-child { border-right: none; }
    .hw-btn.play { width: auto; }

    /* Fullscreen Player Mobile Adjustments */
    .video-container { width: 100vw; height: 100vh; height: 100dvh; border: none; }
    .window-btn { width: 48px; height: 48px; font-size: 12px; }
    .vid-controls-overlay { padding: 0 16px; gap: 16px; height: 72px; opacity: 1; } /* Always visible on touch */
    .vid-time { font-size: 10px !important; }
  }

  /* Small Mobile Devices (Fold, older iPhones) */
  @media (max-width: 380px) {
    .grid-container { grid-template-columns: repeat(3, 1fr); } /* Drop to 3 if screen gets unreadably small, otherwise keeps 4 */
    .lcd-title { font-size: 16px; }
  }


  /* Shared STREAMZ premium surface and type treatment. */
  :root {
    --white-dim: rgba(235,240,255,0.055);
    --white-mid: rgba(235,240,255,0.09);
    --white-border: rgba(220,228,245,0.14);
    --white-text: rgba(241,243,248,0.82);
    --white-muted: rgba(190,198,214,0.62);
    --surface: rgba(6,9,16,0.88);
    --surface-2: rgba(14,18,27,0.92);
  }
  .top-dashboard, .player-console, .bottom-navbar {
    background: var(--surface);
    border-color: var(--white-border);
    backdrop-filter: blur(22px);
  }
  .branding { border-right: 0; padding-inline: clamp(20px, 3vw, 40px); }
  .brand-title { font-weight: 400; letter-spacing: -0.4px; text-transform: none; }
  .nav-btn {
    border: 0;
    border-radius: 12px;
    margin: 8px 3px;
    font-family: var(--font-body);
    font-size: 13px;
    letter-spacing: 0;
    text-transform: none;
    cursor: pointer;
  }
  .nav-btn.active { background: var(--white-dim); color: var(--white); }
  .search-container {
    min-width: min(300px, 25vw);
    margin: 10px;
    border: 1px solid var(--white-border);
    border-radius: 14px;
    background: var(--surface-2);
  }
  .search-box { font-family: var(--font-body); font-size: 14px; letter-spacing: 0; text-transform: none; }
  .content-area { padding: clamp(20px, 4vw, 56px); }
  .page-header { margin-bottom: clamp(28px, 5vw, 56px); border-color: var(--white-border); }
  .page-title { font-weight: 300; letter-spacing: -0.045em; line-height: 1; text-transform: none; }
  .page-meta { font-family: var(--font-body); text-transform: none; }
  .grid-container { gap: 14px; border: 0; background: transparent; }
  .card {
    aspect-ratio: 0.86;
    border: 1px solid var(--white-border);
    border-radius: 18px;
    background: var(--surface-2);
    cursor: pointer;
    transition: transform var(--transition-snap), border-color var(--transition-snap), background var(--transition-snap);
  }
  .card:hover, .card:focus { background: var(--surface-2); border-color: rgba(243,244,246,0.56); transform: translateY(-2px); }
  .card-poster-wrap { border: 0; }
  .card-poster { filter: opacity(0.86) grayscale(0.12); }
  .card:hover .card-poster, .card:focus .card-poster { filter: opacity(1) grayscale(0); }
  .card-info { height: 22%; padding: 0 14px; }
  .card-title { font-family: var(--font-body); font-size: 13px; letter-spacing: -0.1px; text-transform: none; }
  .card:hover .card-title, .card:focus .card-title { color: var(--white); font-weight: 500; }
  .action-btn, .list-download-icon {
    border: 1px solid var(--white-border);
    border-radius: 99px;
    font-family: var(--font-body);
    font-size: 12px;
    letter-spacing: 0;
    padding: 6px 12px;
    text-transform: none;
    cursor: pointer;
  }
  .card:hover .action-btn, .card:focus .action-btn { color: var(--white); border-color: var(--white-border); font-weight: 500; }
  .list-container { border-color: var(--white-border); }
  .list-item {
    margin-block: 4px;
    padding: 12px 16px;
    border: 1px solid transparent;
    border-radius: 14px;
    cursor: pointer;
  }
  .list-item:hover, .list-item:focus { background: var(--white-dim); color: var(--white); border-color: var(--white-border); }
  .list-index, .list-title, .list-meta { font-family: var(--font-body); text-transform: none; }
  .list-title { font-size: 14px; }
  .list-item:hover .list-index, .list-item:focus .list-index,
  .list-item:hover .list-meta, .list-item:focus .list-meta { color: var(--white-text); }
  .list-art, .lcd-art { border-radius: 12px; }
  .list-item:hover .list-art, .list-item:focus .list-art { border-color: var(--white-border); }
  .list-download-icon { color: var(--white-text); }
  .list-item:hover .list-download-icon, .list-item:focus .list-download-icon { color: var(--white); border-color: var(--white-border); font-weight: 500; }
  .now-playing-lcd { border-color: var(--white-border); }
  .lcd-title { font-weight: 500; letter-spacing: -0.3px; text-transform: none; }
  .lcd-label { font-family: var(--font-body); text-transform: none; letter-spacing: 0; }
  .hw-btn {
    margin: 10px 5px;
    border: 1px solid var(--white-border);
    border-radius: 14px;
    font-family: var(--font-body);
    letter-spacing: 0;
    text-transform: none;
    cursor: pointer;
  }
  .hw-btn.play { background: var(--white); border-radius: 14px; }
  .empty-state {
    margin: 40px auto 0;
    max-width: 720px;
    padding: clamp(40px, 8vw, 96px) 24px;
    border: 1px solid var(--white-border);
    border-radius: 20px;
    font-family: var(--font-body);
    letter-spacing: 0;
    text-transform: none;
  }
  .status-badge { border-radius: 99px; font-family: var(--font-body); }
  @media (max-width: 768px) {
    .content-area { padding: 16px; }
    .search-container { min-height: 48px; margin: 4px 8px; }
    .search-box { padding-inline: 42px 14px; }
    .grid-container { grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
    .card { aspect-ratio: 0.82; }
    .card-info { padding-inline: 10px; }
    .card-title { font-size: 12px; text-align: left; }
    .list-item { padding: 12px 10px; }
    .list-index { width: 34px; font-size: 10px; }
    .list-title { font-size: 13px; }
    .bottom-navbar { height: 64px; padding: 5px 8px; }
    .bottom-navbar .nav-btn { margin: 2px; border-radius: 12px; font-size: 12px; }
    .lcd-title { font-size: 20px; }
    .hw-btn { margin: 4px; font-size: 12px; }
  }
  @media (max-width: 380px) {
    .grid-container { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  }

  /* Shared Flutter premium dark-glow visual language. */
  :root {
    --black: #020202;
    --white: #f1f2f5;
    --accent: #f3f4f6;
    --white-dim: rgba(235, 240, 255, 0.055);
    --white-mid: rgba(235, 240, 255, 0.09);
    --white-border: rgba(220, 228, 245, 0.1);
    --white-text: rgba(241, 243, 248, 0.82);
    --white-muted: rgba(190, 198, 214, 0.68);
    --surface: rgba(5, 7, 12, 0.58);
    --surface-2: rgba(14, 18, 27, 0.9);
  }
  body {
    height: 100vh;
    height: 100dvh;
    min-height: 100vh;
    min-height: 100dvh;
    background-color: #060606;
    background-image:
      radial-gradient(ellipse 78% 42% at 50% -10%, rgba(12, 58, 168, 0.42) 0%, rgba(12, 58, 168, 0.14) 38%, transparent 76%),
      linear-gradient(180deg, #0a0a0c 0%, #060606 50%, #020202 100%);
    font-family: 'Manrope', sans-serif;
    font-weight: 400;
  }
  button, input { font: inherit; }
  button, a { -webkit-tap-highlight-color: transparent; }
  button { color: inherit; }
  .top-dashboard {
    height: 72px;
    border: 0;
    background: rgba(5, 7, 12, 0.34);
    backdrop-filter: blur(22px);
    -webkit-backdrop-filter: blur(22px);
  }
  .brand-title { font-weight: 600; letter-spacing: -0.3px; }
  .nav-btn, .hw-btn {
    min-height: 44px;
    font-family: 'Manrope', sans-serif;
    font-size: 13px;
    text-transform: none;
    cursor: pointer;
  }
  .nav-btn.active {
    background: rgba(243, 244, 246, 0.12);
    color: var(--white);
  }
  .search-container { background: rgba(14, 18, 27, 0.72); }
  .search-box { min-height: 48px; font-size: 14px; }
  .content-area { max-width: 1600px; width: 100%; margin-inline: auto; }
  .page-header { border: 0; padding-bottom: 0; align-items: center; }
  .page-meta { font-size: 12px; }
  .grid-container { gap: 16px; }
  .card {
    border-radius: 18px;
    box-shadow: 0 12px 32px rgba(0, 0, 0, 0.18);
  }
  .card-title { min-width: 0; font-size: 13px; }
  .action-btn, .list-download-icon {
    min-height: 36px;
    border-radius: 999px;
    font-size: 12px;
  }
  .list-container { border: 0; gap: 8px; }
  .list-item { min-height: 64px; border-radius: 14px; }
  .list-index, .list-meta { font-size: 12px; }
  .list-art, .lcd-art { border-radius: 12px; }
  .player-console {
    background: rgba(5, 7, 12, 0.62);
    border-top: 1px solid rgba(220, 228, 245, 0.08);
    backdrop-filter: blur(22px);
    -webkit-backdrop-filter: blur(22px);
  }
  .lcd-label { font-size: 12px; }
  .hw-btn { border-radius: 14px; }
  .hw-btn.play { border-radius: 14px; }
  .window-btn { cursor: pointer; border-radius: 0 0 0 12px; }
  video { cursor: default; }
  .lcd-label#vid-time { font-size: 12px !important; }
  .list-download-icon { cursor: pointer !important; }
  .empty-state {
    border: 1px solid var(--white-border);
    border-radius: 20px;
    font-size: 14px;
  }
  .status-badge { font-size: 12px; }
  :where(button, input, a, .card, .list-item):focus-visible {
    outline: 2px solid #8eaeff;
    outline-offset: 3px;
  }
  @media (max-width: 768px) {
    .top-dashboard { height: 56px; }
    .content-area { padding: 16px; }
    .page-header {
      align-items: flex-start;
      flex-direction: column;
      gap: 8px;
      margin-bottom: 28px;
    }
    .page-title { font-size: clamp(30px, 9vw, 56px); }
    .page-meta { text-align: left; padding: 0; }
    .grid-container { grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
    .card { aspect-ratio: 0.82; }
    .list-item { gap: 10px; padding: 12px; }
    .list-index { width: auto; min-width: 42px; font-size: 12px; }
    .list-art { margin-right: 4px; }
    .list-title { font-size: 14px; }
    .bottom-navbar {
      height: calc(64px + env(safe-area-inset-bottom, 0px));
      padding: 5px 8px env(safe-area-inset-bottom, 0px);
      border: 0;
      background: rgba(5, 7, 12, 0.7);
    }
    .bottom-navbar .nav-btn { min-width: 44px; min-height: 44px; }
    .lcd-label { font-size: 12px; }
  }
  @media (max-width: 380px) {
    .grid-container { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  }
  @media (prefers-reduced-motion: reduce) {
    *, *::before, *::after {
      scroll-behavior: auto !important;
      animation-duration: 0.01ms !important;
      animation-iteration-count: 1 !important;
      transition-duration: 0.01ms !important;
    }
  }
</style>
</head>
<body>

<div class="top-dashboard">
  <div class="branding">
    <div class="brand-title">STREAMZ</div>
  </div>
  <div class="nav-switches">
    <button class="nav-btn active" id="nav-video" onclick="switchTab('video')">VIDEOS</button>
    <button class="nav-btn" id="nav-audio" onclick="switchTab('audio')">AUDIO</button>
    <button class="nav-btn" id="nav-image" onclick="switchTab('image')">PHOTOS</button>
    <button class="nav-btn" id="nav-folder" onclick="switchTab('folder')">NETWORK</button>
    <button class="nav-btn" id="nav-station" onclick="switchTab('station')">STATIONS</button>
  </div>
  <div class="search-container">
    <input type="text" class="search-box" id="searchInput" placeholder="SEARCH QUERY..." oninput="handleSearch()">
  </div>
</div>

<div class="workspace">
  <div class="content-area">
    <div id="content-area"></div>
  </div>
</div>

<div class="player-console">
  <div class="now-playing-lcd">
    <div class="lcd-art">
      <img id="np-art-img" src="/assets/images/audio_thumbnail.png" onerror="this.style.display='none'">
    </div>
    <div class="lcd-data">
      <div class="lcd-label" id="lcd-status-label">STATUS // IDLE</div>
      <div class="lcd-title" id="np-title">AWAITING SIGNAL...</div>
      <div class="lcd-progress-wrapper" id="np-progress">
        <div class="lcd-progress-bar" id="np-progress-bar"></div>
      </div>
    </div>
  </div>
  <div class="hardware-controls">
    <button class="hw-btn" onclick="seekGlobal(-10)">-10S</button>
    <button class="hw-btn play" onclick="toggleMedia()" id="globalPlayPause">PLAY</button>
    <button class="hw-btn" onclick="seekGlobal(10)">+10S</button>
  </div>
</div>

<div class="bottom-navbar">
  <button class="nav-btn active" id="m-nav-video" onclick="switchTab('video')">VIDEOS</button>
  <button class="nav-btn" id="m-nav-audio" onclick="switchTab('audio')">AUDIO</button>
  <button class="nav-btn" id="m-nav-image" onclick="switchTab('image')">PHOTOS</button>
  <button class="nav-btn" id="m-nav-folder" onclick="switchTab('folder')">SYSTEM</button>
  <button class="nav-btn" id="m-nav-station" onclick="switchTab('station')">LIVE</button>
</div>

<div class="fs-overlay" id="fsOverlay">
  <div class="video-container" id="mediaContainer">
    <div class="window-controls">
      <button class="window-btn" onclick="toggleFullscreen()">FS</button>
      <button class="window-btn" onclick="closePlayer()">ESC</button>
    </div>
    <video id="videoPlayer" onclick="toggleMedia()" ondblclick="toggleFullscreen()" playsinline></video>
    <img id="fs-img" style="display:none;">
    <audio id="audioPlayer" style="display:none;"></audio>
    <div class="vid-controls-overlay" id="vidControls" style="display:none;">
      <button class="hw-btn play" onclick="toggleMedia()" id="vidPlayBtn" style="height:48px;width:100px;border:none;">PAUSE</button>
      <div class="lcd-progress-wrapper" id="vid-progress" style="display:block;flex-grow:1;margin:0;">
        <div class="lcd-progress-bar" id="vid-progress-bar"></div>
      </div>
      <div class="lcd-label" id="vid-time" style="margin:0;font-size:11px;letter-spacing:0.2px;color:var(--white);">00:00 / 00:00</div>
    </div>
  </div>
</div>

<div class="playback-error" id="playbackError" role="alert" aria-live="assertive" hidden>
  <section class="playback-error-card" aria-labelledby="playbackErrorTitle">
    <span class="playback-error-kicker">PLAYBACK DIAGNOSTIC</span>
    <h2 class="playback-error-title" id="playbackErrorTitle"></h2>
    <p class="playback-error-message" id="playbackErrorMessage"></p>
    <p class="playback-error-status" id="playbackErrorStatus"></p>
    <div class="playback-error-actions">
      <button type="button" id="playbackErrorRetry" onclick="retryBrowserPlayback()">TRY AGAIN</button>
      <button type="button" onclick="closePlayer()">BACK TO LIBRARY</button>
    </div>
  </section>
</div>

<script>
  let allMedia = [];
  let currentTab = 'video';
  let currentBrowsePath = '';
  let ws;
  const webClientId = localStorage.getItem('streamz_web_id') || ('WEB_' + Math.floor(Math.random() * 99999));
  localStorage.setItem('streamz_web_id', webClientId);
  // [SECURITY B2] HTML-escape untrusted media names/titles before they are
  // interpolated into innerHTML — a crafted filename must not inject markup.
  const esc = v => String(v ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  // [SECURITY B1] The pairing token arrives in the page URL (QR / link);
  // it is presented on the WS upgrade. No token => read-only (WS refused).
  const pairingToken = new URLSearchParams(window.location.search).get('token') || '';
  let currentSessionId = '';
  let currentMediaTitle = '';
  let currentMediaType = '';
  let lastTelemetryTime = 0;
  let activePlaybackItem = null;
  let activePlaybackWantsResume = false;
  let activePlaybackPosition = 0;
  let activePlaybackUrl = '';
  let playbackIssueKind = '';
  let playbackRetryAttempt = 0;
  let playbackRetryTimer = null;

  const fallbacks = {
    video: '/assets/images/video_thumbnail.png',
    audio: '/assets/images/audio_thumbnail.png',
    image: '/assets/images/photo_thumbnail.png',
    file:  '/assets/images/video_thumbnail.png',
  };

  const tabMeta = {
    video:  { title: 'VIDEO ARCHIVE', sub: 'PATH // ROOT/VIDEO' },
    audio:  { title: 'AUDIO MATRIX',  sub: 'PATH // ROOT/AUDIO' },
    image:  { title: 'PHOTO DB',      sub: 'PATH // ROOT/IMAGE' },
    folder: { title: 'NETWORK SYS',   sub: 'PATH // ROOT/FS'   },
    station: { title: 'LIVE STATIONS', sub: 'PATH // ROOT/STATIONS' },
  };

  function connectWS() {
    const host  = window.location.hostname || '127.0.0.1';
    const wsUrl = `ws://${host}:8080/ws`;
    // [SECURITY B1] Pairing token is presented as the WS subprotocol.
    ws = new WebSocket(wsUrl, pairingToken ? [pairingToken] : []);
    ws.onmessage = (e) => {
      try {
        const cmd = JSON.parse(e.data);
        if (cmd.type === 'nav')   handleRemoteNav(cmd.action);
        if (cmd.type === 'media') handleRemoteMedia(cmd.action, cmd.value);
      } catch(_) {}
    };
    ws.onclose = () => setTimeout(connectWS, 3000);
  }

  function sendTelemetry(isStopped, player) {
    if (!ws || ws.readyState !== WebSocket.OPEN || !currentSessionId) return;
    if (isStopped) {
      ws.send(JSON.stringify({ type:'report_status', clientId:webClientId, sessionId:currentSessionId, title:currentMediaTitle, progress:0, mediaType:currentMediaType, isStopped:true }));
      currentSessionId = '';
      return;
    }
    const now = Date.now();
    if (now - lastTelemetryTime < 2000) return;
    lastTelemetryTime = now;
    const progress = (player && player.duration > 0) ? player.currentTime / player.duration : 0;
    ws.send(JSON.stringify({ type:'report_status', clientId:webClientId, sessionId:currentSessionId, title:currentMediaTitle, progress, mediaType:currentMediaType, isStopped:false }));
  }

  function handleRemoteNav(action) {
    if (action === 'scroll_down') { document.querySelector('.content-area').scrollTop += 400; return; }
    if (action === 'scroll_up')   { document.querySelector('.content-area').scrollTop -= 400; return; }
    if (action === 'back')        { closePlayer(); return; }
    const focusable = Array.from(document.querySelectorAll('[tabindex="0"], input, button'))
      .filter((element) => !element.closest('[hidden]') && element.getClientRects().length > 0);
    if (!focusable.length) return;
    let idx = focusable.indexOf(document.activeElement);
    if (action === 'enter') { document.activeElement?.click(); return; }
    if (idx === -1) { focusable[0].focus(); return; }
    if (action === 'right' || action === 'down') idx = (idx + 1) % focusable.length;
    else if (action === 'left' || action === 'up') idx = (idx - 1 + focusable.length) % focusable.length;
    focusable[idx].focus();
    focusable[idx].scrollIntoView?.({ behavior: 'smooth', block: 'center' });
  }

  function handleRemoteMedia(action, value) {
    const vid = document.getElementById('videoPlayer');
    const aud = document.getElementById('audioPlayer');
    const isFS = document.getElementById('fsOverlay').classList.contains('active');
    const active = isFS ? vid : (aud.src ? aud : null);
    
    if (action === 'station_pause') {
      if (active) { activePlaybackWantsResume = false; active.pause(); updatePlayBtn(true); }
      return;
    }
    if (action === 'station_resume') {
      if (active) { requestBrowserPlay(active); updatePlayBtn(false); }
      return;
    }
    if (action === 'station_stop') {
      closePlayer();
      return;
    }

    if (!active) return;
    
    if (action === 'play' || action === 'pause' || action === 'toggle_play') {
      if (active.paused) requestBrowserPlay(active);
      else { activePlaybackWantsResume = false; active.pause(); }
      updatePlayBtn(active.paused); 
    }
    if (action === 'seek')    active.currentTime += (value || 0);
    if (action === 'mute')    active.muted = !active.muted;
    if (action === 'vol_up')  active.volume = Math.min(1, active.volume + 0.1);
    if (action === 'vol_down') active.volume = Math.max(0, active.volume - 0.1);
  }

  function toggleFullscreen() {
    const c = document.getElementById('mediaContainer');
    if (!document.fullscreenElement && !document.webkitFullscreenElement) {
      if (c.requestFullscreen) {
        c.requestFullscreen();
      } else if (c.webkitRequestFullscreen) {
        c.webkitRequestFullscreen();
      } else if (c.msRequestFullscreen) {
        c.msRequestFullscreen();
      }
    } else {
      if (document.exitFullscreen) {
        document.exitFullscreen();
      } else if (document.webkitExitFullscreen) {
        document.webkitExitFullscreen();
      } else if (document.msExitFullscreen) {
        document.msExitFullscreen();
      }
    }
  }

  document.addEventListener('keydown', (e) => {
    const isOpen = document.getElementById('fsOverlay').classList.contains('active');
    const vid    = document.getElementById('videoPlayer');
    if (isOpen) {
      if (e.key === 'ArrowRight') { vid.currentTime += 10; e.preventDefault(); return; }
      if (e.key === 'ArrowLeft')  { vid.currentTime -= 10; e.preventDefault(); return; }
      if (e.key === ' ')          { toggleMedia(); e.preventDefault(); return; }
      if (e.key === 'f')          { toggleFullscreen(); e.preventDefault(); return; }
      if (e.key === 'Escape')     { closePlayer(); e.preventDefault(); return; }
    }
    if (e.key === 'Enter') { document.activeElement?.click(); e.preventDefault(); }
  });

  async function init() {
    connectWS();
    try {
      const res = await fetch('/api/media');
      allMedia  = await res.json();
      buildUI('video');
    } catch(_) {
      document.getElementById('content-area').innerHTML = '<div class="empty-state">SIGNAL ERROR // DISCONNECTED</div>';
    }
  }

  function syncNavUI(type) {
    document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
    
    // Sync Top Nav
    const navTop = document.getElementById('nav-' + type);
    if (navTop) navTop.classList.add('active');
    
    // Sync Bottom Nav
    const navBottom = document.getElementById('m-nav-' + type);
    if (navBottom) navBottom.classList.add('active');
  }

  function switchTab(type) {
    currentTab = type;
    if (type === 'folder') currentBrowsePath = '';
    syncNavUI(type);
    document.getElementById('searchInput').value = '';
    buildUI(type);
  }

  function handleSearch() {
    if (currentTab === 'folder') return;
    const q = document.getElementById('searchInput').value.toLowerCase();
    if (!q) { buildUI(currentTab); return; }
    renderGrid(allMedia.filter(m => m.type === currentTab && m.title.toLowerCase().includes(q)));
  }

  function buildUI(type) {
    if (type === 'folder') buildFolderView();
    else if (type === 'station') buildStationView();
    else renderGrid(allMedia.filter(m => m.type === type));
  }

  function renderGrid(items) {
    const container = document.getElementById('content-area');
    container.className = 'grid-container';
    container.innerHTML = items.length === 0 ? '<div class="empty-state">0 SIGNALS FOUND.</div>' : '';
    items.forEach(item => {
      const card     = document.createElement('div');
      card.className = 'card';
      card.setAttribute('tabindex', '0');
      const thumb    = '/api/thumbnail/' + item.id;
      const fallback = fallbacks[item.type] || fallbacks.video;
      card.innerHTML = `
        <div class="card-poster-wrap">
          <img class="card-poster" src="${esc(thumb)}" onerror="this.src='${fallback}';this.onerror=null;">
        </div>
        <div class="card-info">
          <div class="card-title" title="${esc(item.title)}">${esc(item.title)}</div>
          <a href="/stream/${encodeURIComponent(item.id)}" download="${esc(item.title)}" class="action-btn" tabindex="-1" onclick="event.stopPropagation()">GET</a>
        </div>`;
      card.onclick = () => openPlayer(item);
      container.appendChild(card);
    });
  }

  async function buildFolderView() {
    const container = document.getElementById('content-area');
    container.className = 'list-container';
    container.innerHTML = '<div class="empty-state">SCANNING NETWORK...</div>';
    try {
      const res   = await fetch('/api/browse?path=' + encodeURIComponent(currentBrowsePath));
      const items = await res.json();
      container.innerHTML = '';
      
      if (currentBrowsePath) {
        const back = document.createElement('div');
        back.className = 'list-item';
        back.setAttribute('tabindex', '0');
        back.innerHTML = '<div class="list-index">[&lt;]</div><div class="list-title">.. / PARENT DIRECTORY</div>';
        back.onclick = () => {
          let lastSlash = Math.max(currentBrowsePath.lastIndexOf('/'), currentBrowsePath.lastIndexOf('\\'));
          if (lastSlash <= 0 || (lastSlash === 2 && currentBrowsePath.charAt(1) === ':')) {
             currentBrowsePath = '';
          } else {
             currentBrowsePath = currentBrowsePath.substring(0, lastSlash);
             if (currentBrowsePath.endsWith(':')) currentBrowsePath += '\\';
          }
          buildFolderView();
        };
        container.appendChild(back);
      }
      
      items.forEach(item => {
        const row = document.createElement('div');
        row.className = 'list-item';
        row.setAttribute('tabindex', '0');
        if (item.isDirectory) {
          row.innerHTML = `<div class="list-index">[NODE]</div><div class="list-title">${esc(item.name)}</div>`;
          row.onclick   = () => { currentBrowsePath = item.path; buildFolderView(); };
        } else {
          const ext      = (item.name.split('.').pop() || '').toLowerCase();
          let typeKey    = 'file';
          if (['mp4','mkv','webm','avi'].includes(ext))      typeKey = 'video';
          if (['mp3','wav','m4a','aac','flac'].includes(ext)) typeKey = 'audio';
          if (['jpg','png','jpeg','webp'].includes(ext))      typeKey = 'image';
          const thumb    = '/api/thumbnail/' + encodeURIComponent(item.path);
          const fallback = fallbacks[typeKey] || fallbacks.file;
          row.innerHTML = `
            <div class="list-index">[${typeKey.substring(0,3).toUpperCase()}]</div>
            <img class="list-art" src="${esc(thumb)}" onerror="this.src='${fallback}';this.onerror=null;">
            <div class="list-title" title="${esc(item.name)}">${esc(item.name)}</div>
            <div class="list-meta">${(item.size/1024/1024).toFixed(1)} MB</div>
            <a href="/api/file?path=${encodeURIComponent(item.path)}" class="list-download-icon" download="${esc(item.name)}" onclick="event.stopPropagation()">GET</a>`;
          row.onclick = () => {
            if (typeKey !== 'file') openPlayer({ id: item.path, type: typeKey, title: item.name }, true);
            else window.open('/api/file?path=' + encodeURIComponent(item.path), '_blank');
          };
        }
        container.appendChild(row);
      });
    } catch(_) {
      container.innerHTML = '<div class="empty-state">ERR: ACCESS DENIED.</div>';
    }
  }

  async function buildStationView() {
    const container = document.getElementById('content-area');
    container.className = 'list-container';
    container.innerHTML = '<div class="empty-state">TUNING SIGNALS...</div>';
    try {
      const res = await fetch('/api/stations');
      const items = await res.json();
      container.innerHTML = items.length === 0 ? '<div class="empty-state">0 BROADCASTS FOUND.</div>' : '';
      
      items.forEach(station => {
        const row = document.createElement('div');
        row.className = 'list-item';
        row.setAttribute('tabindex', '0');
        const np = station.nowPlaying;
        const sub = np ? `PLAYING: ${esc(np.item.title)}` : 'IDLE';
        const thumb = np ? '/api/thumbnail/' + np.item.id : fallbacks.video;
        
        row.innerHTML = `
          <div class="list-index">[LIVE]</div>
          <img class="list-art" src="${esc(thumb)}" onerror="this.src='${fallbacks.video}';this.onerror=null;">
          <div class="lcd-data" style="flex-grow:1;overflow:hidden;">
            <div class="lcd-label">${esc(station.name)}</div>
            <div class="list-title" style="font-size:16px;">${sub}</div>
          </div>
          <button class="list-download-icon" style="background:transparent;cursor:crosshair;">JOIN</button>`;
        
        row.onclick = async () => {
          try {
            const joinRes = await fetch('/api/stations/join/' + station.id);
            const data = await joinRes.json();
            if (data && data.item) {
              openPlayer(data.item, false, data.isPaused);
              const player = data.item.type === 'audio' ? aud : vid;
              player.currentTime = data.positionMs / 1000;
            }
          } catch(e) { console.error('Join failed', e); }
        };
        container.appendChild(row);
      });
    } catch(_) {
      container.innerHTML = '<div class="empty-state">ERR: STATION OFFLINE.</div>';
    }
  }

  const aud = document.getElementById('audioPlayer');
  const vid = document.getElementById('videoPlayer');

  function activePlaybackElement() {
    return activePlaybackItem?.type === 'audio' ? aud : vid;
  }

  function hidePlaybackError() {
    document.getElementById('playbackError').hidden = true;
    document.getElementById('playbackErrorStatus').innerText = '';
  }

  function beginBrowserPlayback(item, isPath, startPaused) {
    clearTimeout(playbackRetryTimer);
    playbackRetryTimer = null;
    activePlaybackItem = item;
    activePlaybackWantsResume = !startPaused;
    activePlaybackPosition = 0;
    activePlaybackUrl = isPath
      ? '/api/file?path=' + encodeURIComponent(item.id)
      : '/stream/' + item.id;
    playbackIssueKind = '';
    playbackRetryAttempt = 0;
    hidePlaybackError();
  }

  function playbackIssueDetails(media, error) {
    // ponytail: browsers expose only a small media error code and free-form
    // play() errors. Add response-status mapping if the host stream API exposes it.
    const code = media.error?.code;
    const detail = `${error?.name || ''} ${error?.message || ''}`.toLowerCase();
    if (detail.includes('notallowed') || detail.includes('autoplay') || detail.includes('user gesture')) {
      return ['device', 'Playback was blocked by this browser', 'Press Try Again to allow playback. Check browser autoplay or media permissions if it keeps happening.'];
    }
    if (code === 2 || detail.includes('network') || detail.includes('connection') || !navigator.onLine) {
      return ['connection', 'Connection interrupted', 'The media host or Wi-Fi stopped responding. STREAMZ will retry and resume near the last position. Check that the host is still running on the same network.'];
    }
    if (code === 3 || code === 4 || detail.includes('decode') || detail.includes('codec') || detail.includes('not supported')) {
      return ['codec', 'This media may not be supported', 'The file format or codec may not be supported by this browser or device. Try another file or a device with broader codec support.'];
    }
    return ['unknown', 'Playback stopped unexpectedly', 'Retry playback. If it keeps failing, try another file to check whether this browser or device supports its format.'];
  }

  function showBrowserPlaybackIssue(media, error) {
    if (!activePlaybackItem || media !== activePlaybackElement()) return;
    if (Number.isFinite(media.currentTime)) {
      activePlaybackPosition = Math.max(activePlaybackPosition, media.currentTime);
    }
    const [kind, title, message] = playbackIssueDetails(media, error);
    playbackIssueKind = kind;
    const panel = document.getElementById('playbackError');
    const wasHidden = panel.hidden;
    document.getElementById('playbackErrorTitle').innerText = title;
    document.getElementById('playbackErrorMessage').innerText = message;
    panel.hidden = false;
    if (wasHidden) document.getElementById('playbackErrorRetry').focus();
    const status = document.getElementById('playbackErrorStatus');
    if (kind === 'connection' && activePlaybackWantsResume && !playbackRetryTimer) {
      const seconds = Math.min(2 ** (playbackRetryAttempt + 1), 30);
      status.innerText = `Reconnecting · retry ${playbackRetryAttempt + 1} in ${seconds}s`;
      playbackRetryTimer = setTimeout(() => {
        playbackRetryTimer = null;
        retryBrowserPlayback(true);
      }, seconds * 1000);
    } else {
      status.innerText = '';
    }
  }

  function requestBrowserPlay(media) {
    activePlaybackWantsResume = true;
    const result = media.play();
    if (result && typeof result.catch === 'function') {
      result.catch((error) => showBrowserPlaybackIssue(media, error));
    }
  }

  function retryBrowserPlayback(automatic = false) {
    const item = activePlaybackItem;
    if (!item) return;
    clearTimeout(playbackRetryTimer);
    playbackRetryTimer = null;
    const media = activePlaybackElement();
    if (Number.isFinite(media.currentTime)) {
      activePlaybackPosition = Math.max(activePlaybackPosition, media.currentTime);
    }
    if (!automatic) playbackRetryAttempt = 0;
    playbackRetryAttempt++;
    document.getElementById('playbackError').hidden = false;
    document.getElementById('playbackErrorStatus').innerText =
      `Reopening stream · attempt ${playbackRetryAttempt}`;
    const position = activePlaybackPosition;
    media.pause();
    media.addEventListener('loadedmetadata', () => {
      if (activePlaybackItem !== item) return;
      if (!item.isBroadcast && position > 0 && Number.isFinite(media.duration) && media.duration > 0) {
        media.currentTime = Math.min(position, Math.max(0, media.duration - 0.5));
      }
      if (activePlaybackWantsResume) requestBrowserPlay(media);
      else document.getElementById('playbackErrorStatus').innerText = 'Stream is ready. Press Play to continue.';
    }, { once: true });
    media.src = activePlaybackUrl;
    media.load();
  }

  aud.addEventListener('error', (event) => showBrowserPlaybackIssue(aud, event));
  vid.addEventListener('error', (event) => showBrowserPlaybackIssue(vid, event));
  [aud, vid].forEach((media) => media.addEventListener('playing', () => {
    if (media !== activePlaybackElement()) return;
    clearTimeout(playbackRetryTimer);
    playbackRetryTimer = null;
    playbackRetryAttempt = 0;
    playbackIssueKind = '';
    activePlaybackWantsResume = true;
    activePlaybackPosition = media.currentTime || activePlaybackPosition;
    hidePlaybackError();
  }));
  window.addEventListener('offline', () => {
    const media = activePlaybackItem ? activePlaybackElement() : null;
    if (media && activePlaybackWantsResume) showBrowserPlaybackIssue(media, new Error('network offline'));
  });
  window.addEventListener('online', () => {
    if (playbackIssueKind === 'connection' && activePlaybackItem) retryBrowserPlayback(true);
  });

  aud.addEventListener('timeupdate', () => {
    if (!aud.duration) return;
    activePlaybackPosition = Math.max(activePlaybackPosition, aud.currentTime);
    document.getElementById('np-progress-bar').style.width = (aud.currentTime / aud.duration * 100) + '%';
    sendTelemetry(false, aud);
  });
  document.getElementById('np-progress').addEventListener('click', (e) => {
    const r = document.getElementById('np-progress').getBoundingClientRect();
    if (aud.duration) aud.currentTime = ((e.clientX - r.left) / r.width) * aud.duration;
  });

  vid.addEventListener('timeupdate', () => {
    if (!vid.duration) return;
    activePlaybackPosition = Math.max(activePlaybackPosition, vid.currentTime);
    document.getElementById('vid-progress-bar').style.width = (vid.currentTime / vid.duration * 100) + '%';
    const m = Math.floor(vid.currentTime/60), s = Math.floor(vid.currentTime%60).toString().padStart(2,'0');
    const dm = Math.floor(vid.duration/60),  ds = Math.floor(vid.duration%60).toString().padStart(2,'0');
    document.getElementById('vid-time').innerText = `${m}:${s} / ${dm}:${ds}`;
    sendTelemetry(false, vid);
  });
  document.getElementById('vid-progress').addEventListener('click', (e) => {
    const r = document.getElementById('vid-progress').getBoundingClientRect();
    if (vid.duration) vid.currentTime = ((e.clientX - r.left) / r.width) * vid.duration;
  });

  window.addEventListener('beforeunload', () => sendTelemetry(true, null));

  function openPlayer(item, isPath = false, startPaused = false) {
    if (currentSessionId) sendTelemetry(true, null);
    currentSessionId  = 'SESSION_' + Date.now();
    currentMediaTitle = item.title;
    currentMediaType  = item.type;
    beginBrowserPlayback(item, isPath, startPaused);
    const url = isPath ? '/api/file?path=' + encodeURIComponent(item.id) : '/stream/' + item.id;

    if (item.type === 'audio') {
      aud.src = url;
      if (!startPaused) requestBrowserPlay(aud);
      document.getElementById('lcd-status-label').innerText = item.isBroadcast ? 'STATUS // LIVE' : 'STATUS // BROADCASTING';
      document.getElementById('np-title').innerText     = item.title;
      document.getElementById('np-progress').style.display = 'block';
      // Restrict progress interaction for broadcasts
      document.getElementById('np-progress').style.pointerEvents = item.isBroadcast ? 'none' : 'auto';
      document.getElementById('np-progress-bar').style.background = item.isBroadcast ? 'orange' : 'var(--white)';
      
      const art = document.getElementById('np-art-img');
      art.style.display = 'block';
      art.src = isPath
          ? '/api/thumbnail/' + encodeURIComponent(item.id)
          : '/api/thumbnail/' + item.id;
      art.onerror = () => { art.src = fallbacks.audio; art.onerror = null; };
      updatePlayBtn(startPaused);
      return;
    }

    const overlay = document.getElementById('fsOverlay');
    const img     = document.getElementById('fs-img');
    const ctrls   = document.getElementById('vidControls');
    overlay.classList.add('active');
    vid.style.display = 'none';
    img.style.display = 'none';
    ctrls.style.display = 'none';
    vid.pause();

    if (item.type === 'video') {
      vid.src = url;
      vid.style.display   = 'block';
      ctrls.style.display = 'flex';
      
      // Restrict progress interaction for broadcasts
      document.getElementById('vid-progress').style.pointerEvents = item.isBroadcast ? 'none' : 'auto';
      document.getElementById('vid-progress-bar').style.background = item.isBroadcast ? 'orange' : 'var(--white)';
      document.getElementById('vid-time').innerText = item.isBroadcast ? 'LIVE BROADCAST' : '00:00 / 00:00';

      if (!startPaused) requestBrowserPlay(vid);
      updatePlayBtn(startPaused);
    } else if (item.type === 'image') {
      img.src = url;
      img.style.display = 'block';
    }
  }

  function closePlayer() {
    clearTimeout(playbackRetryTimer);
    playbackRetryTimer = null;
    activePlaybackWantsResume = false;
    activePlaybackItem = null;
    activePlaybackUrl = '';
    playbackIssueKind = '';
    hidePlaybackError();
    if (document.fullscreenElement || document.webkitFullscreenElement) {
      if (document.exitFullscreen) document.exitFullscreen();
      else if (document.webkitExitFullscreen) document.webkitExitFullscreen();
    }
    document.getElementById('fsOverlay').classList.remove('active');
    sendTelemetry(true, null);
    vid.pause(); vid.src = '';
    vid.style.display = 'none'; // Ensure it's hidden so it doesn't block audio in toggleMedia
    if (aud.src) {
      aud.pause(); aud.src = '';
      document.getElementById('lcd-status-label').innerText = 'STATUS // IDLE';
      document.getElementById('np-title').innerText  = 'AWAITING SIGNAL...';
      document.getElementById('np-progress').style.display = 'none';
    }
  }

  function toggleMedia() {
    if (currentMediaType && allMedia.find(m => m.title === currentMediaTitle)?.isBroadcast) return;
    const isFS = document.getElementById('fsOverlay').classList.contains('active');
    const active = isFS ? vid : aud;
    if (!active.src) return;
    if (active.paused) { requestBrowserPlay(active); updatePlayBtn(false); }
    else { activePlaybackWantsResume = false; active.pause(); updatePlayBtn(true); }
  }

  function updatePlayBtn(isPaused) {
    document.getElementById('globalPlayPause').innerText = isPaused ? 'PLAY' : 'PAUSE';
    document.getElementById('vidPlayBtn').innerText      = isPaused ? 'PLAY' : 'PAUSE';
    
    // Disable local play/pause for broadcasts
    const isBroadcast = currentMediaTitle && (vid.src || aud.src) && (
      (vid.src && document.getElementById('vid-progress').style.pointerEvents === 'none') ||
      (aud.src && document.getElementById('np-progress').style.pointerEvents === 'none')
    );
    
    document.getElementById('globalPlayPause').disabled = isBroadcast;
    document.getElementById('vidPlayBtn').disabled      = isBroadcast;
    document.getElementById('globalPlayPause').style.opacity = isBroadcast ? '0.5' : '1';
    document.getElementById('vidPlayBtn').style.opacity      = isBroadcast ? '0.5' : '1';
  }

  function seekGlobal(s) {
    const isBroadcast = (vid.src && document.getElementById('vid-progress').style.pointerEvents === 'none') ||
                        (aud.src && document.getElementById('np-progress').style.pointerEvents === 'none');
    if (isBroadcast) return;

    const isFS = document.getElementById('fsOverlay').classList.contains('active');
    const active = isFS ? vid : aud;
    if (active.src) active.currentTime += s;
  }

  init();
</script>
</body>
</html>
""";
