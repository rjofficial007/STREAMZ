// data/network/modern_web_html.dart
// ============================================================================
// STREAMZ — Built-in Web Interface HTML (Spatial UI - Pro Edition)
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
    /* Refined Spatial Glass Material */
    --glass-base: rgba(20, 20, 20, 0.4);
    --glass-hover: rgba(255, 255, 255, 0.15);
    --glass-active: rgba(255, 255, 255, 0.25);
    
    --glass-border: rgba(255, 255, 255, 0.15);
    --glass-highlight: inset 0 1px 1px rgba(255, 255, 255, 0.2), inset 0 0 20px rgba(255, 255, 255, 0.05);
    
    --blur-spatial: blur(40px) saturate(180%);
    
    --text-primary: #ffffff;
    --text-secondary: rgba(255, 255, 255, 0.7);
    --text-muted: rgba(255, 255, 255, 0.45);
    
    --accent: #ffffff;
    
    --radius-sm: 12px;
    --radius-md: 24px;
    --radius-lg: 40px;
    --radius-pill: 999px;
    
    --shadow-spatial: 0 40px 100px -20px rgba(0, 0, 0, 0.8), 0 0 1px rgba(255, 255, 255, 0.1);
    --shadow-float: 0 20px 50px rgba(0, 0, 0, 0.5);
    
    --transition: 0.5s cubic-bezier(0.16, 1, 0.3, 1);
  }
  
  * { box-sizing: border-box; margin: 0; padding: 0; }
  
  body {
    background-color: #000;
    background-image: url('https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&q=80&w=2560');
    background-size: cover;
    background-position: center;
    background-attachment: fixed;
    transition: background-image 1.2s cubic-bezier(0.16, 1, 0.3, 1);
    color: var(--text-primary);
    font-family: 'Inter', -apple-system, sans-serif;
    font-weight: 400;
    overflow: hidden;
    height: 100vh;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 32px;
    -webkit-font-smoothing: antialiased;
  }

  ::-webkit-scrollbar { width: 4px; }
  ::-webkit-scrollbar-track { background: transparent; }
  ::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.3); border-radius: 10px; }
  ::-webkit-scrollbar-thumb:hover { background: rgba(255,255,255,0.6); }

  /* ── SPATIAL PANELS ────────────────────────────────────────────────────── */

  .spatial-panel {
    background: var(--glass-base);
    backdrop-filter: var(--blur-spatial);
    -webkit-backdrop-filter: var(--blur-spatial);
    border: 1px solid var(--glass-border);
    box-shadow: var(--shadow-spatial), var(--glass-highlight);
  }

  .spatial-layout {
    position: relative;
    width: 100%;
    max-width: 1440px;
    height: 100%;
    max-height: 900px;
    display: flex;
    align-items: stretch;
    gap: 32px;
    animation: layoutIn 0.8s cubic-bezier(0.16, 1, 0.3, 1);
  }

  @keyframes layoutIn {
    from { opacity: 0; transform: translateY(40px) scale(0.98); }
    to { opacity: 1; transform: translateY(0) scale(1); }
  }

  /* 1. Floating Side Dock */
  .left-dock {
    width: 80px;
    height: max-content;
    align-self: center;
    border-radius: var(--radius-pill);
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 32px 0;
    gap: 20px;
    z-index: 100;
    flex-shrink: 0;
  }

  .dock-btn {
    position: relative;
    width: 52px;
    height: 52px;
    border-radius: 50%;
    background: transparent;
    border: 1px solid transparent;
    color: var(--text-secondary);
    font-size: 26px;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
    outline: none;
  }
  
  .dock-btn:hover { background: var(--glass-hover); color: var(--text-primary); transform: scale(1.15) translateZ(20px); }
  .dock-btn.active { background: #fff; color: #000; box-shadow: 0 10px 30px rgba(255,255,255,0.3); }

  .dock-divider {
    width: 32px;
    height: 1px;
    background: rgba(255,255,255,0.1);
    margin: 4px 0;
  }

  /* Spatial Tooltips */
  .dock-btn::after {
    content: attr(data-tooltip);
    position: absolute;
    left: calc(100% + 24px);
    background: rgba(255, 255, 255, 0.95);
    padding: 8px 16px;
    border-radius: 12px;
    font-size: 13px;
    font-weight: 700;
    color: #000;
    white-space: nowrap;
    opacity: 0;
    transform: translateX(-15px);
    pointer-events: none;
    transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1);
    box-shadow: 0 20px 40px rgba(0,0,0,0.4);
    z-index: 200;
  }
  .dock-btn:hover::after { opacity: 1; transform: translateX(0); }

  /* 2. Center Column */
  .center-column {
    flex-grow: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 32px;
    overflow: hidden;
  }

  /* 3. Floating Top Bar */
  .top-bar {
    width: 100%;
    max-width: 800px;
    height: 64px;
    border-radius: var(--radius-pill);
    display: flex;
    align-items: center;
    padding: 0 8px 0 32px;
    gap: 32px;
    flex-shrink: 0;
  }

  .search-container { position: relative; flex-grow: 1; }
  .search-container i { position: absolute; left: 0; top: 50%; transform: translateY(-50%); color: var(--text-muted); font-size: 20px; }
  .search-box {
    width: 100%;
    background: transparent;
    border: none;
    color: var(--text-primary);
    font-family: inherit;
    font-size: 15px;
    font-weight: 500;
    padding: 12px 16px 12px 32px;
    outline: none;
  }
  .search-box::placeholder { color: var(--text-muted); }

  .user-pill {
    display: flex;
    align-items: center;
    gap: 12px;
    background: rgba(255,255,255,0.1);
    padding: 6px 20px 6px 8px;
    border-radius: var(--radius-pill);
    font-size: 13px;
    font-weight: 700;
    letter-spacing: 1px;
    border: 1px solid rgba(255,255,255,0.1);
    cursor: pointer;
    transition: all 0.3s;
  }
  .user-pill:hover { background: rgba(255,255,255,0.2); transform: scale(1.05); }
  .user-pill .avatar { width: 32px; height: 32px; border-radius: 50%; background: #fff; display: flex; align-items: center; justify-content: center; color: #000; font-size: 18px; }

  /* 4. Main Window */
  .main-window {
    width: 100%;
    flex-grow: 1;
    border-radius: var(--radius-lg);
    display: flex;
    flex-direction: column;
    overflow: hidden;
    animation: windowFade 0.6s 0.2s cubic-bezier(0.16, 1, 0.3, 1) both;
  }
  @keyframes windowFade { from { opacity: 0; transform: scale(0.99); } to { opacity: 1; transform: scale(1); } }

  .content-area {
    flex-grow: 1;
    overflow-y: auto;
    padding: 40px 48px;
    scroll-behavior: smooth;
  }

  .page-header { margin-bottom: 40px; display: flex; flex-direction: column; gap: 4px; }
  .page-title { font-size: 32px; font-weight: 800; letter-spacing: -1px; }
  .page-meta { font-size: 12px; color: var(--text-secondary); font-weight: 600; text-transform: uppercase; letter-spacing: 2px; }

  /* BORDERLESS GRID */
  .grid-container {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); 
    gap: 32px 24px;
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
    transition: transform 0.4s cubic-bezier(0.16, 1, 0.3, 1);
  }
  .media-card:hover, .media-card:focus { transform: scale(1.05) translateY(-8px); }

  .card-thumb-wrap {
    width: 100%;
    aspect-ratio: 1;
    border-radius: var(--radius-md); 
    margin-bottom: 16px;
    overflow: hidden;
    position: relative;
    background: rgba(255,255,255,0.05);
    border: 1px solid rgba(255,255,255,0.1); 
    box-shadow: 0 15px 35px rgba(0,0,0,0.5);
    transition: all 0.4s;
  }

  .card-thumb { width: 100%; height: 100%; object-fit: cover; transition: transform 0.8s cubic-bezier(0.16, 1, 0.3, 1); }
  
  .card-thumb-wrap::after {
    content: '';
    position: absolute;
    inset: 0;
    background: linear-gradient(to bottom, transparent 40%, rgba(0,0,0,0.8) 100%);
    opacity: 0;
    transition: opacity 0.4s;
  }
  
  .media-card:hover .card-thumb { transform: scale(1.15); }
  .media-card:hover .card-thumb-wrap::after { opacity: 1; }
  .media-card:hover .card-thumb-wrap { border-color: rgba(255,255,255,0.3); box-shadow: 0 25px 60px rgba(0,0,0,0.7); }

  .card-play-btn {
    position: absolute;
    inset: 0;
    margin: auto;
    width: 56px;
    height: 56px;
    border-radius: 50%;
    background: #fff;
    color: #000;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 24px;
    opacity: 0;
    transform: scale(0.6) rotate(-20deg);
    transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1);
    cursor: pointer;
    box-shadow: 0 15px 30px rgba(0,0,0,0.4);
    z-index: 10;
  }
  .media-card:hover .card-play-btn, .media-card:focus .card-play-btn { opacity: 1; transform: scale(1) rotate(0deg); }

  .card-info { padding: 0 8px; display: flex; align-items: center; justify-content: space-between; gap: 12px; }
  .card-title { font-size: 15px; font-weight: 600; color: var(--text-primary); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; flex-grow: 1; }
  .dl-icon { color: var(--text-muted); font-size: 20px; transition: all 0.3s; text-decoration: none; flex-shrink: 0; }
  .dl-icon:hover { color: #fff; transform: translateY(-2px); }

  /* List View */
  .list-container { display: flex; flex-direction: column; gap: 8px; }
  .list-header, .media-row {
    display: grid;
    grid-template-columns: 64px 1fr 120px 48px; 
    align-items: center;
    gap: 20px;
  }
  .list-header {
    padding: 0 24px 16px 24px;
    border-bottom: 1px solid rgba(255,255,255,0.1);
    margin-bottom: 8px;
    color: var(--text-muted);
    font-size: 12px;
    font-weight: 700;
    letter-spacing: 2px;
    text-transform: uppercase;
  }
  .media-row {
    padding: 12px 24px;
    border-radius: var(--radius-md);
    background: transparent;
    cursor: pointer;
    transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
    outline: none;
  }
  .media-row:hover, .media-row:focus { background: rgba(255,255,255,0.08); transform: translateX(8px); }

  .row-art { width: 48px; height: 48px; border-radius: 12px; object-fit: cover; box-shadow: 0 8px 16px rgba(0,0,0,0.3); }
  .row-title { font-size: 15px; font-weight: 600; color: var(--text-primary); }
  .row-meta { font-size: 14px; color: var(--text-secondary); text-align: right; font-variant-numeric: tabular-nums; }

  /* Station Card */
  .station-card {
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid var(--glass-border);
    border-radius: var(--radius-md);
    padding: 24px;
    cursor: pointer;
    transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
    display: flex;
    flex-direction: column;
    gap: 16px;
  }
  .station-card:hover { transform: translateY(-8px); background: rgba(255, 255, 255, 0.1); border-color: var(--accent); }
  .station-header { display: flex; justify-content: space-between; align-items: flex-start; }
  .station-name { font-size: 18px; font-weight: 800; letter-spacing: 1px; }
  .live-badge { background: #ff4b4b; color: #fff; font-size: 10px; font-weight: 900; padding: 2px 8px; border-radius: 4px; letter-spacing: 1px; }
  .station-meta { display: flex; flex-direction: column; gap: 4px; }
  .now-playing-label { font-size: 10px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; letter-spacing: 1px; }
  .now-playing-title { font-size: 14px; font-weight: 600; color: var(--accent); }

  /* Empty State */
  .empty-state { display: flex; flex-direction: column; align-items: center; justify-content: center; height: 50vh; color: var(--text-muted); gap: 20px; }
  .empty-state i { font-size: 80px; opacity: 0.3; }
  .empty-state span { font-weight: 700; font-size: 18px; letter-spacing: 1px; }

  /* ── 5. FLOATING PLAYER ─────────────────────────────────────────────── */
  
  .player-console {
    width: 100%;
    max-width: 900px;
    height: 88px;
    border-radius: var(--radius-pill);
    display: flex;
    align-items: center;
    padding: 0 12px 0 12px;
    gap: 24px;
    flex-shrink: 0;
    margin-bottom: 8px;
    animation: playerIn 0.8s 0.4s cubic-bezier(0.16, 1, 0.3, 1) both;
  }
  @keyframes playerIn { from { opacity: 0; transform: translateY(40px); } to { opacity: 1; transform: translateY(0); } }
  
  .ctrl-btn {
    width: 56px;
    height: 56px;
    border-radius: 50%;
    background: transparent;
    border: none;
    color: #fff;
    font-size: 26px;
    cursor: pointer;
    transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
    display: flex;
    align-items: center;
    justify-content: center;
    outline: none;
  }
  .ctrl-btn:hover { background: var(--glass-hover); transform: scale(1.15); }
  .ctrl-btn.play { background: #fff; color: #000; box-shadow: 0 15px 30px rgba(255,255,255,0.2); }
  .ctrl-btn.play:hover { background: #fff; transform: scale(1.1); }

  .now-playing-pill {
    flex-grow: 1;
    height: 64px;
    display: flex;
    align-items: center;
    background: rgba(0, 0, 0, 0.3);
    border: 1px solid rgba(255,255,255,0.08);
    border-radius: var(--radius-pill);
    padding: 0 24px 0 10px;
    gap: 20px;
    overflow: hidden; 
    cursor: pointer;
    position: relative;
  }

  .np-progress-bg {
    position: absolute;
    left: 0;
    top: 0;
    bottom: 0;
    width: 0%;
    background: rgba(255, 255, 255, 0.15); 
    z-index: 0;
    pointer-events: none;
    transition: width 0.1s linear;
  }

  .np-art, .np-info { z-index: 1; }
  .np-art { width: 44px; height: 44px; border-radius: 12px; overflow: hidden; background: rgba(0,0,0,0.5); flex-shrink: 0; }
  .np-art img { width: 100%; height: 100%; object-fit: cover; }
  .np-info { display: flex; flex-direction: column; overflow: hidden; flex-grow: 1; }
  .np-title { font-size: 15px; font-weight: 700; color: #fff; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .np-label { font-size: 12px; color: var(--text-secondary); font-weight: 500; text-transform: uppercase; letter-spacing: 1px; }

  /* ── FULLSCREEN OVERLAY ────────────────────────────────────────────────── */

  .fs-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0,0,0,0.7);
    backdrop-filter: blur(80px) saturate(150%);
    -webkit-backdrop-filter: blur(80px) saturate(150%);
    z-index: 3000;
    display: none;
    align-items: center;
    justify-content: center;
  }
  .fs-overlay.active { display: flex; animation: fsIn 0.6s cubic-bezier(0.16, 1, 0.3, 1); }
  @keyframes fsIn { from { opacity: 0; transform: scale(1.1); } to { opacity: 1; transform: scale(1); } }

  .video-container { width: 100%; height: 100%; position: relative; display: flex; align-items: center; justify-content: center; padding: 64px; }
  .window-controls { position: absolute; top: 40px; right: 40px; display: flex; gap: 20px; z-index: 3001; }

  .overlay-btn {
    width: 60px; height: 60px; border-radius: 50%; background: rgba(255,255,255,0.1); backdrop-filter: blur(30px); border: 1px solid rgba(255,255,255,0.2);
    color: #fff; font-size: 26px; cursor: pointer; display: flex; align-items: center; justify-content: center; transition: all 0.3s;
  }
  .overlay-btn:hover { background: rgba(255,255,255,0.25); transform: scale(1.1); }

  video { max-width: 100%; max-height: 100%; object-fit: contain; border-radius: 32px; box-shadow: 0 80px 150px rgba(0,0,0,0.8); }
  img#fs-img { max-width: 100%; max-height: 100%; object-fit: contain; border-radius: 32px; box-shadow: 0 80px 150px rgba(0,0,0,0.8); }

  .vid-controls-overlay {
    position: absolute;
    bottom: 60px;
    left: 50%;
    transform: translateX(-50%);
    width: 100%;
    max-width: 800px;
    background: rgba(255, 255, 255, 0.1);
    backdrop-filter: blur(50px);
    -webkit-backdrop-filter: blur(50px);
    border: 1px solid rgba(255,255,255,0.2);
    border-radius: var(--radius-pill);
    padding: 12px 12px 12px 32px;
    opacity: 0;
    transition: opacity 0.5s cubic-bezier(0.16, 1, 0.3, 1);
    z-index: 3002;
    display: flex;
    align-items: center;
    gap: 32px;
    box-shadow: 0 40px 100px rgba(0,0,0,0.6);
  }
  .video-container:hover .vid-controls-overlay { opacity: 1; }
  
  .vid-time { font-size: 14px; font-weight: 700; font-variant-numeric: tabular-nums; color: #fff; width: 140px; text-align: right; }
  
  .progress-container { flex-grow: 1; display: flex; align-items: center; cursor: pointer; height: 40px; }
  .progress-bg { width: 100%; height: 8px; background: rgba(255,255,255,0.15); border-radius: var(--radius-pill); position: relative; overflow: hidden; }
  .progress-fill { height: 100%; width: 0%; background: #fff; border-radius: var(--radius-pill); transition: width 0.1s linear; }
</style>
</head>
<body>

<div class="spatial-layout">
  
  <nav class="left-dock spatial-panel">
    <button class="dock-btn active" id="nav-video" onclick="switchTab('video')" data-tooltip="Videos">
      <i class="ph-fill ph-video-camera"></i>
    </button>
    <button class="dock-btn" id="nav-audio" onclick="switchTab('audio')" data-tooltip="Music">
      <i class="ph-fill ph-music-note"></i>
    </button>
    <button class="dock-btn" id="nav-image" onclick="switchTab('image')" data-tooltip="Photos">
      <i class="ph-fill ph-image"></i>
    </button>
    <button class="dock-btn" id="nav-station" onclick="switchTab('station')" data-tooltip="Stations">
      <i class="ph-fill ph-radio"></i>
    </button>
    <button class="dock-btn" id="nav-folder" onclick="switchTab('folder')" data-tooltip="Files">
      <i class="ph-fill ph-folder"></i>
    </button>
    <div class="dock-divider"></div>
    <button class="dock-btn" onclick="cycleBackground()" data-tooltip="Next Env">
      <i class="ph-bold ph-aperture"></i>
    </button>
  </nav>

  <div class="center-column">
    
    <header class="top-bar spatial-panel">
      <div class="search-container">
        <i class="ph-bold ph-magnifying-glass"></i>
        <input type="text" class="search-box" id="searchInput" placeholder="Search library..." oninput="handleSearch()">
      </div>
      <div class="user-pill">
        <div class="avatar"><i class="ph-fill ph-planet"></i></div>
        STUDIO NODE
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
      <div class="player-controls">
        <button class="ctrl-btn" onclick="seekGlobal(-10)"><i class="ph-fill ph-rewind"></i></button>
      </div>

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
      
      <div class="player-controls">
        <button class="ctrl-btn play" onclick="toggleMedia()" id="globalPlayPause"><i class="ph-fill ph-pause"></i></button>
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
      <button class="ctrl-btn play" style="width: 48px; height: 48px; font-size: 24px;" onclick="toggleMedia()" id="vidPlayBtn"><i class="ph-fill ph-pause"></i></button>
      <div class="progress-container" id="vid-progress">
        <div class="progress-bg"><div class="progress-fill" id="vid-progress-bar"></div></div>
      </div>
      <div class="vid-time" id="vid-time">0:00 / 0:00</div>
    </div>
  </div>
</div>

<script>
  const backgrounds = [
    'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&q=80&w=2560',
    'https://images.unsplash.com/photo-1620641788421-7a1c342ea42e?auto=format&fit=crop&q=80&w=2560',
    'https://images.unsplash.com/photo-1614850523296-d8c1af93d400?auto=format&fit=crop&q=80&w=2560',
    'https://images.unsplash.com/photo-1550684848-fac1c5b4e853?auto=format&fit=crop&q=80&w=2560'
  ];
  let bgIndex = 0;
  
  function cycleBackground() {
    bgIndex = (bgIndex + 1) % backgrounds.length;
    document.body.style.backgroundImage = `url('${backgrounds[bgIndex]}')`;
  }

  let allMedia = [];
  let allStations = [];
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
    video:   { title: 'Video Archive',  sub: 'Verified Server Node' },
    audio:   { title: 'Music Library',  sub: 'High Fidelity Node' },
    image:   { title: 'Photo Library',  sub: 'Visual Asset Node' },
    station: { title: 'Live Stations', sub: 'Linear Broadcast Feed' },
    folder:  { title: 'File System',    sub: 'Network Directory' },
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
    if (currentTab === 'folder' || currentTab === 'station') return;
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

  async function buildStationView() {
    const container = document.getElementById('content-area');
    container.className = 'grid-container';
    container.innerHTML = '<div class="empty-state"><i class="ph-light ph-spinner-gap ph-spin"></i><span>Tuning in...</span></div>';
    try {
      const res = await fetch('/api/stations');
      allStations = await res.json();
      container.innerHTML = allStations.length === 0 ? '<div class="empty-state"><i class="ph-light ph-radio"></i><span>No active broadcasts</span></div>' : '';
      allStations.forEach(s => {
        const card = document.createElement('div');
        card.className = 'station-card';
        card.setAttribute('tabindex', '0');
        const nowPlaying = s.nowPlaying ? s.nowPlaying.item.title.toUpperCase() : 'AWAITING SIGNAL';
        card.innerHTML = `
          <div class="station-header">
            <div class="station-name">${s.name.toUpperCase()}</div>
            <div class="live-badge">LIVE</div>
          </div>
          <div class="station-meta">
            <div class="now-playing-label">Now Playing</div>
            <div class="now-playing-title">${nowPlaying}</div>
          </div>
        `;
        card.onclick = () => joinStation(s.id);
        container.appendChild(card);
      });
    } catch(_) {
      container.innerHTML = '<div class="empty-state"><i class="ph-light ph-warning-circle"></i><span>Failed to load stations</span></div>';
    }
  }

  async function joinStation(id) {
    try {
      const res = await fetch('/api/stations/join/' + id);
      const data = await res.json();
      const item = data.item;
      const pos = data.positionMs / 1000;
      openPlayer({ id: item.id, type: item.type, title: item.title }, true, pos);
    } catch(_) {
      alert('Failed to join station');
    }
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

  aud.addEventListener('timeupdate', () => {
    if (!aud.duration) return;
    const progressPercent = (aud.currentTime / aud.duration * 100) + '%';
    document.getElementById('np-pill-progress').style.width = progressPercent;
    sendTelemetry(false, aud);
  });
  
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
  
  document.getElementById('vid-progress').addEventListener('click', (e) => {
    const wrap = document.getElementById('vid-progress');
    const r = wrap.getBoundingClientRect();
    if (vid.duration) vid.currentTime = ((e.clientX - r.left) / r.width) * vid.duration;
  });

  window.addEventListener('beforeunload', () => sendTelemetry(true, null));

  function openPlayer(item, isPath = false, startOffset = 0) {
    if (currentSessionId) sendTelemetry(true, null);
    currentSessionId  = 'SESSION_' + Date.now();
    currentMediaTitle = item.title;
    currentMediaType  = item.type;
    const url = isPath ? '/api/file?path=' + encodeURIComponent(item.id) : '/stream/' + item.id;

    if (item.type === 'audio') {
      aud.src = url;
      if (startOffset > 0) aud.currentTime = startOffset;
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
      if (startOffset > 0) vid.currentTime = startOffset;
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
      document.getElementById('np-pill-progress').style.width = '0%';
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
