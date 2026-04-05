# Project Cuối Kỳ — Food Ordering & Delivery App (Flutter)

Ứng dụng đặt món và giao hàng với 3 vai trò: **Khách hàng**, **Cửa hàng**, **Tài xế**.

Stack chính:

- Firebase (**Auth** + **Cloud Firestore**) cho xác thực và dữ liệu
- Supabase **Storage** để lưu ảnh (món ăn, minh chứng giao hàng)
- Bản đồ **OpenStreetMap** qua `flutter_map` (không cần Google Maps API key)

## Demo nhanh (Quick start)

Yêu cầu: đã cấu hình Firebase (mục bên dưới) và có Supabase keys.

### macOS/Linux (Bash)

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY \
  --dart-define=SUPABASE_STORAGE_BUCKET=food-images
```

### Windows (PowerShell)

```powershell
flutter pub get
flutter run `
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL `
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY `
  --dart-define=SUPABASE_STORAGE_BUCKET=food-images
```

## Tính năng

### Khách hàng

- Đăng ký/đăng nhập.
- Xem danh sách cửa hàng, món ăn, danh mục; tìm kiếm & lọc.
- Gợi ý theo **khoảng cách** và **thời tiết**.
- Giỏ hàng, đặt hàng **ngay** hoặc **đặt trước** (scheduled/pre-order).
- Thanh toán: **COD** hoặc **Ví nội bộ**.
- Theo dõi trạng thái đơn theo thời gian thực; đánh giá đơn hàng.

### Cửa hàng

- Quản lý menu: tạo/sửa/xóa món, bật/tắt tình trạng bán.
- Thêm món: chỉ chọn **size** khi món là **đồ uống**.
- Quản lý đơn: có nút **Nhận đơn** cho đơn `pending` → chuyển sang `finding_driver` (hệ thống tìm tài xế).
- Tab quản lý: thống kê, đơn hàng, đánh giá, hồ sơ.

### Tài xế

- Bật/tắt trạng thái online nhận đơn.
- Xem đơn gần khu vực hoạt động, nhận đơn khi đơn đang ở trạng thái `finding_driver`.
- Xem đơn đang giao, xác nhận hoàn thành giao hàng.
- Upload **ảnh minh chứng** giao hàng; tự động cộng tiền vào ví và lưu lịch sử giao dịch.

## Công nghệ

- Flutter (Dart SDK theo `pubspec.yaml`)
- State management: Provider
- Firebase: `firebase_core`, `firebase_auth`, `cloud_firestore`
- Bản đồ & vị trí: `flutter_map` (OpenStreetMap), `geolocator`, `geocoding`, `latlong2`
- Upload ảnh: `image_picker`
- Storage ảnh: `supabase_flutter`
- Lịch hẹn (đặt trước): `add_2_calendar`

## Cấu trúc thư mục (rút gọn)

```text
lib/
  data/           Datasource + repositories (Firestore)
  domain/         Entities + repository interfaces
  controller/     Controller cho luồng tài xế/đơn
  screens/        UI theo vai trò + luồng đặt hàng
  services/       Tầng dịch vụ (Auth/Order/Menu/...)
  models/         Model dữ liệu (Order/Food/User/...)
  providers/      Provider state (cart, checkout, tracking, ...)
  widgets/        Widget dùng lại
  theme/          Theme/tokens
```

## Yêu cầu

- Flutter SDK (khuyến nghị Flutter stable mới, tương thích Dart `^3.11.1`)
- Android Studio/SDK hoặc thiết bị thật
- Tài khoản Firebase + dự án Supabase (Storage)

## Cấu hình Firebase

1. Cài FlutterFire CLI (nếu cần):

```bash
dart pub global activate flutterfire_cli
```

2. Kết nối Firebase cho dự án:

```bash
flutterfire configure
```

3. Kiểm tra các file đã có trong repo:

- `android/app/google-services.json`
- `lib/firebase_options.dart`

Ghi chú:

- iOS có thể cần bổ sung `GoogleService-Info.plist` (nếu build iOS).
- Firestore rules tham khảo trong `firestore.rules` (cần chỉnh theo schema/role khi triển khai).

## Cấu hình Supabase Storage (bắt buộc)

App yêu cầu biến môi trường Supabase khi khởi động (được đọc từ `--dart-define`).

Ghi chú: Nếu thiếu `SUPABASE_URL`/`SUPABASE_ANON_KEY` thì app sẽ dừng ở màn hình lỗi để tránh chạy sai cấu hình.

### 1) Tạo bucket

- Tạo bucket Storage (mặc định khuyến nghị): `food-images`.

### 2) Policy (tham khảo cho môi trường dev)

App upload từ client bằng `SUPABASE_ANON_KEY`, vì vậy cần policy phù hợp.

Public read:

```sql
create policy "public read food images"
on storage.objects
for select
to anon
using (bucket_id = 'food-images');
```

Cho phép upload vào thư mục `foods/` và `proofimages/`:

```sql
create policy "anon upload food images"
on storage.objects
for insert
to anon
with check (
  bucket_id = 'food-images'
  and (storage.foldername(name))[1] in ('foods', 'proofimages')
);
```

Lưu ý bảo mật: policy cho `anon` chỉ nên dùng để demo/dev. Khi triển khai production, nên dùng Supabase Auth hoặc upload qua backend.

### 3) Biến môi trường cần thiết

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- (tùy chọn) `SUPABASE_STORAGE_BUCKET` (mặc định có thể dùng `food-images`)

### (Tuỳ chọn) Cấu hình qua file JSON local cho môi trường dev

Trong code có hỗ trợ đọc file cấu hình từ asset `assets/supabase.dev.json`.
Hiện repo **chưa** có thư mục `assets/` nên cách ổn định nhất là dùng `--dart-define`.

Nếu bạn muốn dùng file JSON local:

1. Tạo file `assets/supabase.dev.json` với nội dung:

```json
{
  "SUPABASE_URL": "https://YOUR_PROJECT.supabase.co",
  "SUPABASE_ANON_KEY": "YOUR_ANON_KEY",
  "SUPABASE_STORAGE_BUCKET": "food-images"
}
```

2. Khai báo assets trong `pubspec.yaml`:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/supabase.dev.json
```

3. Chạy app bình thường (`flutter run`) mà không cần `--dart-define`.

## Bản đồ & vị trí (OpenStreetMap)

Project dùng **OpenStreetMap** thông qua `flutter_map` nên **không cần** Google Maps API key.

### Android permissions

Trong `android/app/src/main/AndroidManifest.xml` đảm bảo có:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

## Chạy ứng dụng

Xem mục “Demo nhanh (Quick start)” ở đầu README.

## Troubleshooting

### 1) Báo lỗi “Supabase chưa được cấu hình”

- Chạy lại với `--dart-define=SUPABASE_URL=...` và `--dart-define=SUPABASE_ANON_KEY=...`.

### 2) Không lấy được vị trí

- Kiểm tra quyền Location trên thiết bị/emulator.
- Bật GPS và đảm bảo có internet.

### 3) `permission-denied` khi đọc/ghi Firestore

- Firestore Rules đang chặn. Cần cập nhật `firestore.rules` theo schema và phân quyền.

## Ghi chú bảo mật

- Không commit key thật lên repo public.
- Giới hạn Firestore rules theo role/owner.
- Không mở quyền upload `anon` cho production.

## Notes

- Ảnh sau khi upload thành công sẽ lưu URL vào Firestore (ví dụ `Foods.image`, `Orders.proofImage`) và hiển thị bằng `Image.network(...)`.
