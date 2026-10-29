import React from 'react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { act, cleanup, fireEvent, render, screen, within } from '@testing-library/react';
import { SanoProvider } from '../sano/store';
import { SanoApp } from '../sano/SanoApp';

vi.mock('../sano/sound', () => ({ SoundEngine: new Proxy({}, { get: () => vi.fn() }), Haptics: new Proxy({}, { get: () => vi.fn() }) }));
vi.mock('../sano/ui/Orb', () => ({ Orb: () => <span aria-hidden="true" /> }));
vi.mock('../sano/ui/LivingGradient', () => ({ LivingGradient: () => null, RippleLayer: () => null }));
vi.mock('../sano/screens/Conversation', () => ({ Conversation: () => <h1>Conversation opened</h1> }));
vi.mock('../sano/ai', async (importOriginal) => {
  const original = await importOriginal<typeof import('../sano/ai')>();
  return { ...original, streamChat: vi.fn(async () => 'A sample conversation.') };
});

beforeEach(() => {
  localStorage.clear();
  localStorage.setItem('sano.web.v1', JSON.stringify({ hasOnboarded: true, musicOn: false, soundOn: false, epsilon: false }));
});
afterEach(() => { cleanup(); vi.useRealTimers(); });
const tick = (count = 1) => { for (let i = 0; i < count; i++) act(() => { vi.advanceTimersByTime(2500); }); };
const mount = () => render(<SanoProvider><SanoApp /></SanoProvider>);

