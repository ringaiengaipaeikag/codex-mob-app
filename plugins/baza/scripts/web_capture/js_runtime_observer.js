(function installBazaJsRuntimeObserver() {
  if (window.__BAZA_JS_OBSERVER_INSTALLED__) return;
  Object.defineProperty(window, '__BAZA_JS_OBSERVER_INSTALLED__', { value: true });

  const maxEvents = 2000;
  const sensitive = /(authorization|cookie|token|secret|password|passwd|api[-_]?key|csrf|session)/i;
  const events = [];
  Object.defineProperty(window, '__BAZA_JS_EVENTS__', {
    value: events,
    configurable: false,
    enumerable: false,
    writable: false,
  });

  function safeUrl(raw) {
    try {
      const parsed = new URL(String(raw), location.href);
      parsed.username = '';
      parsed.password = '';
      parsed.search = parsed.search ? '?[REDACTED_QUERY]' : '';
      parsed.hash = '';
      return parsed.toString();
    } catch (_) {
      return String(raw || '').slice(0, 200);
    }
  }

  function safeKey(key) {
    const text = String(key || '');
    return sensitive.test(text) ? '[SENSITIVE_KEY]' : text.slice(0, 120);
  }

  function summarize(value) {
    if (value === null) return { type: 'null' };
    if (value === undefined) return { type: 'undefined' };
    if (typeof value === 'string') {
      return { type: 'string', length: value.length, redacted: true };
    }
    if (value instanceof ArrayBuffer) {
      return { type: 'arraybuffer', byteLength: value.byteLength };
    }
    if (ArrayBuffer.isView(value)) {
      return { type: value.constructor && value.constructor.name || 'typed-array', byteLength: value.byteLength };
    }
    if (typeof Blob !== 'undefined' && value instanceof Blob) {
      return { type: 'blob', size: value.size, mime: value.type || '' };
    }
    if (typeof FormData !== 'undefined' && value instanceof FormData) {
      const keys = [];
      try {
        for (const key of value.keys()) keys.push(safeKey(key));
      } catch (_) {}
      return { type: 'formdata', keys: keys.slice(0, 50), redacted: true };
    }
    if (typeof URLSearchParams !== 'undefined' && value instanceof URLSearchParams) {
      const keys = [];
      try {
        for (const key of value.keys()) keys.push(safeKey(key));
      } catch (_) {}
      return { type: 'urlsearchparams', keys: keys.slice(0, 50), redacted: true };
    }
    if (typeof value === 'object') {
      return {
        type: value.constructor && value.constructor.name || 'object',
        keys: Object.keys(value).map(safeKey).slice(0, 50),
        redacted: true,
      };
    }
    return { type: typeof value };
  }

  function stack() {
    try {
      return String(new Error().stack || '')
        .split('\n')
        .slice(2, 8)
        .map((line) => line.replace(/https?:\/\/\S+/g, (url) => safeUrl(url)));
    } catch (_) {
      return [];
    }
  }

  function log(type, data) {
    if (events.length >= maxEvents) return;
    events.push({
      ts: new Date().toISOString(),
      t: Math.round(performance.now()),
      type,
      page: safeUrl(location.href),
      data: data || {},
      stack: stack(),
    });
  }

  function wrap(obj, key, factory) {
    try {
      const original = obj && obj[key];
      if (typeof original !== 'function') return;
      obj[key] = factory(original);
    } catch (_) {}
  }

  wrap(window, 'fetch', (original) => function bazaFetch(input, init) {
    const url = typeof input === 'string' ? input : input && input.url;
    const method = (init && init.method) || (input && input.method) || 'GET';
    log('fetch.request', {
      url: safeUrl(url),
      method,
      body: init && init.body ? summarize(init.body) : undefined,
      headerNames: init && init.headers ? Object.keys(Object.fromEntries(new Headers(init.headers))).map(safeKey) : [],
    });
    return original.apply(this, arguments).then((response) => {
      log('fetch.response', { url: safeUrl(response.url), status: response.status, type: response.type });
      return response;
    });
  });

  if (window.XMLHttpRequest) {
    const proto = window.XMLHttpRequest.prototype;
    wrap(proto, 'open', (original) => function bazaXhrOpen(method, url) {
      this.__baza_xhr = { method: method || 'GET', url: safeUrl(url) };
      log('xhr.open', this.__baza_xhr);
      return original.apply(this, arguments);
    });
    wrap(proto, 'send', (original) => function bazaXhrSend(body) {
      log('xhr.send', Object.assign({}, this.__baza_xhr || {}, { body: body ? summarize(body) : undefined }));
      this.addEventListener('loadend', () => {
        log('xhr.loadend', Object.assign({}, this.__baza_xhr || {}, { status: this.status, responseURL: safeUrl(this.responseURL) }));
      }, { once: true });
      return original.apply(this, arguments);
    });
  }

  if (window.WebSocket) {
    const OriginalWebSocket = window.WebSocket;
    window.WebSocket = function bazaWebSocket(url, protocols) {
      log('websocket.create', { url: safeUrl(url), protocols: summarize(protocols) });
      const ws = new OriginalWebSocket(url, protocols);
      const originalSend = ws.send;
      ws.send = function bazaWebSocketSend(data) {
        log('websocket.send', { url: safeUrl(url), payload: summarize(data) });
        return originalSend.apply(this, arguments);
      };
      ws.addEventListener('message', (event) => log('websocket.message', { url: safeUrl(url), payload: summarize(event.data) }));
      return ws;
    };
    window.WebSocket.prototype = OriginalWebSocket.prototype;
  }

  if (window.EventSource) {
    const OriginalEventSource = window.EventSource;
    window.EventSource = function bazaEventSource(url, config) {
      log('eventsource.create', { url: safeUrl(url), withCredentials: Boolean(config && config.withCredentials) });
      return new OriginalEventSource(url, config);
    };
    window.EventSource.prototype = OriginalEventSource.prototype;
  }

  wrap(navigator, 'sendBeacon', (original) => function bazaSendBeacon(url, data) {
    log('sendbeacon', { url: safeUrl(url), payload: summarize(data) });
    return original.apply(this, arguments);
  });

  for (const storageName of ['localStorage', 'sessionStorage']) {
    try {
      const storage = window[storageName];
      if (!storage) continue;
      wrap(storage.__proto__, 'setItem', (original) => function bazaStorageSet(key, value) {
        log(`${storageName}.setItem`, { key: safeKey(key), value: summarize(value) });
        return original.apply(this, arguments);
      });
      wrap(storage.__proto__, 'removeItem', (original) => function bazaStorageRemove(key) {
        log(`${storageName}.removeItem`, { key: safeKey(key) });
        return original.apply(this, arguments);
      });
      wrap(storage.__proto__, 'clear', (original) => function bazaStorageClear() {
        log(`${storageName}.clear`, {});
        return original.apply(this, arguments);
      });
    } catch (_) {}
  }

  try {
    const descriptor = Object.getOwnPropertyDescriptor(Document.prototype, 'cookie')
      || Object.getOwnPropertyDescriptor(HTMLDocument.prototype, 'cookie');
    if (descriptor && descriptor.set && descriptor.get) {
      Object.defineProperty(document, 'cookie', {
        get: function bazaCookieGet() {
          log('document.cookie.get', {});
          return descriptor.get.call(document);
        },
        set: function bazaCookieSet(value) {
          const key = String(value || '').split('=')[0];
          log('document.cookie.set', { key: safeKey(key), value: summarize(value) });
          return descriptor.set.call(document, value);
        },
      });
    }
  } catch (_) {}

  if (window.crypto && window.crypto.subtle) {
    for (const name of ['digest', 'sign', 'verify', 'encrypt', 'decrypt', 'importKey', 'deriveKey']) {
      wrap(window.crypto.subtle, name, (original) => function bazaCryptoSubtle() {
        const algorithm = arguments[0] && (arguments[0].name || arguments[0]);
        log(`crypto.subtle.${name}`, { algorithm: summarize(algorithm), argCount: arguments.length });
        return original.apply(this, arguments);
      });
    }
  }

  wrap(window, 'btoa', (original) => function bazaBtoa(value) {
    log('encoding.btoa', { input: summarize(value) });
    return original.apply(this, arguments);
  });
  wrap(window, 'atob', (original) => function bazaAtob(value) {
    log('encoding.atob', { input: summarize(value) });
    return original.apply(this, arguments);
  });

  if (window.FormData) {
    wrap(window.FormData.prototype, 'append', (original) => function bazaFormDataAppend(key, value) {
      log('formdata.append', { key: safeKey(key), value: summarize(value) });
      return original.apply(this, arguments);
    });
    wrap(window.FormData.prototype, 'set', (original) => function bazaFormDataSet(key, value) {
      log('formdata.set', { key: safeKey(key), value: summarize(value) });
      return original.apply(this, arguments);
    });
  }

  if (window.HTMLCanvasElement) {
    wrap(window.HTMLCanvasElement.prototype, 'toDataURL', (original) => function bazaCanvasToDataURL() {
      log('canvas.toDataURL', {});
      return original.apply(this, arguments);
    });
  }
  if (window.CanvasRenderingContext2D) {
    wrap(window.CanvasRenderingContext2D.prototype, 'getImageData', (original) => function bazaCanvasGetImageData() {
      log('canvas.getImageData', {});
      return original.apply(this, arguments);
    });
  }
  if (window.WebGLRenderingContext) {
    wrap(window.WebGLRenderingContext.prototype, 'getParameter', (original) => function bazaWebglGetParameter(param) {
      log('webgl.getParameter', { param: summarize(param) });
      return original.apply(this, arguments);
    });
  }

  log('observer.installed', { version: 'baza-js-runtime-observer-v1' });
})();
