# Hướng Dẫn Sử Dụng: XAUUSD Aggressive Scalper (M1)

Chào mừng bạn! Đây là EA scalping tốc độ cao cho XAUUSD/GOLD trên MetaTrader 5, dựa vào giao cắt Stochastic (5,3,3) và kiểm soát chặt chẽ spread cùng số lệnh.

## 1) Yêu cầu hệ thống & tài khoản
- Nền tảng: MetaTrader 5 (bản desktop).
- Sản phẩm: XAUUSD hoặc GOLD.
- Khung thời gian: **BẮT BUỘC M1**. Dùng khung khác sẽ khiến chiến lược hoạt động sai.
- Loại tài khoản: Khuyến nghị Standard hoặc Ultra Low.
- Vốn gợi ý: $10,000 cho `FixedLot` mặc định 0.5. Nếu vốn nhỏ hơn, hãy giảm `FixedLot` (ví dụ $1,000 → 0.05 lot).
- Giới hạn spread: EA sẽ tạm dừng vào lệnh khi spread vượt `MaxSpreadPoints` (mặc định 100 points).

## 2) Cài đặt EA
1. Tải `AggressiveScalper.mq5` (hoặc file `.ex5` đã biên dịch).
2. Trong MT5, vào `File -> Open Data Folder`.
3. Mở thư mục `MQL5 -> Experts`.
4. Sao chép file EA vào thư mục `Experts`.
5. Quay lại MT5, nhấp phải `Navigator -> Experts` và chọn `Refresh` (hoặc biên dịch bằng MetaEditor).

## 3) Khởi chạy và bật giao dịch
1. Mở biểu đồ XAUUSD/GOLD.
2. Chuyển biểu đồ sang khung **M1**.
3. Kéo EA từ `Navigator -> Experts` thả vào biểu đồ.
4. Trong hộp thoại hiện ra:
   - Tab **Common**: tick `Allow Algo Trading`.
   - Tab **Inputs**: chỉnh các tham số nếu cần (xem mục 4).
5. Đảm bảo nút `Algo Trading` trên thanh công cụ đang màu xanh (được bật).
6. Kiểm tra biểu tượng mũ cử nhân ở góc phải và bảng thông tin ở góc trái biểu đồ.

## 4) Tham số cài đặt (mặc định)
| Tham số            | Mặc định | Giải thích |
|--------------------|----------|------------|
| `FixedLot`         | 0.5      | Khối lượng cố định cho mỗi lệnh. Giảm xuống nếu vốn nhỏ. |
| `StopLossPoints`   | 300      | Khoảng cách cắt lỗ (points) — 300 pts ≈ 30 pips ≈ 3 giá vàng. |
| `TakeProfitPoints` | 150      | Khoảng cách chốt lời (points) — 150 pts ≈ 15 pips ≈ 1.5 giá vàng. |
| `MaxPositions`     | 3        | Số lệnh tối đa đang mở (tính toàn bộ terminal). |
| `TrailingStart`    | 50       | Mức lợi nhuận (points) để dời SL về hòa vốn. |
| `TrailingStep`     | 20       | Phần lợi nhuận thêm (points) để trượt SL tiếp sau khi hòa vốn. |
| `MaxSpreadPoints`  | 100      | Giới hạn spread cho phép (points). Spread cao hơn sẽ tạm dừng vào lệnh. |
| `MagicNumber`      | 123456   | Mã định danh Magic để nhận diện lệnh của EA. |

Mẹo: Bấm `F7` trên biểu đồ để mở lại và chỉnh các tham số này bất kỳ lúc nào.

## 5) Cách đọc bảng Dashboard trên biểu đồ
- `Current Spread`: cập nhật từng tick. Nếu nhỏ hơn `MaxSpreadPoints` thì EA được phép vào lệnh.
- `STATUS: [READY TO TRADE]`: đủ điều kiện; `[PAUSED]`: spread quá cao nên tạm nghỉ.
- `Stoch Main / Stoch Signal`: giá trị Stochastic hiện tại.
- `ZONE`: `OVERSOLD (Waiting for BUY)`, `OVERBOUGHT (Waiting for SELL)`, hoặc `Neutral`.

## 6) Xử lý sự cố
- Không thấy EA vào lệnh:
  - Spread cao: so sánh spread trên dashboard với `MaxSpreadPoints`. Có thể nâng giới hạn cẩn trọng (ví dụ 120) nếu sàn spread rộng.
  - Sai khung: chắc chắn biểu đồ đang ở **M1**.
  - Chưa bật Algo: nút `Algo Trading` phải xanh; trong hộp thoại EA phải cho phép Algo.
  - Vướng trần lệnh: `MaxPositions` sẽ chặn lệnh mới khi đạt giới hạn.
  - Chưa có tín hiệu: chiến lược chờ giao cắt Stochastic ở vùng cực trị.
- Lỗi “Invalid Volume”:
  - Giảm `FixedLot` để phù hợp min/step của sàn. Tài khoản Standard thường cho 0.01 lot; tài khoản micro/cent có thể khác.

## 7) Cảnh báo rủi ro
- Nên chạy demo ít nhất 2 tuần trước khi dùng tiền thật; scalping M1 rất nhạy với spread và tốc độ khớp lệnh.
- Quản lý vốn: gợi ý không vượt 0.01 lot cho mỗi $1,000, tăng dần sau khi đã kiểm chứng.
- Luôn kiểm tra quy định sàn (khối lượng tối thiểu/bước nhảy, khoảng cách SL/TP, mức spread điển hình) và chỉnh tham số cho phù hợp.
