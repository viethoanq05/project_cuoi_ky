# Supabase Configuration Guide

## ❌ Lỗi (Error)
```
Bad state: Supabase chưa được cấu hình. 
Hãy chạy app với --dart-define=SUPABASE_URL=... 
và --dart-define=SUPABASE_ANON_KEY=...
```

**Dịch:** "Supabase is not configured. Run app with --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=..."

---

## ✅ Cách Fix (Solution)

### **Bước 1: Lấy Supabase Credentials**

1. Truy cập: https://supabase.com/dashboard
2. Chọn project của bạn
3. Vào **Settings** → **API**
4. Copy:
   - **Project URL** (ví dụ: `https://your-project-id.supabase.co`)
   - **anon (public) key** (API key dài)

### **Bước 2: Chạy App (Windows - PowerShell)**

**Cách 1: Dùng script (Dễ nhất)**
```powershell
# Chỉnh sửa run_app.ps1 với credentials của bạn
# Sau đó:
.\run_app.ps1
```

**Cách 2: Chạy trực tiếp**
```powershell
$url = "https://your-project-id.supabase.co"
$key = "your-anon-key-here"
$bucket = "product-images"

flutter run `
    --dart-define=SUPABASE_URL=$url `
    --dart-define=SUPABASE_ANON_KEY=$key `
    --dart-define=SUPABASE_STORAGE_BUCKET=$bucket
```

### **Bước 3: Chạy App (macOS/Linux)**

**Cách 1: Dùng script**
```bash
chmod +x run_app.sh
./run_app.sh
```

**Cách 2: Chạy trực tiếp**
```bash
flutter run \
    --dart-define=SUPABASE_URL="https://your-project-id.supabase.co" \
    --dart-define=SUPABASE_ANON_KEY="your-anon-key-here" \
    --dart-define=SUPABASE_STORAGE_BUCKET="product-images"
```

---

## 📝 Ví dụ Thực Tế

```powershell
# Ví dụ với Supabase project thực tế
flutter run `
    --dart-define=SUPABASE_URL=https://abc123def456.supabase.co `
    --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9... `
    --dart-define=SUPABASE_STORAGE_BUCKET=product-images
```

---

## 🔑 Tìm Supabase Credentials

| Người tìm | Địa điểm |
|----------|----------|
| **URL** | Dashboard → Settings → API → Project URL |
| **Anon Key** | Dashboard → Settings → API → `anon (public)` |
| **Storage Bucket** | Dashboard → Storage → Tên bucket (thường là `product-images`) |

---

## ❓ Nếu vẫn có lỗi

### Lỗi: "Invalid URL"
- Đảm bảo URL bắt đầu bằng `https://`
- Đảm bảo URL kết thúc bằng `.supabase.co`

### Lỗi: "Invalid API key"
- Đảm bảo dùng **anon (public) key**, không phải service key
- Kiểm tra lại key không có dấu cách thừa

### Lỗi: "Bucket not found"
- Vào Storage và tạo bucket nếu chưa có
- Dùng tên bucket chính xác (case-sensitive)

---

## 🔒 Bảo Mật (Security)

⚠️ **KHÔNG** commit credentials vào Git!

```bash
# Thêm vào .gitignore
.env
.env.local
run_app.ps1  # (nếu chứa credentials thực tế)
```

---

## 📚 Tài liệu Thêm

- [Supabase Documentation](https://supabase.com/docs)
- [Flutter Supabase Integration](https://supabase.com/docs/reference/flutter/introduction)
- [Flutter --dart-define Guide](https://flutter.dev/docs/guide/initialization-values)
