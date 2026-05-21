// data/network/modern_web_html.dart
// ============================================================================
// STREAMZ — Built-in Web Interface HTML (Spatial UI - Compact Player)
// ============================================================================

const String kModernWebInterfaceHtml = r"""
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Streamz Spatial</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
<script src="https://unpkg.com/@phosphor-icons/web"></script>
<style>
  :root {
    /* Pure Spatial Glass Material Tokens */
    --glass-base: rgba(40, 40, 40, 0.35);
    --glass-hover: rgba(255, 255, 255, 0.15);
    --glass-active: rgba(255, 255, 255, 0.25);
    
    --glass-border: rgba(255, 255, 255, 0.12);
    --glass-highlight: inset 0 1px 1px rgba(255, 255, 255, 0.3), inset 0 0 4px rgba(255, 255, 255, 0.1);
    
    --blur-intense: blur(10px);
    
    --text-primary: rgba(255, 255, 255, 0.95);
    --text-secondary: rgba(255, 255, 255, 0.65);
    --text-muted: rgba(255, 255, 255, 0.4);
    
    --accent: #ffffff;
    
    --radius-sm: 12px;
    --radius-md: 20px;
    --radius-lg: 32px;
    --radius-pill: 9999px;
    
    --shadow-spatial: 0 40px 80px -20px rgba(0, 0, 0, 0.6);
    --shadow-float: 0 16px 40px rgba(0, 0, 0, 0.5);
    
    --transition: 0.4s cubic-bezier(0.16, 1, 0.3, 1);
  }
  
  * { box-sizing: border-box; margin: 0; padding: 0; }
  
  body {
    background-color: #000;
    background-image: url('/assets/images/web_app_bg_1.jpg');
    background-size: cover;
    background-position: center;
    background-attachment: fixed;
    transition: background-image 0.8s ease-in-out;
    color: var(--text-primary);
    font-family: 'Inter', -apple-system, sans-serif;
    font-weight: 400;
    overflow: hidden;
    height: 100vh;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 24px;
    padding: 24px;
    -webkit-font-smoothing: antialiased;
  }

  ::-webkit-scrollbar { width: 6px; }
  ::-webkit-scrollbar-track { background: transparent; }
  ::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.25); border-radius: 10px; }
  ::-webkit-scrollbar-thumb:hover { background: rgba(255,255,255,0.5); }

  /* ── SPATIAL PANELS ────────────────────────────────────────────────────── */

  .spatial-panel {
    background: var(--glass-base);
    backdrop-filter: var(--blur-intense);
    -webkit-backdrop-filter: var(--blur-intense);
    border: 1px solid var(--glass-border);
    box-shadow: var(--shadow-spatial), var(--glass-highlight);
  }

  .spatial-layout {
    position: relative;
    width: 92vw;
    max-width: 1600px;
    height: 95vh;
    max-height: 900px;
    display: flex;
    align-items: stretch;
    gap: 24px;
  }

  /* 1. Floating Left Dock */
  .left-dock {
    width: 72px;
    height: max-content;
    align-self: center;
    border-radius: var(--radius-pill);
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 24px 0;
    gap: 16px;
    z-index: 100;
    flex-shrink: 0;
  }

  .dock-btn {
    position: relative;
    width: 48px;
    height: 48px;
    border-radius: 50%;
    background: transparent;
    border: 1px solid transparent;
    color: var(--text-secondary);
    font-size: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: all 0.2s cubic-bezier(0.2, 0.8, 0.2, 1);
    outline: none;
  }
  
  .dock-btn:hover { background: var(--glass-hover); color: var(--text-primary); transform: scale(1.1); }
  .dock-btn.active { background: var(--glass-active); color: var(--text-primary); border-color: var(--glass-border); box-shadow: inset 0 1px 1px rgba(255,255,255,0.4); }

  .dock-divider {
    width: 32px;
    height: 1px;
    background: rgba(255,255,255,0.15);
    margin: 4px 0;
  }

  /* Spatial Tooltips */
  .dock-btn::after {
    content: attr(data-tooltip);
    position: absolute;
    left: calc(100% + 20px);
    background: rgba(30, 30, 30, 0.6);
    backdrop-filter: blur(20px);
    -webkit-backdrop-filter: blur(20px);
    border: 1px solid var(--glass-border);
    padding: 10px 16px;
    border-radius: 12px;
    font-size: 13px;
    font-weight: 600;
    color: var(--text-primary);
    white-space: nowrap;
    opacity: 0;
    transform: translateX(-10px);
    pointer-events: none;
    transition: all 0.3s cubic-bezier(0.2, 0.8, 0.2, 1);
    box-shadow: var(--shadow-float);
    z-index: 200;
  }
  .dock-btn:hover::after { opacity: 1; transform: translateX(0); }

  /* 2. Center Column */
  .center-column {
    flex-grow: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 24px;
    overflow: hidden;
  }

  /* 3. Floating Top Bar */
  .top-bar {
    width: max-content;
    height: 64px;
    border-radius: var(--radius-pill);
    display: flex;
    align-items: center;
    padding: 0 12px 0 24px;
    gap: 24px;
    flex-shrink: 0;
  }

  .search-container { position: relative; width: 320px; }
  .search-container i { position: absolute; left: 12px; top: 50%; transform: translateY(-50%); color: var(--text-secondary); font-size: 20px; }
  .search-box {
    width: 100%;
    background: rgba(0,0,0,0.3);
    border: 1px solid rgba(255,255,255,0.1);
    border-radius: var(--radius-pill);
    color: var(--text-primary);
    font-family: inherit;
    font-size: 14px;
    padding: 10px 16px 10px 38px;
    outline: none;
    transition: all 0.2s;
  }
  .search-box::placeholder { color: var(--text-subdued); }
  .search-box:focus { background: rgba(0,0,0,0.5); border-color: rgba(255,255,255,0.3); box-shadow: 0 0 0 4px rgba(255,255,255,0.05); }

  .user-pill {
    display: flex;
    align-items: center;
    gap: 12px;
    background: rgba(0,0,0,0.3);
    padding: 6px 16px 6px 6px;
    border-radius: var(--radius-pill);
    font-size: 13px;
    font-weight: 700;
    letter-spacing: 1px;
    border: 1px solid rgba(255,255,255,0.1);
    cursor: pointer;
    transition: background 0.2s;
  }
  .user-pill:hover { background: rgba(0,0,0,0.5); border-color: rgba(255,255,255,0.2); }
  .user-pill .avatar { width: 28px; height: 28px; border-radius: 50%; background: var(--text-primary); display: flex; align-items: center; justify-content: center; color: #000; font-size: 16px; font-weight: bold; }

  /* 4. Main Window */
  .main-window {
    width: 100%;
    flex-grow: 1;
    border-radius: var(--radius-lg);
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .content-area {
    flex-grow: 1;
    overflow-y: auto;
    padding: 24px 40px;
  }

  .page-header { margin-bottom: 24px; display: flex; flex-direction: column; gap: 4px; }
  .page-title { font-size: 24px; font-weight: 700; letter-spacing: -0.5px; text-transform: capitalize;}
  .page-meta { font-size: 11px; color: var(--text-secondary); font-weight: 500; text-transform: uppercase; letter-spacing: 1px; }

  /* BORDERLESS, FLOATING GRID */
  .grid-container {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); 
    gap: 24px 20px;
  }

  .media-card {
    background: transparent;
    border: none;
    padding: 0;
    cursor: pointer;
    display: flex;
    flex-direction: column;
    outline: none;
    position: relative;
    transition: transform var(--transition);
  }
  .media-card:hover, .media-card:focus { transform: scale(1.02); }

  .card-thumb-wrap {
    width: 100%;
    aspect-ratio: 1;
    border-radius: var(--radius-md); 
    margin-bottom: 12px;
    overflow: hidden;
    position: relative;
    background: rgba(0,0,0,0.3);
    border: 1px solid rgba(255,255,255,0.08); 
    box-shadow: 0 12px 32px rgba(0,0,0,0.4);
    transition: all var(--transition);
  }

  .card-thumb { width: 100%; height: 100%; object-fit: cover; transition: transform 0.6s cubic-bezier(0.2, 0.8, 0.2, 1); }
  
  .card-thumb-wrap::after {
    content: '';
    position: absolute;
    inset: 0;
    background: linear-gradient(to bottom, transparent 60%, rgba(0,0,0,0.6) 100%);
    opacity: 0;
    transition: opacity 0.4s;
  }
  
  .media-card:hover .card-thumb { transform: scale(1.08); }
  .media-card:hover .card-thumb-wrap::after { opacity: 1; }
  .media-card:hover .card-thumb-wrap { border-color: rgba(255,255,255,0.2); box-shadow: 0 20px 40px rgba(0,0,0,0.6); }

  .card-play-btn {
    position: absolute;
    inset: 0;
    margin: auto;
    width: 48px;
    height: 48px;
    border-radius: 50%;
    background: rgba(255,255,255,0.2);
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    border: 1px solid rgba(255,255,255,0.4);
    color: #fff;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 20px;
    opacity: 0;
    transform: scale(0.8);
    transition: all var(--transition);
    cursor: pointer;
    box-shadow: 0 8px 24px rgba(0,0,0,0.4);
    z-index: 10;
  }
  .card-play-btn:hover { background: rgba(255,255,255,0.4); transform: scale(1.1); }
  .media-card:hover .card-play-btn, .media-card:focus .card-play-btn { opacity: 1; transform: scale(1); }

  .card-info { padding: 0 4px; display: flex; flex-direction: row; align-items: center; justify-content: space-between; gap: 8px; }
  .card-title { font-size: 14px; font-weight: 600; color: var(--text-primary); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; flex-grow: 1; }
  .dl-icon { color: var(--text-subdued); font-size: 18px; transition: color 0.2s; text-decoration: none; flex-shrink: 0; display: flex; align-items: center; justify-content: center; }
  .dl-icon:hover { color: var(--text-primary); }

  /* CSS Grid List View */
  .list-container { display: flex; flex-direction: column; gap: 4px; }
  .list-header, .media-row {
    display: grid;
    grid-template-columns: 56px 1fr 100px 40px; 
    align-items: center;
    gap: 16px;
  }
  .list-header {
    padding: 0 20px 12px 20px;
    border-bottom: 1px solid rgba(255,255,255,0.1);
    margin-bottom: 12px;
    color: var(--text-secondary);
    font-size: 12px;
    font-weight: 600;
    letter-spacing: 1px;
    text-transform: uppercase;
  }
  .media-row {
    padding: 8px 20px;
    border-radius: var(--radius-sm);
    background: transparent;
    cursor: pointer;
    transition: all 0.2s;
    outline: none;
    border: 1px solid transparent;
  }
  .media-row:hover, .media-row:focus { background: rgba(255,255,255,0.08); border-color: rgba(255,255,255,0.1); transform: scale(1.005); }

  .row-icon-wrap { display: flex; justify-content: center; align-items: center; width: 100%; height: 100%; }
  .row-icon { font-size: 24px; color: var(--text-secondary); }
  .row-art { width: 44px; height: 44px; border-radius: 8px; object-fit: cover; box-shadow: 0 4px 12px rgba(0,0,0,0.3); border: 1px solid rgba(255,255,255,0.1); }
  .row-title { font-size: 14px; font-weight: 500; color: var(--text-primary); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .row-meta { font-size: 13px; color: var(--text-secondary); text-align: right; font-variant-numeric: tabular-nums; }

  /* Empty State */
  .empty-state { display: flex; flex-direction: column; align-items: center; justify-content: center; height: 50vh; color: var(--text-subdued); gap: 16px; }
  .empty-state i { font-size: 64px; opacity: 0.5; }
  .empty-state span { font-weight: 500; font-size: 16px; letter-spacing: 1px; }

  /* ── 5. FLOATING BOTTOM PLAYER ─────────────────────────────────────────── */
  
  .player-console {
    width: max-content; /* Shrink to wrap contents */
    height: 72px;
    border-radius: var(--radius-pill);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 0 24px; /* Balanced floating padding */
    gap: 24px;
    flex-shrink: 0;
  }
  
  .ctrl-btn {
    background: transparent;
    border: none;
    color: var(--text-primary);
    font-size: 24px;
    cursor: pointer;
    transition: all 0.2s cubic-bezier(0.2, 0.8, 0.2, 1);
    outline: none;
    display: flex;
    align-items: center;
    justify-content: center;
    opacity: 0.9;
    line-height: 0;
  }
  .ctrl-btn:hover { opacity: 1; transform: scale(1.15); text-shadow: 0 0 12px rgba(255,255,255,0.4); color: #ffffff; }

  /* PILL PROGRESS BAR STYLING (Black progress) */
  .now-playing-pill {
    position: relative; 
    display: flex;
    align-items: center;
    background: rgba(0, 0, 0, 0.35);
    border: 1px solid rgba(255,255,255,0.08);
    box-shadow: inset 0 2px 10px rgba(0,0,0,0.3);
    border-radius: var(--radius-pill);
    padding: 6px 16px 6px 6px;
    gap: 16px;
    width: 380px; 
    overflow: hidden; 
    cursor: pointer;
  }

  /* Black Frosted Progress Fill */
  .np-progress-bg {
    position: absolute;
    left: 0;
    top: 0;
    bottom: 0;
    width: 0%;
    background: rgba(0, 0, 0, 0.6); 
    border-right: 1px solid #000;
    z-index: 0;
    pointer-events: none;
    transition: width 0.1s linear;
  }

  .np-art, .np-info {
    position: relative;
    z-index: 1;
  }
  
  .np-art { width: 40px; height: 40px; border-radius: 50%; overflow: hidden; background: rgba(0,0,0,0.6); flex-shrink: 0; }
  .np-art img { width: 100%; height: 100%; object-fit: cover; }
  .np-info { display: flex; flex-direction: column; overflow: hidden; flex-grow: 1; pointer-events: none; }
  .np-title { font-size: 14px; font-weight: 600; color: var(--text-primary); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; margin-bottom: 2px;}
  .np-label { font-size: 12px; color: var(--text-secondary); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

  .player-controls-left {
    display: flex;
    align-items: center;
    gap: 20px;
  }

  /* ── FULLSCREEN OVERLAY ────────────────────────────────────────────────── */

  .fs-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0,0,0,0.85);
    backdrop-filter: blur(50px);
    -webkit-backdrop-filter: blur(50px);
    z-index: 3000;
    display: none;
    align-items: center;
    justify-content: center;
  }
  .fs-overlay.active { display: flex; animation: fadeIn 0.4s cubic-bezier(0.2, 0.8, 0.2, 1); }
  @keyframes fadeIn { from { opacity: 0; transform: scale(1.05); } to { opacity: 1; transform: scale(1); } }

  .video-container { width: 100%; height: 100%; position: relative; display: flex; align-items: center; justify-content: center; padding: 40px; }
  .window-controls { position: absolute; top: 40px; right: 40px; display: flex; gap: 16px; z-index: 3001; opacity: 0; transition: opacity 0.4s; }
  .video-container:hover .window-controls { opacity: 1; }

  .overlay-btn {
    width: 56px; height: 56px; border-radius: 50%; background: rgba(255,255,255,0.1); backdrop-filter: blur(20px); border: 1px solid rgba(255,255,255,0.2);
    color: #fff; font-size: 24px; cursor: pointer; display: flex; align-items: center; justify-content: center; transition: all var(--transition);
  }
  .overlay-btn:hover { background: rgba(255,255,255,0.25); transform: scale(1.1); }

  video { max-width: 100%; max-height: 100%; object-fit: contain; outline: none; border-radius: 24px; box-shadow: 0 60px 120px rgba(0,0,0,0.7); }
  img#fs-img { max-width: 100%; max-height: 100%; object-fit: contain; border-radius: 24px; box-shadow: 0 60px 120px rgba(0,0,0,0.7); }

  .vid-controls-overlay {
    position: absolute;
    bottom: 60px;
    left: 50%;
    transform: translateX(-50%);
    width: max-content;
    min-width: 600px;
    background: rgba(30, 30, 30, 0.5);
    backdrop-filter: blur(40px);
    -webkit-backdrop-filter: blur(40px);
    border: 1px solid rgba(255,255,255,0.15);
    border-radius: var(--radius-pill);
    padding: 16px 32px;
    opacity: 0;
    transition: opacity 0.4s ease;
    z-index: 3002;
    display: flex;
    align-items: center;
    gap: 24px;
    box-shadow: 0 32px 64px rgba(0,0,0,0.6), inset 0 1px 1px rgba(255,255,255,0.2);
  }
  .video-container:hover .vid-controls-overlay { opacity: 1; }
  
  .vid-time { font-size: 13px; font-weight: 500; font-family: monospace; color: rgba(255,255,255,0.9); }
  
  .progress-container { flex-grow: 1; display: flex; align-items: center; cursor: pointer; }
  .progress-bar-wrap { width: 100%; height: 24px; display: flex; align-items: center; }
  .progress-bg { width: 100%; height: 6px; background: rgba(255,255,255,0.15); border-radius: 4px; position: relative; }
  
  /* Black Video Progress */
  .progress-fill { height: 100%; width: 0%; background: #000; border-radius: 4px; pointer-events: none; transition: width 0.1s linear; box-shadow: 0 0 12px rgba(0,0,0,0.5); }
</style>
</head>
<body>

<div class="spatial-layout">
  
  <nav class="left-dock spatial-panel">
    <button class="dock-btn active" id="nav-video" onclick="switchTab('video')" data-tooltip="Videos">
      <i class="ph-bold ph-video-camera"></i>
    </button>
    <button class="dock-btn" id="nav-audio" onclick="switchTab('audio')" data-tooltip="Music & Audio">
      <i class="ph-bold ph-music-notes"></i>
    </button>
    <button class="dock-btn" id="nav-image" onclick="switchTab('image')" data-tooltip="Photos">
      <i class="ph-bold ph-image"></i>
    </button>
    <button class="dock-btn" id="nav-folder" onclick="switchTab('folder')" data-tooltip="Network Files">
      <i class="ph-bold ph-folder-open"></i>
    </button>
    <div class="dock-divider"></div>
    <button class="dock-btn" onclick="cycleBackground()" data-tooltip="Change Environment">
      <i class="ph-bold ph-aperture"></i>
    </button>
  </nav>

  <div class="center-column">
    
    <header class="top-bar spatial-panel">
      <div class="search-container">
        <i class="ph-bold ph-magnifying-glass"></i>
        <input type="text" class="search-box" id="searchInput" placeholder="Search spatial library..." oninput="handleSearch()">
      </div>
      <div class="user-pill">
        <div class="avatar"><i class="ph-fill ph-planet"></i></div>
        STREAMZ
      </div>
    </header>

    <main class="main-window spatial-panel">
      <div class="content-area">
        <div class="page-header">
          <div class="page-title" id="page-title">Video Archive</div>
          <div class="page-meta" id="page-subtitle">Directory: root/video</div>
        </div>
        <div id="content-area"></div>
      </div>
    </main>

    <footer class="player-console spatial-panel">
      <div class="now-playing-pill" id="np-pill-progress-wrap">
        <div class="np-progress-bg" id="np-pill-progress"></div>
        <div class="np-art">
          <img id="np-art-img" src="/assets/images/audio_thumbnail.png" onerror="this.style.display='none'">
        </div>
        <div class="np-info">
          <div class="np-title" id="np-title">Nothing playing</div>
          <div class="np-label" id="np-label">Awaiting signal</div>
        </div>
      </div>
      
      <div class="player-controls-left">
        <button class="ctrl-btn" onclick="seekGlobal(-10)"><i class="ph-fill ph-rewind"></i></button>
        <button class="ctrl-btn" style="font-size: 28px;" onclick="toggleMedia()" id="globalPlayPause"><i class="ph-fill ph-pause"></i></button>
        <button class="ctrl-btn" onclick="seekGlobal(10)"><i class="ph-fill ph-fast-forward"></i></button>
      </div>
    </footer>
  </div>

</div>

<div class="fs-overlay" id="fsOverlay">
  <div class="video-container" id="mediaContainer">
    <div class="window-controls">
      <button class="overlay-btn" onclick="toggleFullscreen()"><i class="ph-bold ph-arrows-out"></i></button>
      <button class="overlay-btn" onclick="closePlayer()"><i class="ph-bold ph-x"></i></button>
    </div>
    <video id="videoPlayer" onclick="toggleMedia()" ondblclick="toggleFullscreen()"></video>
    <img id="fs-img" style="display:none;">
    <audio id="audioPlayer" style="display:none;"></audio>
    
    <div class="vid-controls-overlay" id="vidControls" style="display:none;">
      <button class="ctrl-btn" style="width: 48px; height: 48px; font-size: 28px;" onclick="toggleMedia()" id="vidPlayBtn"><i class="ph-fill ph-pause"></i></button>
      <div class="progress-container" id="vid-progress">
        <div class="progress-bar-wrap">
          <div class="progress-bg"><div class="progress-fill" id="vid-progress-bar"></div></div>
        </div>
      </div>
      <div class="vid-time" id="vid-time">0:00 / 0:00</div>
    </div>
  </div>
</div>

<script>
  const backgrounds = [
    '/assets/images/web_app_bg_1.jpg',
    '/assets/images/web_app_bg_2.jpg',
    '/assets/images/web_app_bg_3.jpg',
    '/assets/images/web_app_bg_4.jpg'
  ];
  let bgIndex = 0;
  
  function cycleBackground() {
    bgIndex = (bgIndex + 1) % backgrounds.length;
    document.body.style.backgroundImage = `url('${backgrounds[bgIndex]}')`;
  }

  let allMedia = [];
  let currentTab = 'video'; 
  let currentBrowsePath = '';
  let ws;
  const webClientId = localStorage.getItem('streamz_web_id') || ('WEB_' + Math.floor(Math.random() * 99999));
  localStorage.setItem('streamz_web_id', webClientId);
  let currentSessionId = '';
  let currentMediaTitle = '';
  let currentMediaType = '';
  let lastTelemetryTime = 0;

  const fallbacks = {
    video: '/assets/images/video_thumbnail.png',
    audio: '/assets/images/audio_thumbnail.png',
    image: '/assets/images/photo_thumbnail.png',
    file:  '/assets/images/video_thumbnail.png',
  };

  const tabMeta = {
    video:  { title: 'Video Archive', sub: 'Verified Server Node' },
    audio:  { title: 'Music Library', sub: 'Verified Server Node' },
    image:  { title: 'Photo Library', sub: 'Verified Server Node' },
    folder: { title: 'File Browser',  sub: 'Root Directory' },
  };

  function connectWS() {
    const host  = window.location.hostname || '127.0.0.1';
    const wsUrl = `ws://${host}:8080/ws`;
    ws = new WebSocket(wsUrl);
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
    if (action === 'scroll_down') { document.querySelector('.content-area').scrollTop += 300; return; }
    if (action === 'scroll_up')   { document.querySelector('.content-area').scrollTop -= 300; return; }
    if (action === 'back')        { closePlayer(); return; }
    const focusable = Array.from(document.querySelectorAll('[tabindex="0"], input, button, .media-card'));
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
    const active = vid.style.display === 'block' ? vid : (aud.src ? aud : null);
    if (!active) return;
    
    if (action === 'play' || action === 'pause' || action === 'toggle_play') { 
      active.paused ? active.play() : active.pause(); 
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
      (c.requestFullscreen || c.webkitRequestFullscreen).call(c);
    } else {
      (document.exitFullscreen || document.webkitExitFullscreen).call(document);
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
      switchTab('video'); 
    } catch(_) {
      document.getElementById('content-area').innerHTML = '<div class="empty-state"><i class="ph-light ph-wifi-slash"></i><span>Connection Lost</span></div>';
    }
  }

  function syncNavUI(type) {
    document.querySelectorAll('.dock-btn').forEach(b => b.classList.remove('active'));
    document.getElementById('nav-' + type).classList.add('active');
    document.getElementById('page-title').innerText    = tabMeta[type].title;
    document.getElementById('page-subtitle').innerText = currentBrowsePath
        ? 'Path // ' + currentBrowsePath
        : tabMeta[type].sub;
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
    else renderGrid(allMedia.filter(m => m.type === type));
  }

  function renderGrid(items) {
    const container = document.getElementById('content-area');
    container.className = 'grid-container';
    container.innerHTML = items.length === 0 ? '<div class="empty-state"><i class="ph-light ph-ghost"></i><span>No content found</span></div>' : '';
    items.forEach(item => {
      const card     = document.createElement('div');
      card.className = 'media-card';
      card.setAttribute('tabindex', '0');
      const thumb    = '/api/thumbnail/' + item.id;
      const fallback = fallbacks[item.type] || fallbacks.video;
      card.innerHTML = `
        <div class="card-thumb-wrap">
          <img class="card-thumb" src="${thumb}" onerror="this.src='${fallback}';this.onerror=null;">
          <button class="card-play-btn" onclick="event.stopPropagation(); openPlayer({id: '${item.id}', type: '${item.type}', title: '${item.title.replace(/'/g, "\\'")}'})"><i class="ph-fill ph-play"></i></button>
        </div>
        <div class="card-info">
          <div class="card-title" title="${item.title}">${item.title}</div>
          <a href="/stream/${item.id}" download="${item.title}" class="dl-icon" tabindex="-1" onclick="event.stopPropagation()"><i class="ph-bold ph-download-simple"></i></a>
        </div>`;
      card.onclick = () => openPlayer(item);
      container.appendChild(card);
    });
  }

  async function buildFolderView() {
    const container = document.getElementById('content-area');
    container.className = 'list-container';
    container.innerHTML = '<div class="empty-state"><i class="ph-light ph-spinner-gap ph-spin"></i><span>Reading directory...</span></div>';
    document.getElementById('page-subtitle').innerText = currentBrowsePath
        ? 'Path // ' + currentBrowsePath
        : 'Root Directory';
    try {
      const res   = await fetch('/api/browse?path=' + encodeURIComponent(currentBrowsePath));
      const items = await res.json();
      
      container.innerHTML = `
        <div class="list-header">
          <div style="text-align: center;">#</div>
          <div>Name</div>
          <div style="text-align: right;">Size</div>
          <div></div>
        </div>
      `;
      
      if (currentBrowsePath) {
        const back = document.createElement('div');
        back.className = 'media-row';
        back.setAttribute('tabindex', '0');
        back.innerHTML = '<div class="row-icon-wrap"><i class="ph-bold ph-arrow-u-up-left row-icon"></i></div><div class="row-title">Go Back</div><div></div><div></div>';
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
        row.className = 'media-row';
        row.setAttribute('tabindex', '0');
        if (item.isDirectory) {
          row.innerHTML = `<div class="row-icon-wrap"><i class="ph-fill ph-folder row-icon" style="color: #fff;"></i></div><div class="row-title">${item.name}</div><div></div><div></div>`;
          row.onclick   = () => { currentBrowsePath = item.path; buildFolderView(); };
        } else {
          const ext      = (item.name.split('.').pop() || '').toLowerCase();
          let typeKey    = 'file';
          if (['mp4','mkv','webm','avi'].includes(ext))      typeKey = 'video';
          if (['mp3','wav','m4a','aac','flac'].includes(ext)) typeKey = 'audio';
          if (['jpg','png','jpeg','webp'].includes(ext))      typeKey = 'image';
          const thumb    = '/api/thumbnail/' + encodeURIComponent(item.path);
          const fallback = fallbacks[typeKey] || fallbacks.file;
          
          let iconHtml = `<div class="row-icon-wrap"><i class="ph-light ph-file row-icon"></i></div>`;
          if (typeKey !== 'file') {
             iconHtml = `<div class="row-icon-wrap"><img class="row-art" src="${thumb}" onerror="this.src='${fallback}';this.onerror=null;"></div>`;
          }
          
          row.innerHTML = `
            ${iconHtml}
            <div class="row-title" title="${item.name}">${item.name}</div>
            <div class="row-meta">${(item.size/1024/1024).toFixed(1)} MB</div>
            <a href="/api/file?path=${encodeURIComponent(item.path)}" class="dl-icon" download="${item.name}" onclick="event.stopPropagation()"><i class="ph-bold ph-download-simple"></i></a>`;
          row.onclick = () => {
            if (typeKey !== 'file') openPlayer({ id: item.path, type: typeKey, title: item.name }, true);
            else window.open('/api/file?path=' + encodeURIComponent(item.path), '_blank');
          };
        }
        container.appendChild(row);
      });
    } catch(_) {
      container.innerHTML = '<div class="empty-state"><i class="ph-light ph-warning-circle"></i><span>Directory read failed</span></div>';
    }
  }

  function formatTime(secs) {
    if (isNaN(secs)) return "0:00";
    const m = Math.floor(secs / 60);
    const s = Math.floor(secs % 60).toString().padStart(2, '0');
    return `${m}:${s}`;
  }

  const aud = document.getElementById('audioPlayer');
  const vid = document.getElementById('videoPlayer');

  // Handle Pill Progress Fill Update
  aud.addEventListener('timeupdate', () => {
    if (!aud.duration) return;
    const progressPercent = (aud.currentTime / aud.duration * 100) + '%';
    document.getElementById('np-pill-progress').style.width = progressPercent;
    sendTelemetry(false, aud);
  });
  
  // Interactive Pill Seeking logic
  document.getElementById('np-pill-progress-wrap').addEventListener('click', (e) => {
    const wrap = document.getElementById('np-pill-progress-wrap');
    const r = wrap.getBoundingClientRect();
    if (aud.duration) aud.currentTime = ((e.clientX - r.left) / r.width) * aud.duration;
  });

  vid.addEventListener('timeupdate', () => {
    if (!vid.duration) return;
    document.getElementById('vid-progress-bar').style.width = (vid.currentTime / vid.duration * 100) + '%';
    document.getElementById('vid-time').innerText = `${formatTime(vid.currentTime)} / ${formatTime(vid.duration)}`;
    sendTelemetry(false, vid);
  });
  
  document.querySelector('#vid-progress .progress-bar-wrap').addEventListener('click', (e) => {
    const wrap = document.querySelector('#vid-progress .progress-bar-wrap');
    const r = wrap.getBoundingClientRect();
    if (vid.duration) vid.currentTime = ((e.clientX - r.left) / r.width) * vid.duration;
  });

  window.addEventListener('beforeunload', () => sendTelemetry(true, null));

  function openPlayer(item, isPath = false) {
    if (currentSessionId) sendTelemetry(true, null);
    currentSessionId  = 'SESSION_' + Date.now();
    currentMediaTitle = item.title;
    currentMediaType  = item.type;
    const url = isPath ? '/api/file?path=' + encodeURIComponent(item.id) : '/stream/' + item.id;

    if (item.type === 'audio') {
      aud.src = url;
      aud.play();
      document.getElementById('np-label').innerText = 'Spatial Audio Active';
      document.getElementById('np-title').innerText = item.title;
      const art = document.getElementById('np-art-img');
      art.style.display = 'block';
      art.src = isPath
          ? '/api/thumbnail/' + encodeURIComponent(item.id)
          : '/api/thumbnail/' + item.id;
      art.onerror = () => { art.src = fallbacks.audio; art.onerror = null; };
      updatePlayBtn(false);
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
      vid.play();
      updatePlayBtn(false);
    } else if (item.type === 'image') {
      img.src = url;
      img.style.display = 'block';
    }
  }

  function closePlayer() {
    if (document.fullscreenElement || document.webkitFullscreenElement) {
      (document.exitFullscreen || document.webkitExitFullscreen).call(document);
    }
    document.getElementById('fsOverlay').classList.remove('active');
    sendTelemetry(true, null);
    vid.pause(); vid.src = '';
    if (!aud.paused) {
      aud.pause(); aud.src = '';
      document.getElementById('np-label').innerText = 'Awaiting signal';
      document.getElementById('np-title').innerText = 'Nothing playing';
      document.getElementById('np-pill-progress').style.width = '0%'; // Reset progress fill
    }
  }

  function toggleMedia() {
    const active = vid.style.display === 'block' ? vid : aud;
    if (!active.src) return;
    if (active.paused) { active.play(); updatePlayBtn(false); }
    else               { active.pause(); updatePlayBtn(true); }
  }

  function updatePlayBtn(isPaused) {
    const iconClass = isPaused ? 'ph-play' : 'ph-pause';
    document.getElementById('globalPlayPause').innerHTML = `<i class="ph-fill ${iconClass}"></i>`;
    document.getElementById('vidPlayBtn').innerHTML = `<i class="ph-fill ${iconClass}"></i>`;
  }

  function seekGlobal(s) {
    const active = vid.style.display === 'block' ? vid : aud;
    if (active.src) active.currentTime += s;
  }

  init();
</script>
</body>
</html>
""";
