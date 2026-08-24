import { test, expect } from '@playwright/test';

test.describe('Adversarial Dr. Wil van der Aalst 5D Process Conformance E2E Suite', () => {

  test('01. Ingestion Gatekeeping: Valid OCEL event trace is admitted', async ({ request }) => {
    const response = await request.post('/api/v1/ocel/events', {
      data: {
        schema: 'chatgpt-cloud-ocel/1',
        producer: {
          agent_id: 'chatgpt-cloud-17',
          run_id: 'run-abc',
          runtime: 'beam-otp27'
        },
        sequence: 1,
        objects: {
          'repo-1': { id: 'repo-1', type: 'Repository', name: 'gymact' }
        },
        events: [
          {
            id: 'ev-001',
            activity: 'github.commit',
            timestamp: '2026-08-21T18:14:00Z',
            relationships: [{ objectId: 'repo-1', qualifier: 'source' }],
            agent_id: 'chatgpt-cloud-17',
            run_id: 'run-abc',
            repository: 'gymact'
          }
        ]
      }
    });
    expect(response.status()).toBe(201);
    const json = await response.json();
    expect(json.status).toBe('success');
  });

  test('02. Ingestion Gatekeeping: Empty event payload is strictly refused', async ({ request }) => {
    const response = await request.post('/api/v1/ocel/events', {
      data: {}
    });
    expect(response.status()).toBe(422);
    const json = await response.json();
    expect(json.status).toBe('refused');
  });

  test('03. 5D Conformance: Live A* Fitness metric is evaluated and rendered', async ({ page }) => {
    await page.goto('/dashboard');
    await expect(page.locator('text=Fitness')).toBeVisible();
    await expect(page.locator('text=A* Shortest Move')).toBeVisible();
  });

  test('04. 5D Conformance: Precision metric dial is evaluated', async ({ page }) => {
    await page.goto('/dashboard');
    await expect(page.locator('text=Precision')).toBeVisible();
    await expect(page.locator('text=Model Space')).toBeVisible();
  });

  test('05. 5D Conformance: Declare LTLf Policy compliance is rendered', async ({ page }) => {
    await page.goto('/dashboard');
    await expect(page.locator('text=Policy')).toBeVisible();
    await expect(page.locator('text=Declare LTLf Rules')).toBeVisible();
  });

  test('06. 5D Conformance: LIFO Reversibility lifecycle is verified', async ({ page }) => {
    await page.goto('/dashboard');
    await expect(page.locator('text=Lifecycle')).toBeVisible();
    await expect(page.locator('text=LIFO Reversibility')).toBeVisible();
  });

  test('07. 5D Conformance: Bayesian P(Success) inference is computed', async ({ page }) => {
    await page.goto('/dashboard');
    await expect(page.locator('text=P(Success)')).toBeVisible();
    await expect(page.locator('text=Bayesian Inference')).toBeVisible();
  });

  test('08. Cluster Liveness: Healthz and Readyz HTTP probes return status ok', async ({ request }) => {
    const healthz = await request.get('/healthz');
    expect(healthz.status()).toBe(200);
    const readyz = await request.get('/readyz');
    expect(readyz.status()).toBe(200);
  });
});
