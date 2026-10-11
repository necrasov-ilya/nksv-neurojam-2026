/* LATENTPUNK host: lifecycle only. Original game bundles are left unchanged. */
(() => {
  'use strict';
  const base = new URL('./', document.currentScript.src);
  let active = null;
  const style = document.createElement('style');
  style.textContent = `
    #latent-host{position:fixed;inset:0;z-index:100000;background:#17121f;color:#242139;font:15px system-ui,sans-serif;display:flex;flex-direction:column}
    #latent-host *{box-sizing:border-box}#latent-host header{position:absolute;top:12px;left:50%;transform:translateX(-50%);max-width:calc(100% - 24px);display:flex;align-items:center;gap:8px;padding:8px 12px;background:#f5f3fbf5;border-radius:32px;box-shadow:0 6px 26px #0003;z-index:4}
    #latent-host .brand{font-weight:800;letter-spacing:.08em;color:#5b4cff;font-size:11px;white-space:nowrap}#latent-host .title{max-width:190px;overflow:hidden;white-space:nowrap;text-overflow:ellipsis}
    #latent-host button{background:#e9e5f5;color:#242139;border:0;border-radius:24px;padding:9px 13px;font:600 13px system-ui;cursor:pointer;white-space:nowrap}
    #latent-host button:hover{background:#ac2954;color:white}#latent-host .finish{background:#5b4cff;color:white}#latent-host button:disabled{opacity:.5;cursor:default}#latent-host iframe{border:0;width:100%;height:100%;flex:1;min-height:0;background:#08070c}
    #latent-host .pause-panel{position:absolute;inset:0;z-index:5;display:none;align-items:center;justify-content:center;background:#17121fb8}
    #latent-host .pause-panel.open{display:flex}#latent-host .plate{max-width:600px;max-height:calc(100% - 40px);overflow:auto;padding:30px;background:#f5f3fb;border:8px solid #242139;border-radius:26px;box-shadow:0 16px 70px #0008}
    #latent-host .plate h2{font-size:28px;margin:0 0 14px}#latent-host .plate p{line-height:1.6;color:#67617b}#latent-host .plate button{margin:6px 6px 0 0}
    #latent-host .status{font-size:13px;position:absolute;bottom:12px;left:12px;max-width:70%;background:#f5f3fbe8;color:#242139;padding:8px 12px;border-radius:18px;pointer-events:none;z-index:4}
    #latent-host .done{margin:auto;max-width:680px;padding:30px;font-size:22px;line-height:1.6;color:#eee8ff}#latent-host .done small{display:block;font-size:15px;color:#c9b5df}
    #latent-host .tape{position:absolute;inset:0;pointer-events:none;z-index:3;opacity:.13;background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='256' height='256'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.9' numOctaves='3' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='.8'/%3E%3C/svg%3E");mix-blend-mode:screen;animation:latent-grain .18s steps(1) infinite}#latent-host .tape:after{content:"";position:absolute;inset:0;background:repeating-linear-gradient(0deg,transparent 0 3px,#0006 3px 4px)}
    @keyframes latent-grain{0%{background-position:0 0}25%{background-position:47px 109px}50%{background-position:129px 25px}75%{background-position:11px 183px}}
    @media(max-width:800px){#latent-host header{border-radius:24px;flex-wrap:wrap;justify-content:center;width:calc(100% - 24px);padding:6px;gap:4px}#latent-host .title{max-width:120px}#latent-host button{font-size:11px;padding:7px}.brand{display:none}}
  `;
  document.head.appendChild(style);

  const element = (tag, text, className) => {
    const node = document.createElement(tag);
    if (text !== undefined) node.textContent = text;
    if (className) node.className = className;
    return node;
  };
  function dispose() {
    if (!active) return;
    const old = active;
    active = null;
    clearInterval(old.poll);
    clearInterval(old.ticker);
    old.frame?.remove();
    old.root.remove();
    document.getElementById('canvas')?.focus({preventScroll: true});
  }
  function command(type, value) {
    active?.frame?.contentWindow?.postMessage({kind: 'latent-host', type, value}, location.origin);
  }
  function setMuted(value) {
    if (!active) return;
    active.muted = Boolean(value);
    active.muteButton.textContent = active.muted ? 'Звук: выкл.' : 'Звук: вкл.';
    command('mute', active.muted);
  }
  function pause(value) {
    if (!active || active.finishing) return;
    value = Boolean(value);
    if (value === active.paused) return;
    active.paused = value;
    if (value) {
      active.pauseStart = performance.now();
      if (document.fullscreenElement) document.exitFullscreen().catch(error => status('Не удалось выйти из полноэкранного режима: ' + error.message));
    } else {
      if (active.instructionPending) {
        active.instructionPending = false;
        const message = JSON.stringify({event: 'instruction'});
        if (active.callback) active.callback(message);
        else window.sendIpcMessage?.(message);
        active.plateTitle.textContent = 'Стенд приостановлен';
        active.info.showInstructions = false;
      }
      active.pausedMillis += performance.now() - active.pauseStart;
    }
    active.panel.classList.toggle('open', value);
    active.pauseButton.textContent = value ? 'Продолжить' : 'Пауза';
    command('pause', value);
  }
  function status(text) {
    if (active) active.status.textContent = text;
  }
  function snapshot() {
    if (!active || active.finishing) return;
    if (active.paused) {status('Для снимка продолжи стенд и нажми F8.'); return;}
    status('Снимок следующего отрисованного кадра…');
    command('snapshot', true);
  }
  function elapsed(state) {
    if (state.started === null) return 0;
    const pausedNow = state.paused ? performance.now() - state.pauseStart : 0;
    return Math.max(0, (performance.now() - state.started - state.pausedMillis - pausedNow) / 1000);
  }
  function startClock() {
    if (!active || active.started !== null || !active.loaded || !active.rendered) return;
    active.started = performance.now();
    active.pausedMillis = 0;
    if (active.paused) active.pauseStart = active.started;
  }
  function updateTimer() {
    if (!active || active.finishing) return;
    const remaining = Math.max(0, Math.ceil(15 - elapsed(active)));
    for (const button of active.finishButtons) {
      button.disabled = remaining > 0;
      button.textContent = remaining > 0 ? `Наблюдение · ещё ${remaining} с` : 'В отчёт';
    }
  }
  function sample(state) {
    return {module: state.info.id, status: 'complete', seconds: Math.floor(elapsed(state)), snapshots: state.snapshots.slice(), muted: state.muted};
  }
  async function finish(result = 'complete') {
    if (!active || active.finishing) return;
    if (result === 'complete' && elapsed(active) < 15) {
      status('Сначала проведи минимум 15 секунд в активном стенде. Пауза и загрузка не учитываются.');
      return;
    }
    const state = active;
    const data = sample(state);
    data.status = result;
    state.finishing = true;
    command('pause', true);
    state.frame.remove();
    clearInterval(state.poll);
    clearInterval(state.ticker);
    if (state.callback) {
      dispose();
      state.callback(JSON.stringify(data));
      return;
    }
    try {
      const response = await fetch(new URL('complete', base), {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({token: state.token, module: state.info.id, muted: state.muted, sample: data})});
      if (!response.ok) throw new Error(`HTTP ${response.status}: ${await response.text()}`);
      state.root.replaceChildren(element('div', result === 'complete' ? 'Наблюдение завершено. Вернись в окно LATENTPUNK: там открыт опрос.' : 'Стенд закрыт без отчёта. Вернись в окно LATENTPUNK.', 'done'));
      state.root.firstChild.appendChild(element('small', 'Эту вкладку можно закрыть. Основное приложение должно оставаться открытым.'));
    } catch (error) {
      state.root.replaceChildren(element('div', 'Не удалось передать завершение: ' + error.message + '. Вернись в LATENTPUNK и нажми «Вернуться без отчёта».', 'done'));
    }
  }
  function open(info, muted, callback, token = '') {
    dispose();
    const root = element('section', undefined, '');
    root.id = 'latent-host';
    const header = element('header');
    header.append(element('span', 'LATENT / QA', 'brand'), element('span', info.title, 'title'));
    const makeButton = (text, fn, className = '') => {
      const button = element('button', text, className);
      button.type = 'button';
      button.addEventListener('click', fn);
      return button;
    };
    const pauseButton = makeButton('Пауза', () => pause(!active.paused));
    const muteButton = makeButton('Звук: вкл.', () => {
      setMuted(!active.muted);
      active.callback?.(JSON.stringify({event: 'sound', enabled: !active.muted}));
      if (!active.callback && window.sendIpcMessage) window.sendIpcMessage(JSON.stringify({event: 'sound', enabled: !active.muted}));
    });
    const finishButton = makeButton('Наблюдение · ещё 15 с', () => finish(), 'finish');
    header.append(pauseButton, muteButton, makeButton('Снимок / F8', snapshot), finishButton);
    const frame = element('iframe');
    frame.title = info.title;
    frame.setAttribute('sandbox', 'allow-scripts allow-same-origin allow-pointer-lock');
    frame.setAttribute('allow', 'fullscreen');
    const panel = element('div', undefined, 'pause-panel');
    const plate = element('div', undefined, 'plate');
    const plateTitle = element('h2', info.showInstructions ? 'Как работает испытательный стенд' : 'Стенд приостановлен');
    plate.append(plateTitle, element('p', `${info.controls || 'Управление указано в самой игре.'} Верхняя пилюля: пауза, звук, снимок F8 и переход в отчёт. Esc открывает эту панель. Победа не обязательна: проверь действия минимум 15 секунд; загрузка и пауза не засчитываются. После «В отчёт» заполни наблюдение и рекомендацию на планшете.`));
    const pauseFinish = makeButton('Наблюдение · ещё 15 с', () => finish(), 'finish');
    plate.append(makeButton('Начать / продолжить', () => pause(false)), makeButton('Снимок', snapshot), pauseFinish, makeButton('Выйти без отчёта', () => finish('abort')));
    plate.append(makeButton('Перезапустить стенд', () => {
      const state = active;
      open(state.info, state.muted, state.callback, state.token);
    }));
    panel.append(plate);
    const statusNode = element('div', 'Загрузка контрольной среды · Esc — панель стенда', 'status');
    root.append(frame, element('div', undefined, 'tape'), header, panel, statusNode);
    document.body.append(root);
    active = {root, frame, panel, plateTitle, instructionPending: Boolean(info.showInstructions), pauseButton, muteButton, finishButtons: [finishButton, pauseFinish], status: statusNode, info, token, callback, paused: false, muted: Boolean(muted), finishing: false, started: null, loaded: false, rendered: false, pausedMillis: 0, pauseStart: 0, snapshots: [], poll: null, ticker: setInterval(updateTimer, 200)};
    if (info.showInstructions) pause(true);
    updateTimer();
    setMuted(muted);
    frame.addEventListener('load', () => {
      if (!active || active.frame !== frame) return;
      active.loaded = true;
      startClock();
      command('init', {muted: active?.muted ?? muted, paused: active?.paused ?? false});
      status('Esc — пауза и выход · F8 — снимок · «В отчёт» — после 15 активных секунд');
    });
    frame.src = new URL(info.entry, base).href;
    if (token) {
      active.poll = setInterval(async () => {
        const state = active;
        if (!state || state.finishing) return;
        try {
          const response = await fetch(new URL(`state?token=${encodeURIComponent(token)}`, base));
          if (!response.ok) throw new Error('Приложение не отвечает');
          const data = await response.json();
          if (active !== state) return;
          if (!data.active) {
            clearInterval(state.poll);
            state.frame.remove();
            state.finishing = true;
            state.root.replaceChildren(element('div', 'Запуск закрыт в LATENTPUNK. Эту вкладку можно закрыть.', 'done'));
          }
        } catch (_error) {
          if (active !== state) return;
          clearInterval(state.poll);
          state.frame.remove();
          state.finishing = true;
          state.root.replaceChildren(element('div', 'Основное приложение закрыто или локальный сервер недоступен. Эта среда остановлена.', 'done'));
        }
      }, 1000);
    }
  }
  window.addEventListener('message', event => {
    if (!active || event.source !== active.frame.contentWindow || event.origin !== location.origin || event.data?.kind !== 'latent-frame') return;
    switch (event.data.type) {
      case 'ready': command('init', {muted: active.muted, paused: active.paused}); break;
      case 'rendered': active.rendered = true; startClock(); break;
      case 'pointer-lock-request':
        if (active.token && window.sendIpcMessage) window.sendIpcMessage(JSON.stringify({event: 'pointer-lock', ...event.data.value}));
        else command('pointer-lock', {request: event.data.value.request, locked: false});
        break;
      case 'pause': pause(true); break;
      case 'snapshot-key': snapshot(); break;
      case 'snapshot':
        if (typeof event.data.value === 'string' && event.data.value.startsWith('data:image/jpeg;base64,')) {
          if (active.snapshots.length === 2) active.snapshots.shift();
          active.snapshots.push(event.data.value);
          status(`Снимок сохранён · ${active.snapshots.length}/2 в отчёт`);
        }
        break;
      case 'snapshot-error': status(event.data.value); break;
      case 'error': status('Ошибка среды: ' + event.data.value); break;
    }
  });
  window.addEventListener('keydown', event => {
    if (!active || event.repeat) return;
    if (event.code === 'Escape') {event.preventDefault(); pause(!active.paused);}
    else if (event.code === 'F8') {event.preventDefault(); snapshot();}
  });
  document.addEventListener('visibilitychange', () => {if (document.hidden) pause(true);});
  window.addEventListener('blur', () => setTimeout(() => {if (!active?.token && !document.hasFocus()) pause(true);}, 0));
  window.LatentHost = {
    openGame: (json, muted, callback) => open(JSON.parse(json), muted, callback),
    closeGame: dispose,
    setMuted,
    pause,
    pointerLockResult: (request, locked) => command('pointer-lock', {request, locked}),
    forwardMouse: delta => {if (active && !active.paused) command('mouse-motion', delta);},
    startNative: async () => {
      const query = new URLSearchParams(location.search);
      const response = await fetch(new URL('module_catalog.json', base));
      if (!response.ok) throw new Error('Каталог стендов не найден');
      const catalog = await response.json();
      const info = catalog.modules.find(item => item.id === query.get('module'));
      if (!info?.entry || !query.get('token')) throw new Error('Неверный запуск: открой стенд из приложения LATENTPUNK');
      const stateResponse = await fetch(new URL(`state?token=${encodeURIComponent(query.get('token'))}`, base));
      if (!stateResponse.ok) throw new Error('Локальное приложение недоступно');
      const state = await stateResponse.json();
      if (!state.active) throw new Error('Этот запуск уже закрыт в LATENTPUNK');
      info.showInstructions = !state.instruction_seen;
      open(info, state.muted, null, query.get('token'));
    }
  };
})();
