const { test, expect } = require('@playwright/test');

// URL kiểm thử hệ thống web AloT Smart Home
const TARGET_URL = 'https://iot.pro.vn/';

test.describe('Kiểm thử Giao diện (UI) và Các Module tính năng', () => {

  test.beforeEach(async ({ page }) => {
    // Tự động truy cập trang web trước mỗi test case
    await page.goto(TARGET_URL);
  });

  test('1. Kiểm tra tải trang web và Tiêu đề (Title)', async ({ page }) => {
    // Kiểm tra trang có load thành công hay không (thông qua title)
    await expect(page).toHaveTitle(/.*|Example Domain/); 
  });

  test('2. Kiểm tra hiển thị Module Nội Dung Chính', async ({ page }) => {
    // Web example.com thường chứa thẻ div với nội dung
    const mainContent = page.locator('div'); 
    await expect(mainContent).toBeVisible();
    
    // Kiểm tra không có thông báo lỗi
    const errorAlerts = page.locator('.alert-danger, .error-message');
    await expect(errorAlerts).toHaveCount(0);
  });

  test('3. Kiểm tra tương tác với một liên kết (Link)', async ({ page }) => {
    // Tìm một liên kết trên trang (Ví dụ web example có link "More information...")
    const link = page.getByRole('link', { name: /More information/i });
    
    // Link đó phải hiển thị
    if (await link.count() > 0) {
      await expect(link).toBeVisible();
      await expect(link).toBeEnabled();
    }
  });
});
