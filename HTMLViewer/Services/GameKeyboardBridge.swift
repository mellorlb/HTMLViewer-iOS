import Foundation

/// Page-world helper used only by the explicit Game Keyboard action.
/// It does not intercept or alter normal keystrokes or web forms.
enum GameKeyboardBridge {
    static let script = #"""
    (() => {
      if (window.__htmlViewerGameKeys) return;
      const codes = {
        ' ': ['Space', 32], '-': ['Minus', 189], '_': ['Minus', 189],
        '.': ['Period', 190], ',': ['Comma', 188], '/': ['Slash', 191],
        ':': ['Semicolon', 186], ';': ['Semicolon', 186],
        "'": ['Quote', 222], '"': ['Quote', 222],
        '!': ['Digit1', 49], '@': ['Digit2', 50],
        '#': ['Digit3', 51], '$': ['Digit4', 52],
        '?': ['Slash', 191], '=': ['Equal', 187], '+': ['Equal', 187]
      };
      function keyInfo(char) {
        if (/^[a-z]$/i.test(char)) {
          const c = char.toUpperCase();
          return ['Key' + c, c.charCodeAt(0)];
        }
        if (/^[0-9]$/.test(char)) return ['Digit' + char, char.charCodeAt(0)];
        return codes[char] || ['Unidentified', char.codePointAt(0) || 0];
      }
      function target() {
        const focused = document.activeElement;
        if (focused && focused !== document.body && focused !== document.documentElement) return focused;
        return document.querySelector('canvas') || document.body || document;
      }
      function sendKey(k, config = {}) {
        const [code, legacy] = k === 'Enter' ? ['Enter', 13]
          : k === 'Backspace' ? ['Backspace', 8]
          : keyInfo(k);
        const dest = target();
        const common = { key: k, code, bubbles: true, cancelable: true,
          ctrlKey: !!config.ctrlKey, metaKey: !!config.metaKey,
          shiftKey: k.length === 1 && k !== k.toLowerCase() };
        for (const type of (k === 'Backspace' || k === 'Enter' ? ['keydown', 'keyup'] : ['keydown', 'keypress', 'keyup'])) {
          const evt = new KeyboardEvent(type, common);
          // WebGL games sometimes use the old KeyboardEvent.keyCode/which.
          const char = k.length === 1 ? k.codePointAt(0) : 0;
          const value = type === 'keypress' ? char : legacy;
          try { Object.defineProperty(evt, 'keyCode', { get: () => value });
                Object.defineProperty(evt, 'which', { get: () => value });
                Object.defineProperty(evt, 'charCode', { get: () => type === 'keypress' ? char : 0 }); } catch (_) {}
          dest.dispatchEvent(evt);
        }
      }
      window.__htmlViewerGameKeys = Object.freeze({
        send(text, replace, enter) {
          const content = String(text || '');
          const active = document.activeElement;
          // Standard input elements should get input/change events instead of
          // simulated keyboard events; React-compatible native value setter.
          if (active && (active instanceof HTMLInputElement || active instanceof HTMLTextAreaElement)) {
            const next = replace ? content : active.value + content;
            const proto = active instanceof HTMLInputElement ? HTMLInputElement.prototype : HTMLTextAreaElement.prototype;
            const setter = Object.getOwnPropertyDescriptor(proto, 'value')?.set;
            if (setter) setter.call(active, next); else active.value = next;
            active.dispatchEvent(new Event('input', { bubbles: true }));
            active.dispatchEvent(new Event('change', { bubbles: true }));
            if (enter) sendKey('Enter');
            return 'dom-input';
          }
          // Canvas apps draw the text field themselves and usually listen for
          // keyboard events. Backspace removes the existing username even if
          // Ctrl+A selection is unsupported by the game's keyboard handler.
          if (replace) {
            for (let i = 0; i < 32; ++i) sendKey('Backspace');
          }
          for (const char of content) sendKey(char);
          if (enter) sendKey('Enter');
          return 'canvas-events';
        }
      });
    })();
    """#
}
