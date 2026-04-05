# project_cuoi_ky

Ung dung Flutter co dang ky/dang nhap + Firebase Auth + Firestore + Google Maps.

README nay huong dan chi tiet cach cau hinh Google Maps va vi tri hien tai
de map hien thi duoc tren Android.

## 1) Dien Google Maps API key vao project

Mo file:

- `android/app/src/main/res/values/google_maps_api.xml`

Sua gia tri key:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
	 <string name="google_maps_api_key">AIzaSyYOUR_REAL_KEY_HERE</string>
</resources>
```

Luu y:

- Khong them dau ngoac kep quanh key.
- Khong de khoang trang thua o dau/cuoi key.

## 2) Bat API tren Google Cloud

Vao Google Cloud Console:

1. Chon dung project dang dung cho Firebase.
2. Vao `APIs & Services` -> `Library`.
3. Bat cac API sau:
   - `Maps SDK for Android`
     Ung dung Flutter co dang ky/dang nhap + Firebase Auth + Firestore + OpenStreetMap.

README nay huong dan chi tiet cach cau hinh vi tri hien tai

## 3) Cau hinh API key restrictions (quan trong)

## 1) Khong can Google Maps API key

Vao `APIs & Services` -> `Credentials` -> chon API key dang dung.
Project da chuyen sang OpenStreetMap (OSM), nen:

### 3.1 Application restrictions

- Khong can tao API key Google Maps
- Khong can bat Maps SDK for Android
- Khong can cau hinh SHA-1 cho Google Maps key

1. Chon `Android apps`.

## 2) Cac package dang dung cho map + vi tri

Trong `pubspec.yaml`:

- `flutter_map`
- `latlong2`
- `geolocator`
- `geocoding`

## 3) Android permissions can co

File: `android/app/src/main/AndroidManifest.xml`

Can co cac permission:

- `com.example.project_cuoi_ky`
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>

1. Chon `Restrict key`.

## 4) Chay app

- `Maps SDK for Android`

```powershell
flutter clean
flutter pub get
flutter run
```

## 5) Luong lay vi tri hien tai

App se:

1. Xin quyen vi tri tren thiet bi
2. Lay GPS hien tai bang `geolocator`
3. Reverse geocoding thanh dia chi bang `geocoding`
4. Hien marker tren OpenStreetMap bang `flutter_map`
5. Luu dia chi + toa do vao Firestore user profile

## 6) Loi thuong gap va cach xu ly

### Loi: khong xin duoc quyen vi tri

flutter clean
Kiem tra:
flutter run

1. Da cap quyen Location cho app trong Settings chua
2. GPS tren may/emulator da bat chua

### Loi: map khong tai tile OSM

Kiem tra:

- Location permissions (`ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`)

1. Emulator/phone co internet khong
2. Co bi VPN/proxy/firewall chan domain tile OSM khong

### Loi: `permission-denied` khi ghi Firestore

Do Firestore Rules chan ghi/doc. Can cap nhat rules dung voi schema user cua app.

### Loi: `Unable to establish connection on channel`

2. Da bat `Maps SDK for Android` chua.
   Thu:

### Loi: `Unable to establish connection on channel`

1. Kiem tra internet trong emulator
2. Cold boot lai emulator
3. Chay lai `flutter clean ; flutter pub get ; flutter run`
   Thu:

## 7) Ghi chu bao mat

1. Kiem tra emulator co Internet (mo browser trong emulator).

- Khong luu du lieu nhay cam tren client neu khong can thiet
- Firestore rules phai gioi han doc/ghi theo role va owner
  Do Firestore Rules chan ghi/ doc. Can cap nhat rules dung voi schema user cua app.

- Khong commit API key that vao public repo.

## 8) Supabase Storage (luu anh mon an)

Project nay dung:

- Firebase (Auth + Firestore) de luu du lieu (Users/Orders/Foods/Categories...)
- Supabase chi de luu file anh (Storage). Link anh (URL) se duoc luu vao Firestore (field `Foods.image`) va duoc hien thi bang `Image.network(...)`.

### 8.1 Tao bucket

Trong Supabase Dashboard:

1. Tao project Supabase.
2. Vao `Storage` -> `Buckets` -> tao bucket (mac dinh code dang dung: `food-images`).
3. Neu muon dung `getPublicUrl(...)` (nhu code hien tai) thi set bucket la public.

### 8.2 Policy (quan trong)

Vi app dang upload tu client bang `SUPABASE_ANON_KEY`, ban can policy cho `storage.objects`.

Lua chon A (de test nhanh, it an toan hon cho production):

- Cho phep doc public (select) cho anh trong bucket `food-images`.
- Cho phep upload (insert/update) tu client: can policy cho role `anon` hoac phai tich hop Supabase Auth / backend upload.

Goi y policy (tham khao) de test nhanh:

1. Public read:

```sql
create policy "public read food images"
on storage.objects
for select
to anon
using (bucket_id = 'food-images');
```

2. Allow upload into `foods/` folder (de test nhanh):

```sql
create policy "anon upload food images"
on storage.objects
for insert
to anon
with check (
  bucket_id = 'food-images'
  and (storage.foldername(name))[1] = 'foods'
);
```

Luu y: Neu mo quyen upload cho `anon` thi ai co anon key deu co the upload. De an toan cho production, nen:

- Tich hop Supabase Auth (role `authenticated`) va chi cho authenticated upload, hoac
- Upload qua server/Cloud Function (dung service role key, KHONG de tren client).

### 8.3 Chay app voi bien moi truong Supabase

Code doc cac bien qua `--dart-define`:

Luu y: Supabase duoc khoi tao ngay khi mo app. Neu thieu `SUPABASE_URL`/`SUPABASE_ANON_KEY` thi app se bao loi va dung de tranh chay sai cau hinh.

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- (tuy chon) `SUPABASE_STORAGE_BUCKET` (mac dinh: `food-images`)

Lenh mau:

```powershell
flutter run -d emulator-5554 `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY `
  --dart-define=SUPABASE_STORAGE_BUCKET=food-images
```

Neu chay trong VS Code voi launch config `Flutter Debug (Supabase)`, tao file `supabase.dev.json`
tu file mau `supabase.dev.json.example` va dien gia tri that. File `supabase.dev.json`
duoc bo qua trong git de tranh lo key.

Sau khi upload thanh cong, URL anh duoc luu vao Firestore (`Foods.image`) va se tu dong hien thi o man hinh menu.
