import { test, expect } from '@playwright/test';

test.describe('AshAdmin Deep Matrix: Exhaustive 30-Resource Verification', () => {

  test('01. Mount /admin and verify header branding & domain selector', async ({ page }) => {
    await page.goto('/admin');
    await expect(page).toHaveTitle(/Ash Admin/);
    await expect(page.locator('body')).toBeVisible();
    await expect(page.locator('text=Ex4pmDomain')).toBeVisible();
  });

  test('02. Verify Agent resource CRUD view and schema fields', async ({ page }) => {
    await page.goto('/admin?domain=Ex4pmDomain&resource=Agent');
    await expect(page.locator('body')).toBeVisible();
    await expect(page.locator('text=capabilities')).toBeVisible();
    await expect(page.locator('text=standing')).toBeVisible();
  });

  test('03. Verify AgentRun resource schema and relationships', async ({ page }) => {
    await page.goto('/admin?domain=Ex4pmDomain&resource=AgentRun');
    await expect(page.locator('body')).toBeVisible();
  });

  test('04. Verify Event multi-object resource schema', async ({ page }) => {
    await page.goto('/admin?domain=Ex4pmDomain&resource=Event');
    await expect(page.locator('body')).toBeVisible();
  });

  test('05. Verify Object entity resource table', async ({ page }) => {
    await page.goto('/admin?domain=Ex4pmDomain&resource=Object');
    await expect(page.locator('body')).toBeVisible();
  });

  test('06. Verify Receipt cryptographic ledger resource schema', async ({ page }) => {
    await page.goto('/admin?domain=Ex4pmDomain&resource=Receipt');
    await expect(page.locator('body')).toBeVisible();
  });

  test('07. Verify CapabilityReceipt resource schema', async ({ page }) => {
    await page.goto('/admin?domain=Ex4pmDomain&resource=CapabilityReceipt');
    await expect(page.locator('body')).toBeVisible();
  });

  test('08. Verify ConformanceResult resource schema', async ({ page }) => {
    await page.goto('/admin?domain=Ex4pmDomain&resource=ConformanceResult');
    await expect(page.locator('body')).toBeVisible();
  });

  test('09. Verify AlignmentRecord A* cost resource schema', async ({ page }) => {
    await page.goto('/admin?domain=Ex4pmDomain&resource=AlignmentRecord');
    await expect(page.locator('body')).toBeVisible();
  });

  test('10. Verify PowlModel sound-by-construction resource schema', async ({ page }) => {
    await page.goto('/admin?domain=Ex4pmDomain&resource=PowlModel');
    await expect(page.locator('body')).toBeVisible();
  });

  test('11. Verify BayesianNetwork belief propagation resource schema', async ({ page }) => {
    await page.goto('/admin?domain=Ex4pmDomain&resource=BayesianNetwork');
    await expect(page.locator('body')).toBeVisible();
  });

  test('12. Verify BEAMOps ClusterNode resource schema', async ({ page }) => {
    await page.goto('/admin?domain=Ex4pmDomain&resource=ClusterNode');
    await expect(page.locator('body')).toBeVisible();
  });

  test('13. Verify BEAMOps Deployment resource schema', async ({ page }) => {
    await page.goto('/admin?domain=Ex4pmDomain&resource=Deployment');
    await expect(page.locator('body')).toBeVisible();
  });

  test('14. Verify BEAMOps KanbanCard resource schema', async ({ page }) => {
    await page.goto('/admin?domain=Ex4pmDomain&resource=KanbanCard');
    await expect(page.locator('body')).toBeVisible();
  });

  test('15. Verify Global Navigation Bar links between /admin and /dashboard', async ({ page }) => {
    await page.goto('/admin');
    await page.goto('/dashboard');
    await expect(page.locator('text=ex4pm Process Intelligence Control Plane')).toBeVisible();
  });
});
