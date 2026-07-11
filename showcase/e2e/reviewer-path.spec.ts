import { expect, test, type Page } from "@playwright/test";

function capturePageErrors(page: Page): string[] {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("console", (message) => {
    if (message.type() === "error") errors.push(message.text());
  });
  return errors;
}

async function expectNoHorizontalOverflow(page: Page) {
  const dimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth + 1);
}

test("homepage loads the evaluator entry without page errors", async ({ page }) => {
  const errors = capturePageErrors(page);
  await page.goto("/");

  await expect(page.getByRole("heading", { level: 1, name: "MoonEvidence" })).toBeVisible();
  await expect(page.getByText("为文件生成可验证的证据包，在内容发生变化时准确发现并定位。")).toBeVisible();
  await expect(page.getByText("353 项可执行测试")).toBeAttached();
  await expectNoHorizontalOverflow(page);
  expect(errors).toEqual([]);
});

test("primary call to action verifies the built-in valid pack", async ({ page }) => {
  const errors = capturePageErrors(page);
  await page.goto("/");
  await page.getByRole("button", { name: "开始验证" }).first().click();

  await expect(page).toHaveURL(/#workbench\/verify$/);
  await page.getByRole("button", { name: "开始验证" }).click();
  await expect(page.getByRole("heading", { name: "验证通过" })).toBeVisible();
  await expect(page.getByText("2 个文件均与证据清单记录一致")).toBeVisible();
  expect(errors).toEqual([]);
});

test("tampered built-in pack is rejected and localized", async ({ page }) => {
  const errors = capturePageErrors(page);
  await page.goto("/#workbench/verify");

  await page.getByRole("button", { name: "篡改样例" }).click();
  await page.getByRole("button", { name: "开始验证" }).click();
  await expect(page.getByRole("heading", { name: "发现内容不一致" })).toBeVisible();
  await expect(page.getByRole("cell", { name: "files/a.txt" })).toBeVisible();
  await expect(page.getByText("文件缺失或内容与证据清单不一致")).toBeVisible();
  expect(errors).toEqual([]);
});

test("mobile homepage and workbench remain within the viewport", async ({ page }) => {
  const errors = capturePageErrors(page);
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");

  await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
  await expectNoHorizontalOverflow(page);
  await page.getByRole("button", { name: "开始验证" }).first().click();
  await expect(page.getByRole("heading", { name: "验证证据包" })).toBeVisible();
  await expectNoHorizontalOverflow(page);
  expect(errors).toEqual([]);
});

test("recorded Fabric run exposes its transaction evidence", async ({ page }) => {
  const errors = capturePageErrors(page);
  await page.goto("/");
  await page.getByRole("button", { name: "实链记录" }).click();

  await expect(page).toHaveURL(/#ledger$/);
  await expect(page.getByRole("heading", { level: 1 })).toContainText("穿过两个组织");
  await expect(page.getByText("VALID", { exact: true }).first()).toBeVisible();
  await expect(page.getByText("starlittle-MoonEvidence-0.5.1.zip")).toBeVisible();
  await expect(page.getByText("a6d812ac78e8b933d78f85f743fa8e067dc388f0083afb22b775a6884f4529dc")).toBeVisible();
  await expectNoHorizontalOverflow(page);
  expect(errors).toEqual([]);
});
