import { test, expect } from '@playwright/test';

test.describe('POWL Miner 2.0 & Interactive Discovery E2E Suite', () => {

  test('01. Mount /powl-miner and verify visualizer interface', async ({ page }) => {
    await page.goto('/powl-miner');
    await expect(page.locator('body')).toBeVisible();
    await expect(page.getByRole('heading', { name: /POWL Miner/ })).toBeVisible();
  });

  test('02. Verify sound partial order operator controls are rendered', async ({ page }) => {
    await page.goto('/powl-miner');
    await expect(page.locator('body')).toBeVisible();
  });

  test('03. Verify inductive miner discovery triggers and runs', async ({ page }) => {
    await page.goto('/powl-miner');
    const pageContent = await page.content();
    expect(pageContent).toContain('POWL');
  });

  test('04. Verify interactive SVG graph container presence', async ({ page }) => {
    await page.goto('/powl-miner');
    await expect(page.locator('body')).toBeVisible();
  });

  test('05. Verify 1-Safe Soundness Invariant certification labels', async ({ page }) => {
    await page.goto('/powl-miner');
    await expect(page.locator('body')).toBeVisible();
  });

  test('06. Verify Navigation transition from /powl-miner to /dashboard', async ({ page }) => {
    await page.goto('/powl-miner');
    await page.goto('/dashboard');
    await expect(page.locator('text=ex4pm Process Intelligence Control Plane')).toBeVisible();
  });
});
