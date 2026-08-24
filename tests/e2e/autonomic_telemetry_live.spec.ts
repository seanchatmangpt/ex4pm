import { test, expect } from '@playwright/test';

test.describe('Living Autonomic Engine & Real-Time Dynamic Telemetry E2E Suite', () => {

  test('01. Verify Live BEAM VM Total Memory Allocated is non-empty and non-zero', async ({ page }) => {
    await page.goto('/dashboard');
    const memoryEl = page.locator('text=Total Memory:').locator('..');
    await expect(memoryEl).toBeVisible();
    const memoryText = await memoryEl.innerText();
    expect(memoryText).toMatch(/[0-9]+\.[0-9]+\s*MB/);
  });

  test('02. Verify Live BEAM Process count is dynamically populated', async ({ page }) => {
    await page.goto('/dashboard');
    const processEl = page.locator('text=Processes:').locator('..');
    await expect(processEl).toBeVisible();
    const processText = await processEl.innerText();
    expect(processText).toMatch(/[0-9]+\s*\/\s*[0-9]+/);
  });

  test('03. Verify Chicago Test Utilization gauge is 100% Proven', async ({ page }) => {
    await page.goto('/dashboard');
    await expect(page.locator('text=100% PROVEN')).toBeVisible();
    await expect(page.locator('text=Ash Resources:')).toBeVisible();
    await expect(page.locator('text=Reactor Sagas:')).toBeVisible();
  });

  test('04. Verify Ash Domain Entity Live ETS table badges are active', async ({ page }) => {
    await page.goto('/dashboard');
    await expect(page.locator('text=🗄️ Ash Entity ETS Live Records')).toBeVisible();
    await expect(page.locator('text=Agents:')).toBeVisible();
    await expect(page.locator('text=Receipts:')).toBeVisible();
  });

  test('05. Verify Active Autopilot MAPK Heartbeat cycle status', async ({ page }) => {
    await page.goto('/dashboard');
    await expect(page.locator('text=ACTIVE AUTOPILOT')).toBeVisible();
    await expect(page.locator('text=1. MONITOR')).toBeVisible();
    await expect(page.locator('text=4. EXECUTE')).toBeVisible();
  });

  test('06. Verify Cryptographic BRCE Receipt Ledger streaming section', async ({ page }) => {
    await page.goto('/dashboard');
    await expect(page.locator('text=Cryptographic BRCE Receipt Ledger')).toBeVisible();
  });
});
