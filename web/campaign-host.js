/* LATENTPUNK host: lifecycle only. Original game bundles are left unchanged. */
(() => {
  'use strict';
  const base = new URL('./', document.currentScript.src);
  let active = null;
  const style = document.createElement('style');
  style.textContent = `
    #latent-host{position:fixed;inset:0;z-index:100000;background:#17121f;color:#eee8ff;font:15px system-ui,sans-serif;display:flex;flex-direction:column}
    #latent-host *{box-sizing:border-box}#latent-host header{height:58px;flex:none;display:flex;align-items:center;gap:10px;padding:8px 16px;background:#241b33;border-bottom:1px solid #6b5087}
    #latent-host .brand{font-weight:800;letter-spacing:.12em;color:#cbb5ff;font-size:12px}#latent-host .title{flex:1;overflow:hidden;white-space:nowrap;text-overflow:ellipsis}
    #latent-host button{background:#47305f;color:#fff;border:1px solid #806496;border-radius:6px;padding:9px 13px;font:600 14px system-ui;cursor:pointer}
    #latent-host button:hover{background:#68488a}#latent-host .finish{background:#744792}#latent-host iframe{border:0;width:100%;flex:1;min-height:0;background:#08070c}
    #latent-host .pause-panel{position:absolute;inset:58px 0 0;display:none;align-items:center;justify-content:center;background:#100b18c9}
    #latent-host .pause-panel.open{display:flex}#latent-host .plate{max-width:580px;padding:30px;background:#2d213c;border:1px solid #a37dc2;border-radius:12px;box-shadow:0 16px 70px #0008}
    #latent-host .plate h2{font-size:28px;margin:0 0 14px}#latent-host .plate p{line-height:1.6;color:#d1c3df}#latent-host .plate button{margin:6px 6px 0 0}
    #latent-host .status{font-size:13px;position:absolute;bottom:12px;left:12px;max-width:70%;background:#22152be8;padding:8px 12px;border-radius:6px;pointer-events:none}
    #latent-host .done{margin:auto;max-width:680px;padding:30px;font-size:22px;line-height:1.6}#latent-host .done small{display:block;font-size:15px;color:#c9b5df}
    @media(max-width:800px){#latent-host header{height:94px;flex-wrap:wrap;padding:8px}.title{min-width:45%}#latent-host button{font-size:12px;padding:7px}.pause-panel{top:94px!important}}
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
  function sample(state) {
    const pausedNow = state.paused ? performance.now() - state.pauseStart : 0;
    return {module: state.info.id, status: 'complete', seconds: Math.max(0, Math.round((performance.now() - state.started - state.pausedMillis - pausedNow) / 1000)), snapshots: state.snapshots.slice(), muted: state.muted};
  }
  async function finish(result = 'complete') {
    if (!active || active.finishing) return;
    const state = active;
    const data = sample(state);
    data.status = result;
    state.finishing = true;
    command('pause', true);
    state.frame.remove();
    clearInterval(state.poll);
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
    header.append(pauseButton, muteButton, makeButton('Снимок / F8', snapshot), makeButton('Завершить тестирование', () => finish(), 'finish'));
    const frame = element('iframe');
    frame.title = info.title;
    frame.setAttribute('sandbox', 'allow-scripts allow-same-origin allow-pointer-lock');
    frame.setAttribute('allow', 'fullscreen');
    const panel = element('div', undefined, 'pause-panel');
    const plate = element('div', undefined, 'plate');
    plate.append(element('h2', 'Стенд приостановлен'), element('p', `${info.controls || 'Управление указано в самой игре.'} Для отчёта достаточно проверить действия; победа внутри игры не обязательна.`));
    plate.append(makeButton('Продолжить', () => pause(false)), makeButton('Снимок', snapshot), makeButton('Завершить тестирование', () => finish(), 'finish'), makeButton('Выйти без отчёта', () => finish('abort')));
    plate.append(makeButton('Перезапустить стенд', () => {
      const state = active;
      open(state.info, state.muted, state.callback, state.token);
    }));
    panel.append(plate);
    const statusNode = element('div', 'Загрузка контрольной среды · Esc — панель стенда', 'status');
    root.append(header, frame, panel, statusNode);
    document.body.append(root);
    active = {root, frame, panel, pauseButton, muteButton, status: statusNode, info, token, callback, paused: false, muted: Boolean(muted), finishing: false, started: performance.now(), pausedMillis: 0, pauseStart: 0, snapshots: [], poll: null};
    setMuted(muted);
    frame.addEventListener('load', () => {
      command('init', {muted: active?.muted ?? muted, paused: active?.paused ?? false});
      status('Esc — пауза и выход · F8 — снимок · завершение тестирования — в верхней панели');
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
      open(info, state.muted, null, query.get('token'));
    }
  };
})();
