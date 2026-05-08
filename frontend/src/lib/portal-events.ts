import type { TaskRecord } from './api';

type PortalRefreshReason = 'test-run-finished';

export type PortalRefreshDetail = {
  reason: PortalRefreshReason;
  runId: string;
  status: string;
};

export type PortalTaskDetail = {
  run: TaskRecord;
};

const PORTAL_REFRESH_EVENT = 'dsaa4040:portal-refresh';
const PORTAL_TASK_EVENT = 'dsaa4040:portal-task';
const ACTIVE_TEST_RUN_KEY = 'dsaa4040-active-test-run';

export function emitPortalRefresh(detail: PortalRefreshDetail): void {
  window.dispatchEvent(new CustomEvent<PortalRefreshDetail>(PORTAL_REFRESH_EVENT, { detail }));
}

export function subscribePortalRefresh(listener: (detail: PortalRefreshDetail) => void): () => void {
  const handler = (event: Event) => {
    listener((event as CustomEvent<PortalRefreshDetail>).detail);
  };
  window.addEventListener(PORTAL_REFRESH_EVENT, handler);
  return () => window.removeEventListener(PORTAL_REFRESH_EVENT, handler);
}

export function emitPortalTaskUpdate(run: TaskRecord): void {
  window.dispatchEvent(new CustomEvent<PortalTaskDetail>(PORTAL_TASK_EVENT, { detail: { run } }));
}

export function subscribePortalTaskUpdate(listener: (detail: PortalTaskDetail) => void): () => void {
  const handler = (event: Event) => {
    listener((event as CustomEvent<PortalTaskDetail>).detail);
  };
  window.addEventListener(PORTAL_TASK_EVENT, handler);
  return () => window.removeEventListener(PORTAL_TASK_EVENT, handler);
}

export function setActiveTestRunId(runId: string | null): void {
  if (runId) {
    window.sessionStorage.setItem(ACTIVE_TEST_RUN_KEY, runId);
    return;
  }
  window.sessionStorage.removeItem(ACTIVE_TEST_RUN_KEY);
}

export function getActiveTestRunId(): string | null {
  return window.sessionStorage.getItem(ACTIVE_TEST_RUN_KEY);
}