describe('companion-first paths', () => {
  it('keeps the centered Rumi AI shortcut and log button outside the home scroll', async () => {
    mount();
    const navigation = screen.getByRole('navigation', { name: 'Floating navigation' });
    const ai = within(navigation).getByRole('button', { name: 'Talk with Rumi AI' });
    const log = screen.getByRole('button', { name: 'Log something' });
    expect(log.closest('[data-scroll]')).toBeNull();
    expect(navigation.closest('[data-scroll]')).toBeNull();
    expect(navigation.querySelector('.dock-frost')).toBeInTheDocument();
    expect(ai.parentElement?.children[2]).toBe(ai);
    fireEvent.scroll(document.querySelector('[data-scroll]')!, { target: { scrollTop: 5000 } });
    await act(async () => { fireEvent.click(ai); });
    expect(screen.getByRole('heading', { name: 'Conversation opened' })).toBeInTheDocument();
  });
  it('pops up approval and keeps it paused after review later, including changed fares', () => {
    vi.useFakeTimers();
    mount();
    fireEvent.click(screen.getByRole('button', { name: /Rumi’s work/ }));
    fireEvent.click(screen.getByRole('button', { name: 'Arrange a ride' }));
    fireEvent.click(screen.getByRole('button', { name: 'Sign in as Marcus' }));
    tick(3);
    const popup = screen.getByRole('heading', { name: 'Before I continue' }).closest('[role="dialog"]')!;
    expect(popup).toBeInTheDocument();
    expect(within(popup as HTMLElement).getByRole('button', { name: 'Approve' })).toBeInTheDocument();
    expect(screen.getByRole('region', { name: 'Action approval' }).closest('[aria-label="Browser conversation"]')).toBeNull();
    fireEvent.click(screen.getByRole('button', { name: 'Review later · keep paused' }));
    tick(4);
    expect(screen.queryByRole('button', { name: 'Approve' })).not.toBeInTheDocument();
    expect(screen.queryByText(/Task summary · Arrange a ride/)).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: /Your approval is needed/ }));
    fireEvent.click(screen.getByRole('button', { name: 'Preview a changed fare' }));
    expect(screen.queryByRole('button', { name: 'Approve' })).not.toBeInTheDocument();
    tick(3);
    expect(screen.getByRole('region', { name: 'Action approval' })).toHaveTextContent('$29');
    fireEvent.click(screen.getByRole('button', { name: 'Decline' }));
    expect(screen.queryByRole('button', { name: 'Approve' })).not.toBeInTheDocument();
  });
  it('brands AI settings as Rumi AI while retaining external processing disclosure', () => {
    mount();
    fireEvent.click(screen.getByRole('button', { name: 'Settings' }));
    expect(screen.getByText('Rumi AI · your choice')).toBeInTheDocument();
    expect(screen.getByText(/an external AI service/)).toBeInTheDocument();
    expect(screen.queryByText(/Anthropic|Sonnet|Claude/i)).not.toBeInTheDocument();
  });
  it('opens conversation from the labeled primary action', async () => {
    mount();
    await act(async () => { fireEvent.click(screen.getByRole('button', { name: 'Talk or type to Rumi' })); });
    expect(screen.getByRole('heading', { name: 'Conversation opened' })).toBeInTheDocument();
  });
  it('reaches the guide from Today, edits a question and opens doctor summaries', () => {
    mount();
    fireEvent.click(screen.getByRole('button', { name: /Prepare for my visit/ }));
    expect(screen.getByRole('heading', { name: 'Discussion guide' })).toBeInTheDocument();
    fireEvent.change(screen.getByRole('textbox', { name: 'Question or observation' }), { target: { value: 'Could we discuss my evening walks?' } });
    fireEvent.click(screen.getByRole('button', { name: 'Add to discussion guide' }));
    expect(screen.getByText('Could we discuss my evening walks?')).toBeInTheDocument();
    fireEvent.click(screen.getAllByRole('button', { name: 'Ask first' })[0]);
    fireEvent.click(screen.getByRole('button', { name: 'Review a doctor-specific summary' }));
    expect(screen.getByRole('heading', { name: 'Visit reports' })).toBeInTheDocument();
  });
  it('leads You with insights and opens journeys without using a hidden menu', () => {
    mount();
    fireEvent.click(screen.getByRole('button', { name: 'You' }));
    expect(screen.getByRole('button', { name: 'Your journeys' })).toBeInTheDocument();
    expect(screen.queryByRole('heading', { name: 'Your story' })).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'Your journeys' }));
    expect(screen.getByText('Your library')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Done' })).toBeInTheDocument();
  });
  it('uses a fixed patient login and shows persona results without accepting credentials', () => {
    mount();
    fireEvent.click(screen.getByRole('button', { name: /Rumi’s work/ }));
    fireEvent.click(screen.getByRole('button', { name: 'Check my latest labs' }));
    expect(screen.getByText('Marcus’s sample workspace')).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: 'Sign in to MyChart' })).toBeInTheDocument();
    expect(screen.getByText('marcus.sample')).toBeInTheDocument();
    expect(within(screen.getByRole('region', { name: 'Browser preview' })).queryByRole('textbox')).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'Sign in as Marcus' }));
    const preview = screen.getByRole('region', { name: 'Browser preview' });
    expect(within(preview).getByRole('heading', { name: 'Test results' })).toBeInTheDocument();
    expect(within(preview).getAllByText(/A1c/).length).toBeGreaterThan(0);
    expect(screen.queryByText('Rumi’s work · offline demo')).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /demo/i })).not.toBeInTheDocument();
  });
  it('recognizes 36 Instagram posts and autonomously opens the recipe while chat remains optional', () => {
    vi.useFakeTimers();
    mount();
    fireEvent.click(screen.getByRole('button', { name: /Rumi’s work/ }));
    fireEvent.click(screen.getByRole('button', { name: 'Find a saved recipe' }));
    const preview = screen.getByRole('region', { name: 'Browser preview' });
    expect(within(preview).getByText('Instagram')).toBeInTheDocument();
    expect(within(preview).queryByRole('textbox')).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'Sign in as Marcus' }));
    expect(preview).toHaveClass('browser-working-frame');
    expect(preview.querySelector('[data-step="0"]')).toHaveClass('browser-action-target');
    expect(within(preview).getAllByRole('button', { name: /Open recipe/ })).toHaveLength(36);
    expect(screen.queryByRole('button', { name: 'Continue' })).not.toBeInTheDocument();
    tick();
    expect(preview.querySelector('[data-step="1"]')).toHaveClass('browser-action-target');
    fireEvent.change(screen.getByRole('textbox', { name: 'Ask about this page' }), { target: { value: 'Explain this' } });
    fireEvent.click(screen.getByRole('button', { name: 'Send follow-up' }));
    expect(screen.getByText(/From this sample task: Chickpea/)).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'Pause' }));
    expect(preview).not.toHaveClass('browser-working-frame');
    expect(preview.querySelector('.browser-action-target')).toBeNull();
  });
  it('autonomously prepares the ride and only pauses for approval', () => {
    vi.useFakeTimers();
    mount();
    fireEvent.click(screen.getByRole('button', { name: /Rumi’s work/ }));
    fireEvent.click(screen.getByRole('button', { name: 'Arrange a ride' }));
    expect(within(screen.getByRole('region', { name: 'Browser preview' })).getByText('Uber')).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'Sign in as Marcus' }));
    tick(3);
    fireEvent.click(screen.getByRole('button', { name: 'Approve' }));
    expect(screen.getByText(/Task summary · Arrange a ride/)).toHaveTextContent('no external action taken');
    expect(screen.getByText('Marcus’s sample workspace')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Approve' })).not.toBeInTheDocument();
  });
  it('keeps running minimized and keeps approval visible with the browser collapsed', () => {
    vi.useFakeTimers();
    mount();
    fireEvent.click(screen.getByRole('button', { name: /Rumi’s work/ }));
    fireEvent.click(screen.getByRole('button', { name: 'Arrange a ride' }));
    expect(within(screen.getByRole('region', { name: 'Browser preview' })).queryByRole('textbox')).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'Sign in as Marcus' }));
    tick();
    fireEvent.click(screen.getByRole('button', { name: 'Pause' }));
    expect(screen.queryByRole('button', { name: 'Continue' })).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'Resume' }));
    fireEvent.click(screen.getByRole('button', { name: 'Collapse browser preview' }));
    fireEvent.click(screen.getByRole('button', { name: 'Minimize' }));
    tick(3);
    fireEvent.click(screen.getByRole('button', { name: /Rumi’s work/ }));
    expect(screen.getByRole('region', { name: 'Action approval' })).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'Decline' }));
    expect(within(screen.getByRole('dialog')).getByRole('status')).toHaveTextContent('stopped');
    expect(screen.queryByText(/Task summary ·/)).not.toBeInTheDocument();
  });
});
