// data/network/web_html.dart
// ============================================================================
// STREAMZ — Built-in Web Interface HTML
// ============================================================================

const String kWebInterfaceHtml = r"""
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>STREAMZ // STUDIO</title>
<link href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:ital,wght@0,100;0,300;0,700;0,900;1,100;1,700&family=DM+Mono:ital,wght@0,300;0,400;1,300&family=Barlow:wght@300;400;500&display=swap" rel="stylesheet">
<style>
  :root {
    --black: #000000;
    --white: #ffffff;
    --white-dim: rgba(255,255,255,0.04);
    --white-mid: rgba(255,255,255,0.12);
    --white-border: rgba(255,255,255,0.15);
    --white-text: rgba(255,255,255,0.5);
    --white-muted: rgba(255,255,255,0.3);
    --surface: #0a0a0a;
    --surface-2: #111111;
    --font-display: 'Barlow Condensed', sans-serif;
    --font-mono: 'DM Mono', monospace;
    --font-body: 'Barlow', sans-serif;
    --transition-snap: 0.2s cubic-bezier(0.16, 1, 0.3, 1);
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background-color: var(--black);
    color: var(--white);
    font-family: var(--font-body);
    font-weight: 300;
    overflow: hidden;
    height: 100vh;
    display: flex;
    flex-direction: column;
    cursor: crosshair;
    -webkit-font-smoothing: antialiased;
  }
  ::-webkit-scrollbar { width: 4px; }
  ::-webkit-scrollbar-track { background: var(--black); }
  ::-webkit-scrollbar-thumb { background: var(--white-border); }
  ::-webkit-scrollbar-thumb:hover { background: var(--white); }

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
    font-weight: 900;
    letter-spacing: 4px;
    color: var(--white);
    text-transform: uppercase;
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
    letter-spacing: 2px;
    text-transform: uppercase;
    cursor: crosshair;
    transition: all var(--transition-snap);
    outline: none;
  }
  .nav-btn:hover, .nav-btn:focus { background: var(--white-dim); color: var(--white); }
  .nav-btn.active { background: var(--white); color: var(--black); font-weight: 400; }
  .search-container { display: flex; align-items: center; min-width: 300px; background: var(--black); }
  .search-box {
    background: transparent;
    border: none;
    color: var(--white);
    font-family: var(--font-mono);
    font-size: 11px;
    letter-spacing: 1px;
    width: 100%;
    height: 100%;
    padding: 0 32px;
    outline: none;
    text-transform: uppercase;
  }
  .search-box::placeholder { color: var(--white-muted); }
  .search-box:focus { background: var(--white-dim); }

  .workspace { display: flex; flex-grow: 1; overflow: hidden; position: relative; }
  .content-area {
    flex-grow: 1;
    padding: 30px;
    overflow-y: auto;
    position: relative;
  }
  .page-header { margin-bottom: 48px; display: flex; justify-content: space-between; align-items: flex-end; }
  .page-title {
    font-family: var(--font-display);
    font-size: clamp(28px, 6vw, 64px);
    font-weight: 900;
    letter-spacing: -1px;
    line-height: 0.9;
    text-transform: uppercase;
  }
  .page-meta {
    font-family: var(--font-mono);
    color: var(--white-muted);
    font-size: 11px;
    letter-spacing: 2px;
    text-transform: uppercase;
    text-align: right;
    padding-bottom: 8px;
  }

  .grid-container {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
    gap: 1px;
    background: var(--white-border);
    border: 1px solid var(--white-border);
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
    height: 75%;
    position: relative;
    overflow: hidden;
    border-bottom: 1px solid var(--white-border);
  }
  .card-poster {
    width: 100%;
    height: 100%;
    object-fit: cover;
    filter: opacity(0.6);
    transition: filter var(--transition-snap), transform 0.6s cubic-bezier(0.16, 1, 0.3, 1);
  }
  .card:hover .card-poster, .card:focus .card-poster {
    filter: opacity(1);
    transform: scale(1.05);
  }
  .card-info { padding: 0 20px; display: flex; justify-content: space-between; align-items: center; height: 25%; }
  .card-title {
    font-family: var(--font-mono);
    font-size: 11px;
    letter-spacing: 1px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    color: var(--white-text);
    text-transform: uppercase;
  }
  .card:hover .card-title, .card:focus .card-title { color: var(--black); font-weight: 400; }
  .action-btn {
    color: var(--white-muted);
    text-decoration: none;
    font-family: var(--font-mono);
    font-size: 10px;
    letter-spacing: 2px;
    outline: none;
    text-transform: uppercase;
  }
  .card:hover .action-btn, .card:focus .action-btn { color: var(--black); font-weight: bold; }

  .list-container { display: flex; flex-direction: column; border-top: 1px solid var(--white-border); }
  .list-item {
    display: flex;
    align-items: center;
    padding: 16px 24px;
    border-bottom: 1px solid var(--white-border);
    background: transparent;
    cursor: crosshair;
    transition: all var(--transition-snap);
    outline: none;
  }
  .list-item:hover, .list-item:focus { background: var(--white); color: var(--black); }
  .list-index { font-family: var(--font-mono); width: 60px; font-size: 10px; color: var(--white-muted); letter-spacing: 2px; }
  .list-item:hover .list-index, .list-item:focus .list-index { color: var(--black); }
  .list-art { width: 32px; height: 32px; object-fit: cover; margin-right: 24px; filter: opacity(0.5); border: 1px solid var(--white-border); }
  .list-item:hover .list-art { filter: opacity(1); }
  .list-title { flex-grow: 1; font-family: var(--font-mono); font-size: 12px; letter-spacing: 1px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; text-transform: uppercase; }
  .list-meta { font-family: var(--font-mono); font-size: 10px; width: 120px; text-align: right; margin-right: 32px; color: var(--white-text); letter-spacing: 1px; }
  .list-item:hover .list-meta { color: var(--black); }
  .list-download-icon { color: var(--white-text); text-decoration: none; font-family: var(--font-mono); font-size: 10px; letter-spacing: 2px; outline: none; text-transform: uppercase; }
  .list-item:hover .list-download-icon { color: var(--black); font-weight: bold; }

  /* Progress indicator on cards */
  .card-progress {
    position: absolute;
    bottom: 25%;
    left: 0;
    right: 0;
    height: 3px;
    background: rgba(255,255,255,0.1);
  }
  .card-progress-bar { height: 100%; background: var(--white); }

  .player-console {
    height: 90px;
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
    padding: 0 30px;
    display: flex;
    align-items: center;
    gap: 32px;
  }
  .lcd-art { width: 52px; height: 52px; border: 1px solid var(--white-border); overflow: hidden; }
  .lcd-art img { width: 100%; height: 100%; object-fit: cover; }
  .lcd-data { display: flex; flex-direction: column; justify-content: center; flex-grow: 1; }
  .lcd-label { font-family: var(--font-mono); font-size: 9px; letter-spacing: 3px; color: var(--white-muted); margin-bottom: 6px; text-transform: uppercase; }
  .lcd-title { font-family: var(--font-display); font-size: 28px; font-weight: 700; color: var(--white); line-height: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; text-transform: uppercase; letter-spacing: 1px; }
  .lcd-progress-wrapper { height: 4px; background: rgba(255,255,255,0.1); margin-top: 12px; width: 100%; position: relative; display: none; cursor: crosshair; }
  .lcd-progress-wrapper:hover { background: rgba(255,255,255,0.2); }
  .lcd-progress-bar { height: 100%; width: 0%; background: var(--white); pointer-events: none; }

  .hardware-controls { display: flex; align-items: stretch; }
  .hw-btn {
    width: 90px;
    background: transparent;
    border: none;
    border-left: 1px solid var(--white-border);
    color: var(--white-text);
    font-family: var(--font-mono);
    font-size: 11px;
    letter-spacing: 2px;
    cursor: crosshair;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all var(--transition-snap);
    outline: none;
    text-transform: uppercase;
  }
  .hw-btn:hover, .hw-btn:focus { background: var(--white-dim); color: var(--white); }
  .hw-btn.play { width: 120px; background: var(--white); color: var(--black); font-weight: bold; }
  .hw-btn.play:hover, .hw-btn.play:focus { background: rgba(255,255,255,0.8); }

  .fs-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0,0,0,0.92);
    z-index: 2000;
    display: none;
    align-items: center;
    justify-content: center;
  }
  .fs-overlay.active { display: flex; animation: fadeIn 0.25s ease; }
  @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }

  .video-container {
    width: 90vw;
    height: 90vh;
    border: 1px solid var(--white-border);
    position: relative;
    background: var(--black);
    overflow: hidden;
  }
  .video-container:fullscreen { width: 100vw; height: 100vh; border: none; }
  .video-container:-webkit-full-screen { width: 100vw; height: 100vh; border: none; }

  .window-controls { position: absolute; top: 0; right: 0; display: flex; z-index: 2001; }
  .window-btn {
    width: 60px;
    height: 60px;
    background: var(--white);
    color: var(--black);
    font-family: var(--font-mono);
    font-size: 14px;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: crosshair;
    border: none;
    outline: none;
    border-left: 1px solid var(--black);
    transition: opacity 0.15s;
  }
  .window-btn:hover { opacity: 0.8; }

  video { width: 100%; height: 100%; object-fit: contain; outline: none; cursor: crosshair; }
  img#fs-img { width: 100%; height: 100%; object-fit: contain; }

  .vid-controls-overlay {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: 90px;
    background: linear-gradient(to top, rgba(0,0,0,0.9), transparent);
    display: flex;
    align-items: center;
    padding: 0 40px;
    gap: 24px;
    opacity: 0;
    transition: opacity 0.3s ease;
    z-index: 2002;
  }
  .video-container:hover .vid-controls-overlay { opacity: 1; }

  .empty-state {
    padding: 120px 20px;
    text-align: center;
    color: var(--white-muted);
    font-family: var(--font-mono);
    font-size: 12px;
    letter-spacing: 4px;
    text-transform: uppercase;
    border: 1px dashed var(--white-border);
    margin-top: 20px;
  }
</style>
</head>
<body>

<div class="top-dashboard">
  <div class="branding"><div class="brand-title">STREAMZ</div></div>
  <div class="nav-switches">
    <button class="nav-btn active" id="nav-video" onclick="switchTab('video')">VIDEOS</button>
    <button class="nav-btn" id="nav-audio" onclick="switchTab('audio')">AUDIO</button>
    <button class="nav-btn" id="nav-image" onclick="switchTab('image')">PHOTOS</button>
    <button class="nav-btn" id="nav-folder" onclick="switchTab('folder')">NETWORK</button>
  </div>
  <div class="search-container">
    <input type="text" class="search-box" id="searchInput" placeholder="Query Matrix..." oninput="handleSearch()">
  </div>
</div>

<div class="workspace">
  <div class="content-area">
    <div class="page-header">
      <div class="page-title" id="page-title">VIDEO ARCHIVE</div>
      <div class="page-meta" id="page-subtitle">PATH // ROOT/MEDIA</div>
    </div>
    <div id="content-area"></div>
  </div>
</div>

<div class="player-console">
  <div class="now-playing-lcd">
    <div class="lcd-art">
      <img id="np-art-img" src="/assets/images/audio_thumbnail.png" onerror="this.style.display='none'">
    </div>
    <div class="lcd-data">
      <div class="lcd-label">SYSTEM IDLE</div>
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

<div class="fs-overlay" id="fsOverlay">
  <div class="video-container" id="mediaContainer">
    <div class="window-controls">
      <button class="window-btn" onclick="toggleFullscreen()">[ ]</button>
      <button class="window-btn" onclick="closePlayer()">X</button>
    </div>
    <video id="videoPlayer" onclick="toggleMedia()" ondblclick="toggleFullscreen()"></video>
    <img id="fs-img" style="display:none;">
    <audio id="audioPlayer" style="display:none;"></audio>
    <div class="vid-controls-overlay" id="vidControls" style="display:none;">
      <button class="hw-btn play" onclick="toggleMedia()" id="vidPlayBtn" style="height:48px;width:100px;border:none;">PAUSE</button>
      <div class="lcd-progress-wrapper" id="vid-progress" style="display:block;flex-grow:1;margin:0;">
        <div class="lcd-progress-bar" id="vid-progress-bar"></div>
      </div>
      <div class="lcd-label" id="vid-time" style="margin:0;font-size:11px;letter-spacing:2px;">00:00 / 00:00</div>
    </div>
  </div>
</div>

<script>
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
    video:  { title: 'VIDEO ARCHIVE', sub: 'PATH // ROOT/VIDEO' },
    audio:  { title: 'AUDIO MATRIX',  sub: 'PATH // ROOT/AUDIO' },
    image:  { title: 'PHOTO DB',      sub: 'PATH // ROOT/IMAGE' },
    folder: { title: 'NETWORK SYS',   sub: 'PATH // ROOT/FS'   },
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
    const focusable = Array.from(document.querySelectorAll('[tabindex="0"], input, button'));
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
      buildUI('video');
    } catch(_) {
      document.getElementById('content-area').innerHTML = '<div class="empty-state">ERR: CONNECTION LOST.</div>';
    }
  }

  function syncNavUI(type) {
    document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
    document.getElementById('nav-' + type).classList.add('active');
    document.getElementById('page-title').innerText    = tabMeta[type].title;
    document.getElementById('page-subtitle').innerText = currentBrowsePath
        ? 'PATH // ' + currentBrowsePath.toUpperCase()
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
    container.innerHTML = items.length === 0 ? '<div class="empty-state">0 SIGNALS FOUND.</div>' : '';
    items.forEach(item => {
      const card     = document.createElement('div');
      card.className = 'card';
      card.setAttribute('tabindex', '0');
      const thumb    = '/api/thumbnail/' + item.id;
      const fallback = fallbacks[item.type] || fallbacks.video;
      card.innerHTML = `
        <div class="card-poster-wrap">
          <img class="card-poster" src="${thumb}" onerror="this.src='${fallback}';this.onerror=null;">
        </div>
        <div class="card-info">
          <div class="card-title" title="${item.title}">${item.title}</div>
          <a href="/stream/${item.id}" download="${item.title}" class="action-btn" tabindex="-1" onclick="event.stopPropagation()">DL</a>
        </div>`;
      card.onclick = () => openPlayer(item);
      container.appendChild(card);
    });
  }

  async function buildFolderView() {
    const container = document.getElementById('content-area');
    container.className = 'list-container';
    container.innerHTML = '<div class="empty-state">READING DIRECTORY...</div>';
    document.getElementById('page-subtitle').innerText = currentBrowsePath
        ? 'PATH // ' + currentBrowsePath.toUpperCase()
        : 'PATH // ROOT/FS';
    try {
      const res   = await fetch('/api/browse?path=' + encodeURIComponent(currentBrowsePath));
      const items = await res.json();
      container.innerHTML = '';
      
      if (currentBrowsePath) {
        const back = document.createElement('div');
        back.className = 'list-item';
        back.setAttribute('tabindex', '0');
        back.innerHTML = '<div class="list-index">[&lt;]</div><div class="list-title">.. / GO BACK</div>';
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
          row.innerHTML = `<div class="list-index">[DIR]</div><div class="list-title">${item.name}</div>`;
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
            <img class="list-art" src="${thumb}" onerror="this.src='${fallback}';this.onerror=null;">
            <div class="list-title" title="${item.name}">${item.name}</div>
            <div class="list-meta">${(item.size/1024/1024).toFixed(1)} MB</div>
            <a href="/api/file?path=${encodeURIComponent(item.path)}" class="list-download-icon" download="${item.name}" onclick="event.stopPropagation()">DL</a>`;
          row.onclick = () => {
            if (typeKey !== 'file') openPlayer({ id: item.path, type: typeKey, title: item.name }, true);
            else window.open('/api/file?path=' + encodeURIComponent(item.path), '_blank');
          };
        }
        container.appendChild(row);
      });
    } catch(_) {
      container.innerHTML = '<div class="empty-state">ERR: DIRECTORY READ FAILED.</div>';
    }
  }

  const aud = document.getElementById('audioPlayer');
  const vid = document.getElementById('videoPlayer');

  aud.addEventListener('timeupdate', () => {
    if (!aud.duration) return;
    document.getElementById('np-progress-bar').style.width = (aud.currentTime / aud.duration * 100) + '%';
    sendTelemetry(false, aud);
  });
  document.getElementById('np-progress').addEventListener('click', (e) => {
    const r = document.getElementById('np-progress').getBoundingClientRect();
    if (aud.duration) aud.currentTime = ((e.clientX - r.left) / r.width) * aud.duration;
  });

  vid.addEventListener('timeupdate', () => {
    if (!vid.duration) return;
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

  function openPlayer(item, isPath = false) {
    if (currentSessionId) sendTelemetry(true, null);
    currentSessionId  = 'SESSION_' + Date.now();
    currentMediaTitle = item.title;
    currentMediaType  = item.type;
    const url = isPath ? '/api/file?path=' + encodeURIComponent(item.id) : '/stream/' + item.id;

    if (item.type === 'audio') {
      aud.src = url;
      aud.play();
      document.querySelector('.lcd-label').innerText    = 'BROADCAST ACTIVE';
      document.getElementById('np-title').innerText     = item.title;
      document.getElementById('np-progress').style.display = 'block';
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
      document.querySelector('.lcd-label').innerText = 'SYSTEM IDLE';
      document.getElementById('np-title').innerText  = 'AWAITING SIGNAL...';
      document.getElementById('np-progress').style.display = 'none';
    }
  }

  function toggleMedia() {
    const active = vid.style.display === 'block' ? vid : aud;
    if (!active.src) return;
    if (active.paused) { active.play(); updatePlayBtn(false); }
    else               { active.pause(); updatePlayBtn(true); }
  }

  function updatePlayBtn(isPaused) {
    document.getElementById('globalPlayPause').innerText = isPaused ? 'PLAY' : 'PAUSE';
    document.getElementById('vidPlayBtn').innerText      = isPaused ? 'PLAY' : 'PAUSE';
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
