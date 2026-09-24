import unittest
import time
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options

class EportalDynamicCrawlerTests(unittest.TestCase):
    def setUp(self):
        # Mở trình duyệt để quan sát trực quan
        chrome_options = Options()
        chrome_options.add_argument("--log-level=3")
        self.driver = webdriver.Chrome(options=chrome_options)
        
        # Đặt địa chỉ gốc (Base URL)
        self.base_url = "https://iot.pro.vn"
        self.driver.implicitly_wait(5)
        self.driver.maximize_window()

    def test_dynamic_crawling_and_health_check(self):
        print("\n" + "="*70)
        print(" BẮT ĐẦU CRAWL TỰ ĐỘNG (TỰ TÌM VÀ QUÉT TẤT CẢ CÁC TRANG) ")
        print("="*70)

        # 1. TRUY CẬP TRANG CHỦ ĐỂ THU THẬP TẤT CẢ CÁC ĐƯỜNG LINK (PAGES)
        print(f"[INFO] Đang truy cập trang chủ {self.base_url} để thu thập danh sách trang...")
        self.driver.get(self.base_url)
        time.sleep(3) # Chờ trang load xong hoàn toàn
        
        links = self.driver.find_elements(By.TAG_NAME, "a")
        urls_to_test = set() # Dùng set để loại bỏ các link trùng lặp
        
        for link in links:
            try:
                href = link.get_attribute("href")
                # Chỉ lấy các link hợp lệ và là link nội bộ (cùng IP) để tránh test nhầm ra web ngoài (như facebook)
                if href and href.startswith(self.base_url) and not href.endswith(".jpg") and not href.endswith(".png"):
                    # Bỏ qua các link trỏ về đúng trang hiện tại có dấu #
                    if "#" not in href.split("/")[-1]:
                        urls_to_test.add(href)
            except:
                pass # Bỏ qua nếu có lỗi khi lấy thuộc tính link
        
        # Không giới hạn số lượng, QUÉT TOÀN BỘ tất cả các trang thu thập được
        pages_to_test = list(urls_to_test)
        print(f"\n[OK] Đã tự động thu thập được {len(urls_to_test)} trang trên hệ thống.")
        print(f"[INFO] Bot sẽ tiến hành truy vết và test TOÀN BỘ {len(pages_to_test)} trang để kiểm tra lỗi.\n")

        # 2. VÒNG LẶP: ĐI VÀO TỪNG TRANG ĐÃ TÌM ĐƯỢC VÀ KIỂM TRA LỖI
        for idx, url in enumerate(pages_to_test, 1):
            with self.subTest(url=url):
                print(f"\n[{idx}/{len(pages_to_test)}] Đang kiểm tra giao diện trang: {url}")
                self.driver.get(url)
                
                # Cuộn từ từ để kích hoạt hiển thị
                self.driver.execute_script("window.scrollTo(0, document.body.scrollHeight / 2);")
                time.sleep(1)
                self.driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
                time.sleep(1)

                # -- KIỂM TRA LỖI CONSOLE --
                browser_logs = self.driver.get_log('browser')
                errors = [log for log in browser_logs if log['level'] == 'SEVERE']
                if errors:
                    print(f"  [❌] LỖI HỆ THỐNG: Tìm thấy {len(errors)} lỗi Console. Dưới đây là chi tiết:")
                    # Chỉ in tối đa 5 lỗi đầu tiên để tránh bị trôi log
                    for err in errors[:5]:
                        print(f"       -> Lỗi: {err['message']}")
                else:
                    print("  [✅] Trạng thái Console: Không có lỗi JavaScript/Server.")

                # -- KIỂM TRA ẢNH BỊ LỖI (404/BROKEN) --
                images = self.driver.find_elements(By.TAG_NAME, "img")
                broken_images = 0
                for img in images:
                    is_loaded = self.driver.execute_script(
                        "return arguments[0].complete && typeof arguments[0].naturalWidth != 'undefined' && arguments[0].naturalWidth > 0", 
                        img
                    )
                    if not is_loaded:
                        broken_images += 1
                if broken_images > 0:
                    print(f"  [❌] LỖI UI: {broken_images}/{len(images)} hình ảnh bị hỏng (Mất link/404).")
                else:
                    print(f"  [✅] Trạng thái Hình ảnh: {len(images)} ảnh load thành công.")

                # -- KIỂM TRA CẤU TRÚC DOM --
                headings = self.driver.find_elements(By.XPATH, "//h1 | //h2 | //h3")
                links_on_page = self.driver.find_elements(By.TAG_NAME, "a")
                print(f"  [✅] Trạng thái DOM: {len(headings)} Tiêu đề (H1-H3) và {len(links_on_page)} Liên kết được load.")
                
                # Dừng lại 1 giây cho người dùng quan sát giao diện
                time.sleep(1)

    def tearDown(self):
        print("\n" + "="*70)
        print("Hoàn tất quá trình Quét & Kiểm thử. Đóng trình duyệt sau 3 giây...")
        time.sleep(3)
        self.driver.quit()

if __name__ == "__main__":
    unittest.main(verbosity=2)
