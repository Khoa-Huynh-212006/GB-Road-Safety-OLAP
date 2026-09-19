# TỔNG HỢP THÔNG TIN DỮ LIỆU ĐÃ TRANSFORM VÀ THIẾT KẾ SCHEMA
(Phân tích dữ liệu thương vong giao thông đường bộ tại Great Britain 2021-2025)

Tài liệu này tổng hợp các thông tin quan trọng từ tài liệu phân tích, tập trung vào quá trình transform dữ liệu và thiết kế schema để các agents khác có thể nắm bắt nhanh cấu trúc dữ liệu và mô hình Data Warehouse.

---

## 1. QUÁ TRÌNH TRANSFORM DỮ LIỆU (DỮ LIỆU ĐẦU VÀO)

Mục tiêu của quá trình transform là tạo ra 3 file dữ liệu "sạch" phục vụ làm nguồn cho SSIS, không tạo trực tiếp bảng Fact/Dimension. Tổng cộng 37/99 cột được giữ lại từ dữ liệu gốc.

### Các quy tắc xử lý chính:
- **Đổi tên cột:** Đổi các tên cột gốc cho thống nhất và dễ hiểu (vd: `collision_index` -> `collision_id`, `age_of_casualty` -> `casualty_age`).
- **Chuyển mã thành nhãn:** Thay thế các mã số (code) bằng nhãn văn bản (label) để dễ phân tích (vd: 1 -> Fatal). File clean chỉ giữ nhãn.
- **Historic & Current:** Gộp thuộc tính, ưu tiên lấy chuẩn của Current, mỗi thuộc tính chỉ dùng 1 cột duy nhất.
- **Missing / Unknown:** Chuyển mã trống của dạng số thành null/ô trống; categorical chuyển thành "Unknown", "Not known", v.v.
- **Duplicate:** Xử lý bằng cách đối chiếu theo khóa tự nhiên. Hiện tại bộ dữ liệu không phát hiện duplicate.

### Các file sau Transform (Clean Data):

**1. `collisions_clean.csv`** (513.801 dòng, 18 cột)
- **Mô tả:** Thông tin chung về vụ va chạm (thời gian, địa điểm, mức độ nghiêm trọng, môi trường, nút giao, đường).
- **Khóa tự nhiên:** `collision_id`
- **Các cột chính:** `collision_id`, `collision_year`, `collision_date`, `collision_time`, `longitude`, `latitude`, `local_authority_district_code`, `collision_severity`, `first_road_class`, `road_type`, `speed_limit_mph`, `junction_detail`, `junction_control`, `pedestrian_crossing`, `light_conditions`, `weather_conditions`, `road_surface_conditions`, `area_type`.

**2. `vehicles_clean.csv`** (937.265 dòng, 8 cột)
- **Mô tả:** Thông tin phương tiện tham gia và người điều khiển.
- **Khóa tự nhiên:** `collision_id` + `vehicle_reference`
- **Các cột chính:** `collision_id`, `vehicle_reference`, `vehicle_type`, `vehicle_manoeuvre`, `driver_age_band`, `driver_sex`, `skidding_and_overturning`, `vehicle_leaving_carriageway`.

**3. `casualties_clean.csv`** (652.821 dòng, 11 cột)
- **Mô tả:** Thông tin chi tiết người bị thương vong.
- **Khóa tự nhiên:** `collision_id` + `casualty_reference`
- **Các cột chính:** `collision_id`, `vehicle_reference`, `casualty_reference`, `casualty_class`, `casualty_sex`, `casualty_age`, `casualty_age_band`, `casualty_severity`, `casualty_type`, `pedestrian_location`, `pedestrian_movement`.

**Quan hệ:**
- `collisions` (1) - (N) `vehicles` (qua `collision_id`)
- `collisions` (1) - (N) `casualties` (qua `collision_id`)
- `vehicles` (1) - (N) `casualties` (qua `collision_id` + `vehicle_reference`)

---

## 2. THIẾT KẾ SCHEMA (DATA WAREHOUSE)

### 2.1. Bảng Fact: `FactCasualty`
- **Grain (Độ hạt):** Một dòng đại diện cho **một casualty** (người thương vong) được ghi nhận trong một collision và liên kết với một phương tiện (vehicle) cụ thể.
- **Số dòng dự kiến:** 652.821 dòng.
- **Khóa tự nhiên:** `CollisionID` + `CasualtyReference`
- **Các cột Measure (Fact):** `CasualtyAge` (tuổi chính xác), `CasualtyCount` (luôn = 1), `FatalFlag` (0/1), `SeriousFlag` (0/1), `SlightFlag` (0/1), `KSIFlag` (0/1).

### 2.2. Mô hình Snowflake Schema
Sử dụng mô hình Snowflake để giảm thiểu lặp dữ liệu, thống nhất các định nghĩa và tạo Hierarchies rõ ràng cho SSAS. Mô hình bao gồm `FactCasualty` và các Dimensions phân cấp:

**Role-playing Dimension:**
- **DimSeverity** được dùng cho 2 role: `Casualty Severity` và `Collision Severity`.

**Các Dimension chính và phân cấp (Snowflake branches):**
1. **DimDate:** Phân cấp (Year -> Quarter -> Month -> FullDate).
2. **DimTime:** Có thông tin về khung giờ (`TimeBand`: Morning, Afternoon, Evening, Late Night).
3. **DimLocation** -> liên kết bảng con -> **DimLocalAuthority** (Mã ONS, Tên, Region).
4. **DimRoad** (RoadType, SpeedLimit, AreaType) -> liên kết bảng con -> **DimRoadClass** (vd: Motorway, A, B).
5. **DimEnvironment:** Gộp Thời tiết, Ánh sáng và Bề mặt đường vì chúng hay được phân tích kết hợp (không tạo bảng con).
6. **DimJunction:** Gộp chi tiết, điều khiển và vạch sang đường của nút giao (không tạo bảng con).
7. **DimCasualtyProfile** (Sex, Class, Type, Pedestrian info) -> liên kết bảng con -> **DimAgeBand**.
8. **DimVehicleInvolvement** (Bảng trung gian định danh chiếc xe trong tai nạn cụ thể) -> liên kết với:
   - **DimVehicleType** (Tên loại phương tiện, Nhóm phương tiện).
   - **DimVehicleEvent** (Manoeuvre, Skidding, Leaving Carriageway).
   - **DimDriverProfile** (Sex) -> liên kết tiếp -> **DimAgeBand**.

*(Lưu ý: Bảng **DimAgeBand** được dùng chung để định nghĩa nhóm tuổi cho cả Casualty và Driver)*

### 2.3. Tóm tắt Quan hệ Foreign Key từ FactCasualty:
- `FactCasualty` -> `DimDate`
- `FactCasualty` -> `DimTime`
- `FactCasualty` -> `DimLocation`
- `FactCasualty` -> `DimRoad`
- `FactCasualty` -> `DimEnvironment`
- `FactCasualty` -> `DimJunction`
- `FactCasualty` -> `DimCasualtyProfile`
- `FactCasualty` -> `DimVehicleInvolvement`
- `FactCasualty` -> `DimSeverity` (2 FK: `CasualtySeverityKey`, `CollisionSeverityKey`)
