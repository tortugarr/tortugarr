// Compiles a dart2wasm-generated main module from `source` which can then
// be instantiated via the `instantiate` method.
//
// `source` needs to be a `Response` object (or promise thereof) e.g. created
// via the `fetch()` JS API.
export async function compileStreaming(source) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(
      await WebAssembly.compileStreaming(source, builtins), builtins);
}

// Compiles a dart2wasm-generated wasm module from `bytes` which is then
// instantiable via the `instantiate` method.
export async function compile(bytes) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(await WebAssembly.compile(bytes, builtins), builtins);
}

class CompiledApp {
  constructor(module, builtins) {
    this.module = module;
    this.builtins = builtins;
  }

  // The second argument is an options object containing:
  // `loadDeferredModules` is a JS function that takes an array of module names
  //   matching wasm files produced by the dart2wasm compiler. It also takes a
  //   callback that should be invoked for each loaded module with 2 arguments:
  //   (1) the module name, (2) the loaded module in a format supported by
  //   `WebAssembly.compile` or `WebAssembly.compileStreaming`. The callback
  //   returns a Promise that resolves when the module is instantiated.
  //   loadDeferredModules should return a Promise that resolves when all the
  //   modules have been loaded and the callback promises have resolved.
  // `loadDeferredId` is a JS function that takes load ID produced by the
  //   compiler when the `use-load-ids` option is passed. Each load ID maps to
  //   one or more wasm files as specified in the emitted JSON file. It also
  //   takes a callback that should be invoked for each loaded module with 2
  //   arguments: (1) the module name, (2) the loaded module in a format
  //   supported by `WebAssembly.compile` or `WebAssembly.compileStreaming`.
  //   The callback returns a Promise that resolves when the module is
  //   instantiated.
  //   loadDeferredId should return a Promise that resolves when all the
  //   modules have been loaded and the callback promises have resolved.
  async instantiate(additionalImports, {loadDeferredModules, loadDeferredId} = {}) {
    let dartInstance;

    // Prints to the console
    function printToConsole(value) {
      if (typeof dartPrint == "function") {
        dartPrint(value);
        return;
      }
      if (typeof console == "object" && typeof console.log != "undefined") {
        console.log(value);
        return;
      }
      if (typeof print == "function") {
        print(value);
        return;
      }

      throw "Unable to print message: " + value;
    }

    // A special symbol attached to functions that wrap Dart functions.
    const jsWrappedDartFunctionSymbol = Symbol("JSWrappedDartFunction");

    function finalizeWrapper(dartFunction, wrapped) {
      wrapped.dartFunction = dartFunction;
      wrapped[jsWrappedDartFunctionSymbol] = true;
      return wrapped;
    }

    // Imports
    const dart2wasm = {
            AB: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      AC: Function.prototype.call.bind(DataView.prototype.getInt16),
      AD: x0 => x0.devicePixelRatio,
      AE: x0 => x0.languages,
      AF: (o, p, r) => o.replaceAll(p, () => r),
      AG: (x0,x1) => x0.segment(x1),
      AH: x0 => x0.minWidth,
      AI: () => Date.now(),
      AJ: x0 => x0.name,
      AK: (x0,x1) => { x0.timeout = x1 },
      AL: (x0,x1) => { x0.innerHTML = x1 },
      AM: x0 => x0.maxChannelCount,
      AN: x0 => x0.mark,
      AO: (x0,x1) => { x0.preload = x1 },
      AP: x0 => new JASSUB(x0),
      AQ: (x0,x1,x2,x3,x4,x5) => x0.sqlite3_exec(x1,x2,x3,x4,x5),
      AR: x0 => x0.close(),
      AS: (x0,x1) => x0.read(x1),
      AT: x0 => x0.ctrlKey,
      AU: x0 => x0.gamepad,
      AV: x0 => x0.result,
      B: s => printToConsole(s),
      BB: b => !!b,
      BC: o => o instanceof Uint8ClampedArray,
      BD: x0 => x0.height,
      BE: (x0,x1) => x0.observe(x1),
      BF: x0 => x0.deltaMode,
      BG: x0 => x0.index,
      BH: (x0,x1) => x0.removeProperty(x1),
      BI: () => 1000 * performance.now(),
      BJ: x0 => x0.repetitionCount,
      BK: (x0,x1,x2) => x0.setRequestHeader(x1,x2),
      BL: (x0,x1,x2,x3) => x0.register(x1,x2,x3),
      BM: x0 => x0.destination,
      BN: x0 => x0.measure,
      BO: (x0,x1) => { x0.autoplay = x1 },
      BP: x0 => x0.baseURI,
      BQ: (x0,x1) => x0.sqlite3_last_insert_rowid(x1),
      BR: (x0,x1) => x0.truncate(x1),
      BS: (x0,x1,x2) => x0.read(x1,x2),
      BT: x0 => x0.isComposing,
      BU: x0 => x0.value,
      BV: x0 => x0.length,
      C: Function.prototype.call.bind(Number.prototype.toString),
      CB: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      CC: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint8Array) return 1;
        return 2;
      },
      CD: x0 => x0.width,
      CE: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      CF: x0 => x0.deltaY,
      CG: x0 => x0.next(),
      CH: (x0,x1) => x0.add(x1),
      CI: (map, o) => map.get(o),
      CJ: x0 => x0.frameCount,
      CK: (x0,x1) => { x0.withCredentials = x1 },
      CL: (x0,x1,x2) => x0.register(x1,x2),
      CM: x0 => globalThis.MediaSource.isTypeSupported(x0),
      CN: () => globalThis.performance,
      CO: () => new RTCPeerConnection(),
      CP: (x0,x1) => { x0.text = x1 },
      CQ: x0 => globalThis.Number(x0),
      CR: x0 => x0.createSyncAccessHandle(),
      CS: (x0,x1) => x0.write(x1),
      CT: x0 => x0.code,
      CU: x0 => x0.axes,
      CV: x0 => x0.files,
      D: Function.prototype.call.bind(BigInt.prototype.toString),
      DB: (x0,x1) => x0.focus(x1),
      DC: Function.prototype.call.bind(DataView.prototype.setInt8),
      DD: x0 => x0.screen,
      DE: x0 => new ResizeObserver(x0),
      DF: x0 => x0.deltaX,
      DG: x0 => x0.value,
      DH: x0 => x0.data,
      DI: x0 => x0.load(),
      DJ: x0 => x0.selectedTrack,
      DK: (x0,x1) => { x0.responseType = x1 },
      DL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      DM: x0 => x0.maxTouchPoints,
      DN: (x0,x1,x2,x3) => x0.sendCommand(x1,x2,x3),
      DO: (x0,x1) => x0.createDataChannel(x1),
      DP: x0 => x0.readyState,
      DQ: (x0,x1) => x0.sqlite3_changes(x1),
      DR: x0 => ({create: x0}),
      DS: (x0,x1,x2) => x0.write(x1,x2),
      DT: x0 => x0.repeat,
      DU: x0 => x0.buttons,
      DV: (x0,x1) => { x0.accept = x1 },
      E: (exn) => {
        let stackString = exn.toString();
        let frames = stackString.split('\n');
        let drop = 4;
        if (frames[0].startsWith('Error')) {
            drop += 1;
        }
        return frames.slice(drop).join('\n');
      },
      EB: () => ({}),
      EC: Function.prototype.call.bind(DataView.prototype.getInt8),
      ED: o => {
        if (o === null || o === undefined) return 0;
        if (typeof(o) === 'string') return 1;
        return 2;
      },
      EE: (x0,x1) => x0.getPropertyValue(x1),
      EF: x0 => x0.wheelDeltaY,
      EG: x0 => x0.done,
      EH: (x0,x1) => { x0.scrollTop = x1 },
      EI: x0 => x0.remove(),
      EJ: x0 => x0.completed,
      EK: x0 => x0.decode(),
      EL: x0 => new FinalizationRegistry(x0),
      EM: (x0,x1) => new YT.Player(x0,x1),
      EN: () => globalThis.PdfiumWasmCommunicator,
      EO: x0 => x0.setLocalDescription(),
      EP: x0 => x0.paused,
      EQ: (x0,x1,x2) => x0.sqlite3_column_name(x1,x2),
      ER: (x0,x1,x2) => x0.getFileHandle(x1,x2),
      ES: x0 => x0.flush(),
      ET: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      EU: x0 => x0.getGamepads(),
      EV: (x0,x1) => { x0.multiple = x1 },
      F: () => new Error().stack,
      FB: (o, p, v) => o[p] = v,
      FC: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int8Array) return 1;
        return 2;
      },
      FD: x0 => x0.tabIndex,
      FE: x0 => globalThis.parseFloat(x0),
      FF: x0 => x0.wheelDeltaX,
      FG: (o, m, a) => o[m].apply(o, a),
      FH: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      FI: (o, p) => delete o[p],
      FJ: x0 => x0.ready,
      FK: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      FL: () => globalThis.FinalizationRegistry,
      FM: x0 => x0.getIframe(),
      FN: (x0,x1) => x0.writeText(x1),
      FO: x0 => x0.close(),
      FP: x0 => x0.ended,
      FQ: (x0,x1,x2) => x0.sqlite3_column_blob(x1,x2),
      FR: x0 => ({create: x0}),
      FS: x0 => x0.getSize(),
      FT: x0 => globalThis.Wakelock.toggle(x0),
      FU: x0 => x0.reset(),
      FV: (x0,x1) => { x0.draggable = x1 },
      G: s => JSON.stringify(s),
      GB: () => [],
      GC: (o, start, length) => new Float64Array(o.buffer, o.byteOffset + start, length),
      GD: (x0,x1) => x0.contains(x1),
      GE: (x0,x1) => x0.getComputedStyle(x1),
      GF: x0 => x0.key,
      GG: x0 => x0.iterator,
      GH: (x0,x1) => { x0.value = x1 },
      GI: (x0,x1) => { x0.src = x1 },
      GJ: x0 => x0.tracks,
      GK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      GL: (x0,x1,x2) => x0.setAttribute(x1,x2),
      GM: (x0,x1) => { x0.pointerEvents = x1 },
      GN: x0 => x0.clipboard,
      GO: x0 => x0.sdp,
      GP: (x0,x1) => { x0.playbackRate = x1 },
      GQ: (x0,x1,x2) => x0.sqlite3_column_bytes(x1,x2),
      GR: (x0,x1,x2) => x0.getDirectoryHandle(x1,x2),
      GS: (x0,x1,x2) => x0.transaction(x1,x2),
      GT: (x0,x1) => x0.item(x1),
      GU: x0 => x0.vibrationActuator,
      GV: (x0,x1) => { x0.type = x1 },
      H: Function.prototype.call.bind(Number.prototype.toString),
      HB: (a, i) => a.push(i),
      HC: (o, start, length) => new Float32Array(o.buffer, o.byteOffset + start, length),
      HD: x0 => x0.activeElement,
      HE: x0 => x0.documentElement,
      HF: x0 => x0.identifier,
      HG: () => globalThis.Symbol,
      HH: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      HI: x0 => x0.pause(),
      HJ: () => globalThis.window.ImageDecoder,
      HK: (x0,x1,x2) => x0.addEventListener(x1,x2),
      HL: (x0,x1) => x0.append(x1),
      HM: x0 => x0.origin,
      HN: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      HO: x0 => x0.localDescription,
      HP: (x0,x1) => { x0.currentTime = x1 },
      HQ: (x0,x1,x2) => x0.sqlite3_column_text(x1,x2),
      HR: x0 => x0.getDirectory(),
      HS: (x0,x1) => x0.objectStore(x1),
      HT: x0 => x0.src,
      HU: x0 => x0.connected,
      HV: x0 => x0.onLine,
      I: Function.prototype.call.bind(String.prototype.indexOf),
      IB: x0 => new Int8Array(x0),
      IC: (o, start, length) => new Uint32Array(o.buffer, o.byteOffset + start, length),
      ID: x0 => x0.parentNode,
      IE: x0 => x0.computedStyleMap(),
      IF: x0 => x0.touches,
      IG: (x0,x1) => new Intl.Segmenter(x0,x1),
      IH: (x0,x1) => { x0.value = x1 },
      II: (x0,x1) => { x0.volume = x1 },
      IJ: (x0,x1) => x0.get(x1),
      IK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      IL: (x0,x1) => x0.append(x1),
      IM: x0 => x0.location,
      IN: x0 => x0.preventDefault(),
      IO: x0 => x0.iceGatheringState,
      IP: (x0,x1,x2,x3) => x0.attach(x1,x2,x3),
      IQ: (x0,x1,x2) => x0.sqlite3_column_double(x1,x2),
      IR: x0 => x0.storage,
      IS: (x0,x1) => x0.openCursor(x1),
      IT: x0 => x0.length,
      IU: x0 => x0.hidden,
      IV: x0 => x0.mediaSession,
      J: (s, p, i) => s.lastIndexOf(p, i),
      JB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI8ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      JC: (o, start, length) => new Int32Array(o.buffer, o.byteOffset + start, length),
      JD: x0 => x0.tagName,
      JE: (x0,x1) => x0.get(x1),
      JF: x0 => x0.pressure,
      JG: x0 => x0.Segmenter,
      JH: s => {
        if (/[[\]{}()*+?.\\^$|]/.test(s)) {
            s = s.replace(/[[\]{}()*+?.\\^$|]/g, '\\$&');
        }
        return s;
      },
      JI: (x0,x1) => { x0.muted = x1 },
      JJ: x0 => x0.body,
      JK: x0 => x0.send(),
      JL: (x0,x1) => x0.createElement(x1),
      JM: (o) => {
        const typeofValue = typeof o;
        return (typeofValue === 'object') ||
            typeofValue === 'function';
      },
      JN: (x0,x1) => x0.querySelector(x1),
      JO: (x0,x1) => x0.getItem(x1),
      JP: (x0,x1,x2,x3) => x0.canUseHlsJs(x1,x2,x3),
      JQ: (x0,x1,x2) => x0.sqlite3_column_int64(x1,x2),
      JR: () => globalThis.navigator,
      JS: x0 => x0.arrayBuffer(),
      JT: x0 => x0.children,
      JU: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2) { return wasmFunction(f,arguments.length,x0,x1,x2) }),
      JV: x0 => x0.length,
      K: o => o,
      KB: x0 => new Uint8Array(x0),
      KC: (o, start, length) => new Uint16Array(o.buffer, o.byteOffset + start, length),
      KD: x0 => x0.target,
      KE: (o, p) => p in o,
      KF: x0 => x0.tiltY,
      KG: x0 => x0.buffer,
      KH: x0 => x0.value,
      KI: x0 => x0.muted,
      KJ: x0 => x0.headers,
      KK: x0 => x0.status,
      KL: x0 => x0.head,
      KM: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      KN: x0 => x0.href,
      KO: (x0,x1) => x0.removeItem(x1),
      KP: (x0,x1) => { x0.crossOrigin = x1 },
      KQ: (x0,x1,x2) => x0.sqlite3_column_type(x1,x2),
      KR: x0 => new URL(x0),
      KS: x0 => x0.value,
      KT: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      KU: (x0,x1) => { x0.nativeCommunication = x1 },
      KV: x0 => x0.getReader(),
      L: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'number') return 1;
        return 2;
      },
      LB: x0 => new Uint8ClampedArray(x0),
      LC: (o, start, length) => new Int16Array(o.buffer, o.byteOffset + start, length),
      LD: x0 => x0.clientY,
      LE: (x0,x1) => { x0.textContent = x1 },
      LF: x0 => x0.tiltX,
      LG: x0 => x0.wasmMemory,
      LH: x0 => x0.selectionDirection,
      LI: x0 => x0.requestFullscreen(),
      LJ: () => {
        // On browsers return `globalThis.location.href`
        if (globalThis.location != null) {
          return globalThis.location.href;
        }
        return null;
      },
      LK: x0 => x0.response,
      LL: (x0,x1) => { x0.src = x1 },
      LM: x0 => new ResizeObserver(x0),
      LN: x0 => x0.baseURI,
      LO: x0 => x0.localStorage,
      LP: x0 => x0.text(),
      LQ: (x0,x1) => x0.sqlite3_column_count(x1),
      LR: (x0,x1) => new URL(x0,x1),
      LS: x0 => x0.key,
      LT: () => new webkitSpeechRecognition(),
      LU: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      LV: x0 => x0.value,
      M: x0 => x0.index,
      MB: x0 => new Int16Array(x0),
      MC: (o, start, length) => new Uint8ClampedArray(o.buffer, o.byteOffset + start, length),
      MD: x0 => x0.clientX,
      ME: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      MF: x0 => x0.pointerType,
      MG: () => globalThis.window._flutter_skwasmInstance,
      MH: x0 => x0.selectionStart,
      MI: x0 => x0.exitFullscreen(),
      MJ: () => {
        return typeof process != "undefined" &&
               Object.prototype.toString.call(process) == "[object process]" &&
               process.platform == "win32"
      },
      MK: (x0,x1,x2) => x0.setRequestHeader(x1,x2),
      ML: (x0,x1) => { x0.type = x1 },
      MM: (x0,x1) => x0.observe(x1),
      MN: x0 => { globalThis.pdfiumWasmWorkerUrl = x0 },
      MO: x0 => x0.sessionStorage,
      MP: () => new MessageChannel(),
      MQ: (x0,x1) => x0.sqlite3_close_v2(x1),
      MR: (x0,x1) => globalThis.fetch(x0,x1),
      MS: x0 => x0.continue(),
      MT: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      MU: (o,s,v) => o[s] = v,
      MV: x0 => x0.done,
      N: o => String(o),
      NB: x0 => new Uint16Array(x0),
      NC: (o, start, length) => new Uint8Array(o.buffer, o.byteOffset + start, length),
      ND: (x0,x1,x2) => x0.setAttribute(x1,x2),
      NE: x0 => x0.matches,
      NF: x0 => x0.pointerId,
      NG: () => new TextDecoder(),
      NH: x0 => x0.selectionEnd,
      NI: x0 => x0.fullscreenElement,
      NJ: (x0,x1) => x0.getRandomValues(x1),
      NK: (x0,x1) => { x0.responseType = x1 },
      NL: (x0,x1) => { x0.charset = x1 },
      NM: (x0,x1) => { x0.transform = x1 },
      NN: x0 => globalThis.URL.createObjectURL(x0),
      NO: (x0,x1,x2) => x0.insertBefore(x1,x2),
      NP: x0 => new BroadcastChannel(x0),
      NQ: (x0,x1,x2,x3) => x0.call(x1,x2,x3),
      NR: x0 => x0.exports,
      NS: x0 => x0.error,
      NT: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      NU: () => Symbol("jsBoxedDartObjectProperty"),
      NV: x0 => x0.read(),
      O: o => o === undefined,
      OB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI16ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      OC: (o, start, length) => new Int8Array(o.buffer, o.byteOffset + start, length),
      OD: x0 => x0.getBoundingClientRect(),
      OE: (x0,x1) => x0.matchMedia(x1),
      OF: x0 => x0.getCoalescedEvents(),
      OG: Function.prototype.call.bind(DataView.prototype.getBigInt64),
      OH: x0 => x0.value,
      OI: x0 => x0.documentElement,
      OJ: () => globalThis.crypto,
      OK: () => new XMLHttpRequest(),
      OL: (x0,x1) => { x0.async = x1 },
      OM: x0 => x0.clientHeight,
      ON: x0 => x0.content,
      OO: x0 => x0.id,
      OP: x0 => globalThis.Array.isArray(x0),
      OQ: x0 => x0.dart_sqlite3_rollbacks,
      OR: (x0,x1) => globalThis.WebAssembly.instantiateStreaming(x0,x1),
      OS: x0 => x0.result,
      OT: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      OU: () => globalThis.window.flutter_inappwebview,
      OV: x0 => x0.assetBase,
      P: (x0,x1) => x0.exec(x1),
      PB: x0 => new Int32Array(x0),
      PC: (x0,x1) => x0.querySelector(x1),
      PD: (ms, c) =>
      setTimeout(() => dartInstance.exports.$invokeCallback(c),ms),
      PE: x0 => x0.matches,
      PF: (x0,x1) => x0.getModifierState(x1),
      PG: Function.prototype.call.bind(DataView.prototype.setBigInt64),
      PH: x0 => x0.selectionDirection,
      PI: () => globalThis.document,
      PJ: l => new DataView(new ArrayBuffer(l)),
      PK: (a, l) => a.length = l,
      PL: x0 => x0.videoHeight,
      PM: x0 => x0.clientWidth,
      PN: (x0,x1,x2,x3) => x0.putImageData(x1,x2,x3),
      PO: x0 => x0.offsetHeight,
      PP: x0 => x0.table,
      PQ: x0 => x0.dart_sqlite3_commits,
      PR: x0 => x0.call(),
      PS: (x0,x1) => globalThis.IDBKeyRange.bound(x0,x1),
      PT: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      PU: (x0,x1) => { x0.src = x1 },
      PV: x0 => x0.loader,
      Q: (x0,x1) => { x0.lastIndex = x1 },
      QB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      QC: (x0,x1) => x0.item(x1),
      QD: s => new Date(s * 1000).getTimezoneOffset() * 60,
      QE: o => typeof o === 'function' && o[jsWrappedDartFunctionSymbol] === true,
      QF: s => s.trimLeft(),
      QG: (o, start, length) => new BigInt64Array(o.buffer, o.byteOffset + start, length),
      QH: x0 => x0.selectionStart,
      QI: x0 => new WeakRef(x0),
      QJ: () => new AbortController(),
      QK: x0 => x0.input,
      QL: x0 => x0.videoWidth,
      QM: (x0,x1) => { x0.transformOrigin = x1 },
      QN: x0 => x0.arrayBuffer(),
      QO: x0 => x0.offsetWidth,
      QP: x0 => x0.kind,
      QQ: x0 => x0.dart_sqlite3_updates,
      QR: x0 => x0.instance,
      QS: x0 => x0.length,
      QT: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      QU: (x0,x1) => x0.getResponseHeader(x1),
      QV: () => globalThis._flutter,
      R: o => o,
      RB: x0 => new Uint32Array(x0),
      RC: x0 => x0.length,
      RD: Date.now,
      RE: f => f.dartFunction,
      RF: (a, s) => a.join(s),
      RG: o => o.byteLength,
      RH: x0 => x0.selectionEnd,
      RI: x0 => x0.deref(),
      RJ: (x0,x1,x2,x3,x4,x5) => ({method: x0,headers: x1,body: x2,credentials: x3,redirect: x4,signal: x5}),
      RK: () => globalThis.window.navigator.userAgent,
      RL: x0 => x0.message,
      RM: (x0,x1) => { x0.left = x1 },
      RN: (x0,x1) => x0.transferFromImageBitmap(x1),
      RO: x0 => x0.stopPropagation(),
      RP: (x0,x1) => x0.postMessage(x1),
      RQ: (x0,x1,x2,x3,x4,x5) => x0.dart_sqlite3_create_scalar_function(x1,x2,x3,x4,x5),
      RR: x0 => ({initial: x0}),
      RS: (x0,x1) => x0.get(x1),
      RT: (x0,x1) => { x0.onnomatch = x1 },
      RU: x0 => x0.responseText,
      S: (s, m) => {
        try {
          return new RegExp(s, m);
        } catch (e) {
          return String(e);
        }
      },
      SB: x0 => new Float32Array(x0),
      SC: (x0,x1) => x0.querySelectorAll(x1),
      SD: (handle) => clearTimeout(handle),
      SE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      SF: (x0,x1) => x0.error(x1),
      SG: (a, i) => a.splice(i, 1),
      SH: x0 => x0.keyCode,
      SI: () => globalThis.WeakRef,
      SJ: (x0,x1) => globalThis.fetch(x0,x1),
      SK: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      SL: x0 => x0.error,
      SM: (x0,x1) => { x0.top = x1 },
      SN: x0 => x0.height,
      SO: x0 => x0.disabled,
      SP: (x0,x1) => ({kind: x0,table: x1}),
      SQ: (x0,x1,x2,x3) => x0.sqlite3_result_error(x1,x2,x3),
      SR: x0 => new WebAssembly.Memory(x0),
      SS: (x0,x1) => x0.index(x1),
      ST: (x0,x1) => { x0.onend = x1 },
      SU: (x0,x1,x2,x3) => x0.open(x1,x2,x3),
      T: o => o instanceof RegExp,
      TB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      TC: (x0,x1) => x0.getAttribute(x1),
      TD: (a, l) => a.length = l,
      TE: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      TF: () => globalThis.console,
      TG: a => a.pop(),
      TH: (x0,x1) => x0.scrollIntoView(x1),
      TI: (o, offsetInBytes, lengthInBytes) => {
        var dst = new ArrayBuffer(lengthInBytes);
        new Uint8Array(dst).set(new Uint8Array(o, offsetInBytes, lengthInBytes));
        return new DataView(dst);
      },
      TJ: (x0,x1) => x0.get(x1),
      TK: (x0,x1,x2) => x0.addEventListener(x1,x2),
      TL: x0 => x0.playbackRate,
      TM: (x0,x1) => { x0.id = x1 },
      TN: x0 => x0.width,
      TO: (x0,x1) => { x0.min = x1 },
      TP: x0 => x0.close(),
      TQ: x0 => x0.sqlite3_result_subtype,
      TR: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      TS: x0 => x0.openKeyCursor(),
      TT: (x0,x1) => { x0.onspeechstart = x1 },
      TU: (x0,x1) => { x0.csp = x1 },
      U: (string, times) => string.repeat(times),
      UB: x0 => new Float64Array(x0),
      UC: x0 => x0.remove(),
      UD: (x0,x1) => x0.closest(x1),
      UE: (p, s, f) => p.then(s, (e) => f(e, e === undefined)),
      UF: s => s.trimRight(),
      UG: (map, o, v) => map.set(o, v),
      UH: x0 => x0.multiViewEnabled,
      UI: (a, s, e) => a.slice(s, e),
      UJ: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2) { return wasmFunction(f,arguments.length,x0,x1,x2) }),
      UK: x0 => ({type: x0}),
      UL: x0 => x0.volume,
      UM: (x0,x1) => { x0.overflow = x1 },
      UN: x0 => x0.rasterEndMilliseconds,
      UO: (x0,x1) => { x0.max = x1 },
      UP: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      UQ: (x0,x1,x2,x3,x4) => x0.sqlite3_result_blob64(x1,x2,x3,x4),
      UR: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2,x3,x4) { return wasmFunction(f,arguments.length,x0,x1,x2,x3,x4) }),
      US: x0 => x0.primaryKey,
      UT: (x0,x1) => { x0.onstart = x1 },
      UU: x0 => x0.csp,
      V: o => o,
      VB: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF64ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      VC: (x0,x1) => x0.appendChild(x1),
      VD: x0 => x0.bottom,
      VE: (o, i) => o[i],
      VF: x0 => x0.blur(),
      VG: () => new WeakMap(),
      VH: (x0,x1) => x0.replaceWith(x1),
      VI: (a, i) => a.splice(i, 1)[0],
      VJ: (x0,x1) => x0.forEach(x1),
      VK: (x0,x1) => new Blob(x0,x1),
      VL: (x0,x1) => x0.end(x1),
      VM: (x0,x1) => { x0.position = x1 },
      VN: x0 => x0.rasterStartMilliseconds,
      VO: (x0,x1) => { x0.disabled = x1 },
      VP: (x0,x1) => x0.postMessage(x1),
      VQ: (x0,x1,x2,x3,x4) => x0.sqlite3_result_text(x1,x2,x3,x4),
      VR: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2) { return wasmFunction(f,arguments.length,x0,x1,x2) }),
      VS: (x0,x1,x2) => x0.open(x1,x2),
      VT: (x0,x1) => { x0.onerror = x1 },
      VU: (x0,x1) => { x0.name = x1 },
      W: o => {
        if (o === undefined || o === null) return 0;
        if (typeof o === 'boolean') return 1;
        return 2;
      },
      WB: x0 => new ArrayBuffer(x0),
      WC: (x0,x1) => x0.append(x1),
      WD: x0 => x0.top,
      WE: o => o.length,
      WF: x0 => x0.button,
      WG: x0 => x0.debugSkipFontRetryDelay,
      WH: (x0,x1) => { x0.type = x1 },
      WI: x0 => x0.naturalHeight,
      WJ: x0 => x0.name,
      WK: (x0,x1,x2) => x0.sendBeacon(x1,x2),
      WL: x0 => x0.length,
      WM: x0 => x0.playVideo(),
      WN: x0 => x0.imageBitmaps,
      WO: (x0,x1) => { x0.scrollLeft = x1 },
      WP: x0 => x0.close(),
      WQ: (x0,x1,x2) => x0.sqlite3_result_double(x1,x2),
      WR: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2,x3) { return wasmFunction(f,arguments.length,x0,x1,x2,x3) }),
      WS: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      WT: x0 => x0.error,
      WU: x0 => x0.name,
      X: x0 => x0.dotAll,
      XB: (x0,x1,x2) => new Uint8Array(x0,x1,x2),
      XC: (x0,x1,x2,x3) => x0.setProperty(x1,x2,x3),
      XD: x0 => x0.right,
      XE: o => {
        if (o === undefined) return 1;
        var type = typeof o;
        if (type === 'boolean') return 2;
        if (type === 'number') return 3;
        if (type === 'string') return 4;
        if (o instanceof Array) return 5;
        if (ArrayBuffer.isView(o)) {
          if (o instanceof Int8Array) return 6;
          if (o instanceof Uint8Array) return 7;
          if (o instanceof Uint8ClampedArray) return 8;
          if (o instanceof Int16Array) return 9;
          if (o instanceof Uint16Array) return 10;
          if (o instanceof Int32Array) return 11;
          if (o instanceof Uint32Array) return 12;
          if (o instanceof Float32Array) return 13;
          if (o instanceof Float64Array) return 14;
          if (o instanceof DataView) return 15;
        }
        if (o instanceof ArrayBuffer) return 16;
        // Feature check for `SharedArrayBuffer` before doing a type-check.
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
            return 17;
        }
        if (o instanceof Promise) return 18;
        return 19;
      },
      XF: x0 => x0.innerHeight,
      XG: x0 => x0.status,
      XH: (x0,x1) => { x0.className = x1 },
      XI: x0 => x0.naturalWidth,
      XJ: x0 => x0.statusText,
      XK: x0 => x0.navigator,
      XL: x0 => x0.buffered,
      XM: (x0,x1) => x0.loadModule(x1),
      XN: (x0,x1) => { x0.height = x1 },
      XO: (x0,x1) => { x0.spellcheck = x1 },
      XP: (x0,x1) => ({i: x0,p: x1}),
      XQ: (x0,x1,x2) => x0.sqlite3_result_int64(x1,x2),
      XR: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2,x3) { return wasmFunction(f,arguments.length,x0,x1,x2,x3) }),
      XS: (x0,x1) => { x0.onupgradeneeded = x1 },
      XT: x0 => x0.stop(),
      XU: (x0,x1) => { x0.referrerPolicy = x1 },
      Y: x0 => x0.unicode,
      YB: (x0,x1,x2) => new DataView(x0,x1,x2),
      YC: x0 => x0.style,
      YD: x0 => x0.left,
      YE: x0 => x0.language,
      YF: x0 => x0.innerWidth,
      YG: (x0,x1,x2) => x0.set(x1,x2),
      YH: (x0,x1) => { x0.tabIndex = x1 },
      YI: (x0,x1) => x0.createElement(x1),
      YJ: x0 => x0.url,
      YK: () => globalThis.window,
      YL: x0 => x0.duration,
      YM: (x0,x1) => x0.unloadModule(x1),
      YN: (x0,x1) => { x0.width = x1 },
      YO: (x0,x1) => { x0.disabled = x1 },
      YP: (x0,x1) => ({c: x0,r: x1}),
      YQ: (x0,x1) => x0.sqlite3_result_null(x1),
      YR: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2) { return wasmFunction(f,arguments.length,x0,x1,x2) }),
      YS: x0 => ({autoIncrement: x0}),
      YT: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      YU: x0 => x0.referrerPolicy,
      Z: x0 => x0.ignoreCase,
      ZB: (o, p) => o[p],
      ZC: x0 => x0.debugShowSemanticsNodes,
      ZD: x0 => x0.clientY,
      ZE: (x0,x1,x2,x3) => x0.register(x1,x2,x3),
      ZF: x0 => x0.height,
      ZG: x0 => x0.arrayBuffer(),
      ZH: (x0,x1) => { x0.name = x1 },
      ZI: (x0,x1) => { x0.pointerEvents = x1 },
      ZJ: x0 => x0.status,
      ZK: x0 => x0.abort(),
      ZL: x0 => x0.currentTime,
      ZM: x0 => x0.origin,
      ZN: x0 => x0.convertToBlob(),
      ZO: x0 => x0.canvasKitMaximumSurfaces,
      ZP: (x0,x1) => { x0.onmessage = x1 },
      ZQ: (x0,x1) => x0.sqlite3_value_blob(x1),
      ZR: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      ZS: (x0,x1,x2) => x0.createObjectStore(x1,x2),
      ZT: x0 => x0.start(),
      ZU: (x0,x1) => { x0.allowFullscreen = x1 },
      a: x0 => x0.multiline,
      aB: (o) => new DataView(o.buffer, o.byteOffset, o.byteLength),
      aC: (x0,x1) => x0.warn(x1),
      aD: x0 => x0.clientX,
      aE: () => globalThis.window.FinalizationRegistry,
      aF: x0 => x0.width,
      aG: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof ArrayBuffer) return 1;
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
          return 2;
        }
        return 3;
      },
      aH: (x0,x1) => { x0.placeholder = x1 },
      aI: (x0,x1) => { x0.height = x1 },
      aJ: x0 => x0.getReader(),
      aK: () => new Headers(),
      aL: (o, p, v) => o[p] = v,
      aM: (x0,x1) => x0.append(x1),
      aN: (x0,x1,x2) => new ImageData(x0,x1,x2),
      aO: x0 => x0.nextSibling,
      aP: (o, a) => o == a,
      aQ: (x0,x1) => x0.sqlite3_value_bytes(x1),
      aR: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      aS: x0 => ({unique: x0}),
      aT: (x0,x1) => { x0.lang = x1 },
      aU: x0 => x0.allowFullscreen,
      b: (exn) => {
        if (exn instanceof Error) {
          return exn.stack;
        } else {
          return null;
        }
      },
      bB: Function.prototype.call.bind(Object.getOwnPropertyDescriptor(DataView.prototype, 'byteLength').get),
      bC: x0 => x0.console,
      bD: x0 => x0.changedTouches,
      bE: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      bF: x0 => x0.clientHeight,
      bG: (x0,x1) => x0.fetch(x1),
      bH: (x0,x1) => { x0.autocomplete = x1 },
      bI: (x0,x1) => { x0.width = x1 },
      bJ: x0 => x0.read(),
      bK: (x0,x1) => ({headers: x0,signal: x1}),
      bL: (x0,x1) => { x0.border = x1 },
      bM: (x0,x1,x2) => x0.insertRule(x1,x2),
      bN: (x0,x1) => x0.getContext(x1),
      bO: (x0,x1) => x0.debug(x1),
      bP: x0 => x0.r,
      bQ: (x0,x1) => x0.sqlite3_value_text(x1),
      bR: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      bS: (x0,x1,x2,x3) => x0.createIndex(x1,x2,x3),
      bT: (x0,x1) => { x0.continuous = x1 },
      bU: (x0,x1) => { x0.allow = x1 },
      c: (c) =>
      queueMicrotask(() => dartInstance.exports.$invokeCallback(c)),
      cB: o => o.byteOffset,
      cC: () => globalThis.window,
      cD: x0 => x0.offsetY,
      cE: x0 => new window.FinalizationRegistry(x0),
      cF: x0 => x0.clientWidth,
      cG: x0 => x0.fontFallbackBaseUrl,
      cH: (x0,x1) => { x0.name = x1 },
      cI: x0 => x0.style,
      cJ: x0 => x0.value,
      cK: (x0,x1,x2) => x0.fetch(x1,x2),
      cL: (x0,x1) => { x0.height = x1 },
      cM: (x0,x1) => x0.add(x1),
      cN: (x0,x1) => new OffscreenCanvas(x0,x1),
      cO: (x0,x1) => { x0.mode = x1 },
      cP: x0 => x0.c,
      cQ: (x0,x1) => x0.sqlite3_value_double(x1),
      cR: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      cS: (x0,x1) => x0.createObjectStore(x1),
      cT: (x0,x1) => { x0.interimResults = x1 },
      cU: x0 => x0.allow,
      d: (x0,x1) => x0.didCreateEngineInitializer(x1),
      dB: o => o.buffer,
      dC: (o, c) => o instanceof c,
      dD: x0 => x0.offsetX,
      dE: (x0,x1) => x0.unregister(x1),
      dF: (x0,x1) => { x0.content = x1 },
      dG: (handle) => clearInterval(handle),
      dH: (x0,x1) => { x0.placeholder = x1 },
      dI: (x0,x1) => { x0.src = x1 },
      dJ: x0 => x0.done,
      dK: x0 => x0.ok,
      dL: (x0,x1) => { x0.width = x1 },
      dM: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      dN: x0 => x0.allocationSize(),
      dO: x0 => x0.track,
      dP: x0 => x0.p,
      dQ: (x0,x1) => x0.sqlite3_value_int64(x1),
      dR: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2,x3) { return wasmFunction(f,arguments.length,x0,x1,x2,x3) }),
      dS: x0 => x0.oldVersion,
      dT: (x0,x1) => { x0.onresult = x1 },
      dU: (x0,x1) => { x0.display = x1 },
      e: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      eB: Function.prototype.call.bind(DataView.prototype.getUint8),
      eC: (x0,x1) => x0[x1],
      eD: x0 => x0.type,
      eE: (x0,x1) => x0.contains(x1),
      eF: (x0,x1) => { x0.name = x1 },
      eG: (ms, c) =>
      setInterval(() => dartInstance.exports.$invokeCallback(c), ms),
      eH: (x0,x1) => { x0.action = x1 },
      eI: () => globalThis.document,
      eJ: x0 => x0.cancel(),
      eK: (x0,x1,x2) => x0.append(x1,x2),
      eL: x0 => x0.style,
      eM: x0 => x0.preventDefault(),
      eN: (x0,x1) => x0.copyTo(x1),
      eO: (x0,x1) => x0[x1],
      eP: x0 => x0.i,
      eQ: (x0,x1) => x0.sqlite3_value_type(x1),
      eR: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2,x3) { return wasmFunction(f,arguments.length,x0,x1,x2,x3) }),
      eS: () => globalThis.indexedDB,
      eT: (x0,x1) => x0.item(x1),
      eU: x0 => x0.src,
      f: (wasmFunction,f) => finalizeWrapper(f, function() { return wasmFunction(f,arguments.length) }),
      fB: (b, o) => new DataView(b, o),
      fC: x0 => x0.length,
      fD: x0 => x0.maxTouchPoints,
      fE: s => s.toUpperCase(),
      fF: x0 => x0.head,
      fG: () => Date.now(),
      fH: (x0,x1) => { x0.method = x1 },
      fI: x0 => x0.src,
      fJ: x0 => x0.body,
      fK: x0 => x0.protocol,
      fL: (x0,x1) => { x0.controls = x1 },
      fM: x0 => x0.createRange(),
      fN: (x0,x1) => { x0.height = x1 },
      fO: x0 => x0.length,
      fP: x0 => x0.port1,
      fQ: (x0,x1,x2) => x0.sqlite3_extended_result_codes(x1,x2),
      fR: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      fS: (x0,x1) => ({name: x0,length: x1}),
      fT: (x0,x1) => x0.item(x1),
      fU: (x0,x1) => x0.item(x1),
      g: (x0,x1) => ({initializeEngine: x0,autoStart: x1}),
      gB: (b, o, l) => new DataView(b, o, l),
      gC: (string, token) => string.split(token),
      gD: x0 => x0.platform,
      gE: x0 => x0.pop(),
      gF: (x0,x1) => x0.removeChild(x1),
      gG: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      gH: (x0,x1) => { x0.noValidate = x1 },
      gI: (x0,x1) => x0.revokeObjectURL(x1),
      gJ: x0 => x0.headers,
      gK: (x0,x1,x2) => x0.close(x1,x2),
      gL: (x0,x1) => x0.appendChild(x1),
      gM: (x0,x1) => x0.selectNode(x1),
      gN: (x0,x1) => { x0.width = x1 },
      gO: x0 => x0.textTracks,
      gP: (x0,x1) => x0.sqlite3_finalize(x1),
      gQ: (x0,x1,x2,x3,x4) => x0.sqlite3_open_v2(x1,x2,x3,x4),
      gR: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      gS: (x0,x1) => x0.update(x1),
      gT: x0 => x0.confidence,
      gU: x0 => x0.length,
      h: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      hB: Function.prototype.call.bind(DataView.prototype.getFloat64),
      hC: o => o instanceof Array,
      hD: x0 => x0.body,
      hE: x0 => x0.flags,
      hF: x0 => x0.firstChild,
      hG: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF64ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      hH: (x0,x1) => x0.removeAttribute(x1),
      hI: (x0,x1) => { x0.src = x1 },
      hJ: x0 => x0.signal,
      hK: x0 => x0.close(),
      hL: x0 => x0.click(),
      hM: x0 => x0.getSelection(),
      hN: (x0,x1) => x0.toDataURL(x1),
      hO: x0 => x0.destroy(),
      hP: (x0,x1) => x0.dart_sqlite3_free(x1),
      hQ: (x0,x1) => x0.call(x1),
      hR: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      hS: x0 => x0.name,
      hT: x0 => x0.transcript,
      hU: x0 => x0.sandbox,
      i: x0 => new Promise(x0),
      iB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float64Array) return 1;
        return 2;
      },
      iC: (a, i, v) => a[i] = v,
      iD: () => globalThis.document,
      iE: (s) => +s,
      iF: x0 => x0.viewConstraints,
      iG: (x0,x1,x2,x3) => x0.pushState(x1,x2,x3),
      iH: x0 => x0.isConnected,
      iI: (x0,x1,x2,x3,x4) => globalThis.createImageBitmap(x0,x1,x2,x3,x4),
      iJ: (o, p) => p in o,
      iK: (x0,x1) => x0.send(x1),
      iL: x0 => x0.body,
      iM: x0 => x0.removeAllRanges(),
      iN: (x0,x1,x2,x3) => x0.drawImage(x1,x2,x3),
      iO: x0 => x0.dispose(),
      iP: (x0,x1) => x0.sqlite3_reset(x1),
      iQ: x0 => x0.sqlite3_initialize,
      iR: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      iS: x0 => globalThis.IDBKeyRange.only(x0),
      iT: x0 => x0.length,
      iU: x0 => x0.id,
      j: (x0,x1,x2) => x0.call(x1,x2),
      jB: Function.prototype.call.bind(DataView.prototype.setFloat64),
      jC: (a, i) => a[i],
      jD: (x0,x1,x2) => x0.addEventListener(x1,x2),
      jE: s => {
        if (!/^\s*[+-]?(?:Infinity|NaN|(?:\.\d+|\d+(?:\.\d*)?)(?:[eE][+-]?\d+)?)\s*$/.test(s)) {
          return NaN;
        }
        return parseFloat(s);
      },
      jF: x0 => x0.hostElement,
      jG: x0 => x0.history,
      jH: x0 => x0.click(),
      jI: x0 => x0.naturalHeight,
      jJ: x0 => x0.groups,
      jK: () => new Array(),
      jL: (x0,x1) => { x0.target = x1 },
      jM: (x0,x1) => x0.addRange(x1),
      jN: (x0,x1) => x0.getContext(x1),
      jO: x0 => x0.kind,
      jP: (x0,x1) => x0.unregister(x1),
      jQ: (x0,x1,x2,x3) => x0.dart_sqlite3_register_vfs(x1,x2,x3),
      jR: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      jS: (x0,x1,x2) => x0.put(x1,x2),
      jT: x0 => x0.length,
      jU: (x0,x1) => x0.getCookieExpirationDate(x1),
      k: (constructor, args) => {
        const factoryFunction = constructor.bind.apply(
            constructor, [null, ...args]);
        return new factoryFunction();
      },
      kB: Function.prototype.call.bind(DataView.prototype.setUint8),
      kC: a => a.length,
      kD: x0 => x0.hasFocus(),
      kE: s => s.trim(),
      kF: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      kG: x0 => x0.search,
      kH: (x0,x1) => x0.getElementsByClassName(x1),
      kI: x0 => x0.naturalWidth,
      kJ: () => new XMLHttpRequest(),
      kK: (x0,x1) => new WebSocket(x0,x1),
      kL: (x0,x1) => { x0.rel = x1 },
      kM: () => globalThis.window,
      kN: x0 => x0.format,
      kO: x0 => x0.language,
      kP: x0 => x0.buffer,
      kQ: x0 => x0.close(),
      kR: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      kS: (x0,x1) => x0.getKey(x1),
      kT: x0 => x0.results,
      kU: (o, a) => o + a,
      l: x0 => new Array(x0),
      lB: (t, s) => t.set(s),
      lC: (x0,x1) => x0.test(x1),
      lD: x0 => x0.relatedTarget,
      lE: x0 => x0.classList,
      lF: x0 => ({runApp: x0}),
      lG: x0 => x0.location,
      lH: (x0,x1) => x0.dispatchEvent(x1),
      lI: x0 => x0.decode(),
      lJ: (x0,x1,x2) => x0.open(x1,x2),
      lK: x0 => x0.reason,
      lL: (x0,x1) => { x0.download = x1 },
      lM: (x0,x1) => { x0.innerText = x1 },
      lN: (x0,x1) => { x0.objectFit = x1 },
      lO: x0 => x0.label,
      lP: (x0,x1) => x0.sqlite3_errstr(x1),
      lQ: (x0,x1) => globalThis.Atomics.load(x0,x1),
      lR: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2) { return wasmFunction(f,arguments.length,x0,x1,x2) }),
      lS: (x0,x1) => x0.delete(x1),
      lT: x0 => x0.abort(),
      lU: x0 => new Blob(x0),
      m: o => [o],
      mB: Function.prototype.call.bind(DataView.prototype.setFloat32),
      mC: x0 => x0.userAgent,
      mD: x0 => x0.shiftKey,
      mE: x0 => x0.preventDefault(),
      mF: (x0,x1) => x0.requestAnimationFrame(x1),
      mG: x0 => x0.pathname,
      mH: (x0,x1) => x0.createEvent(x1),
      mI: (x0,x1) => { x0.decoding = x1 },
      mJ: (x0,x1) => x0.send(x1),
      mK: x0 => x0.code,
      mL: (x0,x1) => { x0.href = x1 },
      mM: x0 => x0.offsetY,
      mN: (x0,x1) => x0.warn(x1),
      mO: (x0,x1) => { x0.line = x1 },
      mP: (x0,x1) => x0.sqlite3_errmsg(x1),
      mQ: (x0,x1,x2) => globalThis.Atomics.wait(x0,x1,x2),
      mR: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2) { return wasmFunction(f,arguments.length,x0,x1,x2) }),
      mS: (x0,x1) => x0.put(x1),
      mT: (x0,x1) => x0.key(x1),
      mU: x0 => globalThis.URL.revokeObjectURL(x0),
      n: (o0, o1) => [o0, o1],
      nB: Function.prototype.call.bind(DataView.prototype.getFloat32),
      nC: x0 => x0.navigator,
      nD: (decoder, codeUnits) => decoder.decode(codeUnits),
      nE: x0 => x0.parent,
      nF: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      nG: (x0,x1,x2,x3) => x0.replaceState(x1,x2,x3),
      nH: (x0,x1,x2,x3) => x0.initEvent(x1,x2,x3),
      nI: (x0,x1) => { x0.crossOrigin = x1 },
      nJ: x0 => x0.send(),
      nK: (o, t) => typeof o === t,
      nL: x0 => x0.disconnect(),
      nM: x0 => x0.offsetX,
      nN: () => globalThis.console,
      nO: (x0,x1) => { x0.snapToLines = x1 },
      nP: x0 => x0.sqlite3_error_offset,
      nQ: (x0,x1,x2) => globalThis.Atomics.notify(x0,x1,x2),
      nR: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2) { return wasmFunction(f,arguments.length,x0,x1,x2) }),
      nS: (x0,x1,x2) => x0.postMessage(x1,x2),
      nT: x0 => x0.length,
      nU: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      o: (o0, o1, o2) => [o0, o1, o2],
      oB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Float32Array) return 1;
        return 2;
      },
      oC: Function.prototype.call.bind(String.prototype.toLowerCase),
      oD: () => new TextDecoder("utf-8", {fatal: true}),
      oE: x0 => x0.timeStamp,
      oF: x0 => x0.now(),
      oG: o => {
        const proto = Object.getPrototypeOf(o);
        return proto === Object.prototype || proto === null;
      },
      oH: x0 => x0.readText(),
      oI: (x0,x1) => x0.createObjectURL(x1),
      oJ: x0 => x0.abort(),
      oK: x0 => x0.data,
      oL: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      oM: x0 => x0.button,
      oN: (x0,x1) => x0.querySelectorAll(x1),
      oO: x0 => x0.lineAlign,
      oP: (x0,x1) => x0.sqlite3_extended_errcode(x1),
      oQ: (x0,x1,x2) => globalThis.Atomics.store(x0,x1,x2),
      oR: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      oS: x0 => x0.port2,
      oT: (x0,x1,x2) => x0.setItem(x1,x2),
      oU: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      p: (o0, o1, o2, o3) => [o0, o1, o2, o3],
      pB: Function.prototype.call.bind(DataView.prototype.setUint32),
      pC: Object.is,
      pD: () => new TextDecoder("utf-8", {fatal: false}),
      pE: (x0,x1) => x0.hasAttribute(x1),
      pF: x0 => x0.performance,
      pG: o => Object.keys(o),
      pH: x0 => x0.clipboard,
      pI: x0 => x0.URL,
      pJ: x0 => x0.readyState,
      pK: x0 => x0.readyState,
      pL: x0 => x0.pauseVideo(),
      pM: x0 => x0.classList,
      pN: (x0,x1) => x0.item(x1),
      pO: (x0,x1) => { x0.lineAlign = x1 },
      pP: (x0,x1) => x0.sqlite3_step(x1),
      pQ: x0 => new Worker(x0),
      pR: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      pS: x0 => x0.terminate(),
      pT: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      pU: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      q: (x0,x1,x2) => { x0[x1] = x2 },
      qB: Function.prototype.call.bind(DataView.prototype.getUint32),
      qC: x0 => x0.vendor,
      qD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI8ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      qE: x0 => x0.buttons,
      qF: x0 => new Uint8Array(x0),
      qG: x0 => x0.state,
      qH: (x0,x1) => x0.writeText(x1),
      qI: x0 => new Blob(x0),
      qJ: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      qK: (x0,x1) => { x0.binaryType = x1 },
      qL: x0 => x0.destroy(),
      qM: x0 => x0.sheet,
      qN: x0 => x0.contentWindow,
      qO: (x0,x1) => x0[x1],
      qP: (x0,x1,x2,x3,x4,x5) => x0.sqlite3_bind_blob64(x1,x2,x3,x4,x5),
      qQ: () => globalThis.Uint8Array,
      qR: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      qS: (x0,x1) => new SharedWorker(x0,x1),
      qT: x0 => x0.firstElementChild,
      qU: (x0,x1) => x0.removeChild(x1),
      r: (o, p) => o[p],
      rB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Uint32Array) return 1;
        return 2;
      },
      rC: (x0,x1) => x0.createTextNode(x1),
      rD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI16ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      rE: x0 => x0.ctrlKey,
      rF: (x0,x1,x2) => x0.slice(x1,x2),
      rG: x0 => x0.hash,
      rH: x0 => x0.unlock(),
      rI: x0 => x0.close(),
      rJ: (x0,x1,x2,x3) => x0.removeEventListener(x1,x2,x3),
      rK: x0 => x0.play(),
      rL: x0 => x0.mute(),
      rM: x0 => x0.head,
      rN: x0 => x0.length,
      rO: x0 => x0.length,
      rP: x0 => globalThis.BigInt(x0),
      rQ: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof DataView) return 1;
        return 2;
      },
      rR: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2,x3,x4) { return wasmFunction(f,arguments.length,x0,x1,x2,x3,x4) }),
      rS: x0 => x0.start(),
      rT: x0 => x0.permissions,
      rU: x0 => x0.firstChild,
      s: () => globalThis,
      sB: Function.prototype.call.bind(DataView.prototype.setInt32),
      sC: (x0,x1) => { x0.id = x1 },
      sD: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      sE: x0 => x0.y,
      sF: (x0,x1) => x0.decode(x1),
      sG: x0 => x0.state,
      sH: (x0,x1) => x0.lock(x1),
      sI: (x0,x1) => ({frameIndex: x0,completeFramesOnly: x1}),
      sJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      sK: x0 => x0.message,
      sL: x0 => x0.unMute(),
      sM: x0 => x0.clearMarks(),
      sN: (x0,x1) => x0.removeAttribute(x1),
      sO: x0 => x0.activeCues,
      sP: (x0,x1) => x0.dart_sqlite3_malloc(x1),
      sQ: () => globalThis.DataView,
      sR: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2,x3,x4) { return wasmFunction(f,arguments.length,x0,x1,x2,x3,x4) }),
      sS: x0 => x0.port,
      sT: x0 => x0.geolocation,
      sU: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      t: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      tB: Function.prototype.call.bind(DataView.prototype.getInt32),
      tC: (x0,x1) => { x0.nonce = x1 },
      tD: x0 => x0.visibilityState,
      tE: x0 => x0.x,
      tF: (x0,x1) => x0.adoptText(x1),
      tG: (x0,x1) => x0.go(x1),
      tH: x0 => x0.orientation,
      tI: (x0,x1) => x0.decode(x1),
      tJ: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      tK: x0 => ({xhrSetup: x0}),
      tL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      tM: x0 => x0.clearMeasures(),
      tN: (x0,x1) => x0.destroy(x1),
      tO: (x0,x1) => { x0.textContent = x1 },
      tP: (x0,x1,x2,x3,x4,x5) => x0.sqlite3_bind_text(x1,x2,x3,x4,x5),
      tQ: x0 => x0.communicationBuffer,
      tR: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      tS: (x0,x1) => x0.fetch(x1),
      tT: x0 => x0.mediaDevices,
      tU: (x0,x1) => x0.item(x1),
      u: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      uB: o => {
        if (o === null || o === undefined) return 0;
        if (o instanceof Int32Array) return 1;
        return 2;
      },
      uC: x0 => x0.nonce,
      uD: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      uE: x0 => x0.scrollTop,
      uF: x0 => x0.first(),
      uG: x0 => x0.parentElement,
      uH: (x0,x1) => x0.querySelector(x1),
      uI: x0 => x0.displayHeight,
      uJ: x0 => x0.upload,
      uK: x0 => new Hls(x0),
      uL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      uM: (x0,x1) => x0.parse(x1),
      uN: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      uO: (x0,x1) => x0.destroy(x1),
      uP: (x0,x1,x2,x3) => x0.sqlite3_bind_double(x1,x2,x3),
      uQ: () => globalThis.Int32Array,
      uR: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      uS: x0 => x0.text(),
      uT: x0 => x0.document,
      uU: () => new FileReader(),
      v: (x0,x1) => ({addView: x0,removeView: x1}),
      vB: o => o instanceof Uint16Array,
      vC: () => globalThis.window.flutterConfiguration,
      vD: x0 => x0.disconnect(),
      vE: x0 => x0.offsetTop,
      vF: x0 => x0.next(),
      vG: (x0,x1) => x0.querySelectorAll(x1),
      vH: (x0,x1) => { x0.title = x1 },
      vI: x0 => x0.displayWidth,
      vJ: x0 => x0.responseURL,
      vK: (x0,x1) => x0.loadSource(x1),
      vL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      vM: (x0,x1,x2) => x0.mark(x1,x2),
      vN: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      vO: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      vP: (x0,x1,x2,x3) => x0.sqlite3_bind_int64(x1,x2,x3),
      vQ: x0 => x0.byteLength,
      vR: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      vS: x0 => x0.hostElement,
      vT: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      vU: (x0,x1) => x0.readAsDataURL(x1),
      w: (l, r) => l === r,
      wB: Function.prototype.call.bind(DataView.prototype.setUint16),
      wC: (x0,x1) => x0.attachShadow(x1),
      wD: x0 => new Intl.Locale(x0),
      wE: x0 => x0.scrollLeft,
      wF: x0 => x0.current(),
      wG: (d, digits) => d.toFixed(digits),
      wH: (x0,x1) => x0.vibrate(x1),
      wI: x0 => x0.duration,
      wJ: x0 => x0.statusText,
      wK: (x0,x1) => x0.attachMedia(x1),
      wL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      wM: (x0,x1,x2,x3) => x0.measure(x1,x2,x3),
      wN: (x0,x1,x2,x3) => x0.canUseHlsJs(x1,x2,x3),
      wO: (x0,x1) => { x0.srclang = x1 },
      wP: (x0,x1,x2) => x0.sqlite3_bind_null(x1,x2),
      wQ: x0 => x0.synchronizationBuffer,
      wR: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1) { return wasmFunction(f,arguments.length,x0,x1) }),
      wS: x0 => x0.location,
      wT: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      wU: (x0,x1) => x0.readAsArrayBuffer(x1),
      x: x0 => x0.random(),
      xB: Function.prototype.call.bind(DataView.prototype.getUint16),
      xC: (x0,x1) => x0.createElement(x1),
      xD: x0 => x0.region,
      xE: x0 => x0.offsetLeft,
      xF: (x0,x1) => new Intl.v8BreakIterator(x0,x1),
      xG: x0 => x0.maxHeight,
      xH: x0 => x0.content,
      xI: x0 => x0.image,
      xJ: x0 => x0.getAllResponseHeaders(),
      xK: (x0,x1) => x0.canPlayType(x1),
      xL: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      xM: () => globalThis.JSON,
      xN: (x0,x1,x2,x3) => x0.attach(x1,x2,x3),
      xO: (x0,x1) => { x0.label = x1 },
      xP: (x0,x1) => x0.sqlite3_bind_parameter_count(x1),
      xQ: (x0,x1,x2) => x0.postMessage(x1,x2),
      xR: (wasmFunction,f) => finalizeWrapper(f, function(x0,x1,x2) { return wasmFunction(f,arguments.length,x0,x1,x2) }),
      xS: (x0,x1) => x0.getModifierState(x1),
      xT: (wasmFunction,f) => finalizeWrapper(f, function(x0) { return wasmFunction(f,arguments.length,x0) }),
      xU: x0 => x0.size,
      y: () => globalThis.Math,
      yB: o => o instanceof Int16Array,
      yC: x0 => x0.scale,
      yD: x0 => x0.script,
      yE: x0 => x0.offsetParent,
      yF: x0 => x0.v8BreakIterator,
      yG: x0 => x0.maxWidth,
      yH: x0 => x0.document,
      yI: (x0,x1,x2,x3,x4) => ({type: x0,data: x1,premultiplyAlpha: x2,colorSpaceConversion: x3,preferAnimation: x4}),
      yJ: x0 => x0.status,
      yK: () => globalThis.Hls.isSupported(),
      yL: () => new AudioContext(),
      yM: x0 => x0.clearMarks,
      yN: (x0,x1) => { x0.backgroundColor = x1 },
      yO: (x0,x1) => { x0.src = x1 },
      yP: (x0,x1) => x0.sqlite3_stmt_isexplain(x1),
      yQ: x0 => new SharedArrayBuffer(x0),
      yR: (x0,x1) => x0.sqlite3_user_data(x1),
      yS: x0 => x0.metaKey,
      yT: x0 => x0.id,
      yU: x0 => x0.name,
      z: (x0,x1) => x0.prepend(x1),
      zB: Function.prototype.call.bind(DataView.prototype.setInt16),
      zC: x0 => x0.visualViewport,
      zD: x0 => x0.language,
      zE: (o, p, r) => o.replace(p, () => r),
      zF: () => globalThis.Intl,
      zG: x0 => x0.minHeight,
      zH: () => typeof dartUseDateNowForTicks !== "undefined",
      zI: x0 => new window.ImageDecoder(x0),
      zJ: x0 => x0.response,
      zK: x0 => x0.userAgent,
      zL: x0 => x0.close(),
      zM: x0 => x0.clearMeasures,
      zN: (x0,x1) => { x0.loop = x1 },
      zO: (x0,x1) => { x0.kind = x1 },
      zP: (x0,x1,x2,x3,x4,x5,x6) => x0.sqlite3_prepare_v3(x1,x2,x3,x4,x5,x6),
      zQ: (x0,x1,x2,x3) => ({clientVersion: x0,root: x1,synchronizationBuffer: x2,communicationBuffer: x3}),
      zR: x0 => ({at: x0}),
      zS: x0 => x0.altKey,
      zT: x0 => x0.index,
      zU: x0 => x0.type,

    };

    const baseImports = {
      _: dart2wasm,
      Math: Math,
      Date: Date,
      Object: Object,
      Array: Array,
      Reflect: Reflect,
      WebAssembly: {
        JSTag: WebAssembly.JSTag,
      },
      "": new Proxy({}, { get(_, prop) { return prop; } }),

    };

    const jsStringPolyfill = {
      "charCodeAt": (s, i) => s.charCodeAt(i),
      "compare": (s1, s2) => {
        if (s1 < s2) return -1;
        if (s1 > s2) return 1;
        return 0;
      },
      "concat": (s1, s2) => s1 + s2,
      "equals": (s1, s2) => s1 === s2,
      "fromCharCode": (i) => String.fromCharCode(i),
      "length": (s) => s.length,
      "substring": (s, a, b) => s.substring(a, b),
      "fromCharCodeArray": (a, start, end) => {
        if (end <= start) return '';

        const read = dartInstance.exports.$wasmI16ArrayGet;
        let result = '';
        let index = start;
        const chunkLength = Math.min(end - index, 500);
        let array = new Array(chunkLength);
        while (index < end) {
          const newChunkLength = Math.min(end - index, 500);
          for (let i = 0; i < newChunkLength; i++) {
            array[i] = read(a, index++);
          }
          if (newChunkLength < chunkLength) {
            array = array.slice(0, newChunkLength);
          }
          result += String.fromCharCode(...array);
        }
        return result;
      },
      "intoCharCodeArray": (s, a, start) => {
        if (s === '') return 0;

        const write = dartInstance.exports.$wasmI16ArraySet;
        for (var i = 0; i < s.length; ++i) {
          write(a, start++, s.charCodeAt(i));
        }
        return s.length;
      },
      "test": (s) => typeof s == "string",
    };


    

    dartInstance = await WebAssembly.instantiate(this.module, {
      ...baseImports,
      ...additionalImports,
      
      "wasm:js-string": jsStringPolyfill,
    });

    return new InstantiatedApp(this, dartInstance);
  }
}

class InstantiatedApp {
  constructor(compiledApp, instantiatedModule) {
    this.compiledApp = compiledApp;
    this.instantiatedModule = instantiatedModule;
  }

  // Call the main function with the given arguments.
  invokeMain(...args) {
    this.instantiatedModule.exports.$invokeMain(args);
  }
}
