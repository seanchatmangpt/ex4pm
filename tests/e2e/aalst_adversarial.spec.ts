import { test, expect } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';

test.describe('Adversarial Dr. Wil van der Aalst Process Intelligence E2E Suite', () => {

  test('Attack 1: Live Dashboard Autonomic MAPK Autopilot Verification', async ({ page }) => {
    // Navigate directly to the live kind cluster dashboard
    await page.goto('/dashboard');

    // 1. Assert core title and control plane presence
    await expect(page.locator('h1')).toContainText('ex4pm Process Intelligence Control Plane');

    // 2. Assert Autonomic Closed-Loop Engine is ACTIVE AUTOPILOT
    await expect(page.getByText('ACTIVE AUTOPILOT')).toBeVisible();
    await expect(page.getByText('1. MONITOR')).toBeVisible();
    await expect(page.getByText('4. EXECUTE')).toBeVisible();

    // 3. Assert 5D Conformance Meters are rendered
    await expect(page.getByText('Fitness')).toBeVisible();
    await expect(page.getByText('100.0%').first()).toBeVisible();
    await expect(page.getByText('Precision')).toBeVisible();
    await expect(page.getByText('Policy')).toBeVisible();
    await expect(page.getByText('Lifecycle')).toBeVisible();

    // 4. Assert Living Mermaid DAG and Cluster Mesh are rendered
    await expect(page.getByText('Living Reactor Execution Graph')).toBeVisible();
    await expect(page.getByText('Distributed Erlang Cluster Mesh')).toBeVisible();

    // 5. Assert Cryptographic BRCE Receipt Ledger contains verified receipts
    await expect(page.getByText('Cryptographic BRCE Receipt Ledger')).toBeVisible();
    await expect(page.getByText('✓ match').first()).toBeVisible();
  });

  test('Attack 2: Direct API Ingestion & Conformance Gatekeeping', async ({ request }) => {
    // Ingest invalid OCEL 2.0 event payload to verify typed REFUSAL
    const invalidPayload = {
      producer: { agent_id: "dr_aalst_adversarial_test" },
      events: []
    };

    const response = await request.post('/api/v1/ocel/events', {
      data: invalidPayload
    });

    expect(response.status()).toBe(422);
    const body = await response.json();
    expect(body.status).toBe('refused');
    expect(body.standing).toBe('refused');
  });

  test('Attack 3: Cluster Health Probe and Readyz Invariants', async ({ request }) => {
    const healthResponse = await request.get('/healthz');
    expect(healthResponse.status()).toBe(200);
    const healthBody = await healthResponse.json();
    expect(healthBody.standing).toBe('alive');
    expect(healthBody.service).toBe('ex4pm-process-intelligence-control-plane');

    const readyResponse = await request.get('/readyz');
    expect(readyResponse.status()).toBe(200);
  });

  test('Attack 4: AshAdmin UI & Multi-Domain Introspection Verification', async ({ page }) => {
    await page.goto('/admin');
    await expect(page).toHaveTitle(/Ash Admin/);
    await expect(page.locator('body')).toBeVisible();
  });
});
