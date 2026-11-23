const results = document.getElementById('results');
function status(name, success, details = '') {
  const row = document.createElement('div');
  row.className = 'result';
  row.innerHTML = `<b>${name}:</b> <span class="${success ? 'ok' : 'no'}">${success ? 'OK' : 'Unavailable'}</span> ${details}`;
  results.appendChild(row);
}

status('JavaScript ES module', true, 'Loaded from a relative path');
status('WebSocket API', typeof WebSocket === 'function');
status('WebGPU API', !!navigator.gpu, '(hardware/OS/WebKit-dependent)');
status('Secure context', window.isSecureContext, '(localhost origin)');
status('CSS styles', getComputedStyle(document.body).backgroundColor === 'rgb(13, 19, 34)');

try {
  const stored = localStorage.getItem('sample-counter') || '0';
  status('localStorage', true, `Stored counter: ${stored}`);
  document.getElementById('persist').onclick = () => {
    localStorage.setItem('sample-counter', String(Number(localStorage.getItem('sample-counter') || 0) + 1));
    location.reload();
  };
} catch (e) { status('localStorage', false, e.message); }

try {
  const { instance } = await WebAssembly.instantiateStreaming(fetch('./answer.wasm'));
  status('WebAssembly + fetch', instance.exports.answer() === 42, `Result: ${instance.exports.answer()}`);
} catch (e) { status('WebAssembly + fetch', false, e.message); }

const canvas = document.getElementById('canvas');
const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
status('WebGL', !!gl);
if (gl) {
  gl.clearColor(0.1, 0.55, 0.85, 1.0);
  gl.clear(gl.COLOR_BUFFER_BIT);
}

document.getElementById('fullscreen').onclick = async () => {
  try { await document.documentElement.requestFullscreen(); }
  catch (e) { alert(`Web page fullscreen is not supported: ${e.message}. Use the viewer's Fullscreen mode instead.`); }
};
