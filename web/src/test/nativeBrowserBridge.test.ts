/// <reference types="node" />
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

interface Page {
  url: string;
  text: string;
  title: string;
  elements: { ref: number; name: string; value?: string }[];
}
interface Bridge {
  snapshot(): Promise<Page>;
  click(ref: number, expected: { url: string; text: string; name: string; fields?: { ref: number; value: string; checked: boolean }[] } | null): Promise<unknown>;
  typeText(ref: number, text: string): Promise<unknown>;
  stop(): void;
}
type BridgeWindow = Window & { agentBridge?: Bridge; didSubmit?: boolean };
const browser = window as BridgeWindow;
const source = readFileSync(resolve(process.cwd(), '../ios/Nudge/Resources/agent-bridge.js'), 'utf8');

/** Execute the actual bundled iOS bridge, not a copy of its safeguards. */
function mount(html: string): Bridge {
  document.body.innerHTML = html;
  window.eval(source);
  if (!browser.agentBridge) throw new Error('Bridge missing');
  return browser.agentBridge;
}

describe('native browser bridge safeguards in a DOM harness', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.spyOn(HTMLElement.prototype, 'getBoundingClientRect').mockReturnValue({ x: 0, y: 0, top: 0, left: 0, right: 300, bottom: 44, width: 300, height: 44, toJSON: () => ({}) });
    vi.stubGlobal('CSS', { escape: (value: string) => value });
    Object.defineProperty(HTMLElement.prototype, 'innerText', { configurable: true, get() { return this.textContent ?? ''; } });
    Object.defineProperty(HTMLElement.prototype, 'scrollIntoView', { configurable: true, value: vi.fn() });
  });
  afterEach(() => {
    delete browser.agentBridge;
    delete browser.didSubmit;
    document.body.innerHTML = '';
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
    vi.useRealTimers();
  });

  it('redacts the entire credential page before observation', async () => {
    const bridge = mount('<label for="u">Username</label><input id="u" value="never-share"><input type="password" value="never-share-password">');
    const page = await bridge.snapshot();
    expect(page.title).toBe('Sign in');
    expect(page.elements).toEqual([]);
    expect(JSON.stringify(page)).not.toContain('never-share');
  });

  it('refuses submission without a page-bound approval', async () => {
    const bridge = mount('<form><button type="submit">Send message</button></form>');
    const page = await bridge.snapshot();
    await expect(bridge.click(page.elements[0].ref, null)).rejects.toThrow('approval');
  });

  it('rejects a changed proposal before clicking', async () => {
    const bridge = mount('<h1>Review appointment</h1><button>Book appointment</button>');
    const page = await bridge.snapshot();
    document.querySelector('h1')!.textContent = 'Different appointment';
    const click = vi.fn();
    document.querySelector('button')!.addEventListener('click', click);
    const action = bridge.click(page.elements[0].ref, { url: page.url, text: page.text, name: page.elements[0].name, fields: [] });
    const assertion = expect(action).rejects.toThrow('changed');
    await vi.advanceTimersByTimeAsync(450);
    await assertion;
    expect(click).not.toHaveBeenCalled();
  });

  it('Stop cancels a click during its highlight delay', async () => {
    const bridge = mount('<button>Book appointment</button>');
    const page = await bridge.snapshot();
    const click = vi.fn();
    document.querySelector('button')!.addEventListener('click', click);
    const action = bridge.click(page.elements[0].ref, { url: page.url, text: page.text, name: page.elements[0].name });
    const assertion = expect(action).rejects.toThrow('Stopped');
    bridge.stop();
    await vi.advanceTimersByTimeAsync(450);
    await assertion;
    expect(click).not.toHaveBeenCalled();
  });
});
