#!/usr/bin/env node
// Cross-platform smoke test for the optional page-world keyboard bridge.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const root = require('node:path').join(__dirname, '..');
const swift = fs.readFileSync(require('node:path').join(root, 'HTMLViewer/Services/GameKeyboardBridge.swift'), 'utf8');
const match = swift.match(/static let script = #"""([\s\S]*?)"""#/);
assert(match, 'Swift source must contain the page-world bridge');
const script = match[1];
const events = [];
class KeyEvent { constructor(type, props) { this.type = type; Object.assign(this, props); } }
class GenericEvent { constructor(type, props) { this.type = type; Object.assign(this, props); } }
class Input { constructor() { this.value = 'old'; } dispatchEvent(e) { events.push(e); } }
class TextArea extends Input {}
const canvas = { dispatchEvent: e => events.push(e) };
const doc = { body: {}, documentElement: {}, activeElement: null, querySelector: tag => tag === 'canvas' ? canvas : null };
doc.activeElement = doc.body;
const sandbox = { window: {}, document: doc, HTMLInputElement: Input,
  HTMLTextAreaElement: TextArea, KeyboardEvent: KeyEvent, Event: GenericEvent };
vm.runInNewContext(script, sandbox);
assert.equal(sandbox.window.__htmlViewerGameKeys.send('New', true, true), 'canvas-events');
assert.equal(events.filter(e => e.type === 'keydown' && e.key === 'Backspace').length, 32);
assert.equal(events.filter(e => e.type === 'keydown' && e.key === 'Enter').length, 1);
assert.equal(events.filter(e => e.type === 'keypress').map(e => e.key).join(''), 'New');
events.length = 0;
const input = new Input();
doc.activeElement = input;
assert.equal(sandbox.window.__htmlViewerGameKeys.send('fresh', true, true), 'dom-input');
assert.equal(input.value, 'fresh');
assert(events.some(e => e.type === 'input'));
assert(events.some(e => e.type === 'change'));
assert.equal(events.filter(e => e.type === 'keydown' && e.key === 'Enter').length, 1);
console.log('PASS: canvas text events, clear/Enter and ordinary HTML input events');
