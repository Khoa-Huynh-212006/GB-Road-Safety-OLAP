# Tổng quan Dữ liệu và Thiết kế Kho dữ liệu (STATS19)

Tài liệu này tổng hợp cấu trúc dữ liệu, các quy tắc làm sạch/chuyển đổi (transform) và thiết kế Schema mới nhất cho kho dữ liệu (Data Warehouse) dựa trên bộ dữ liệu tai nạn giao thông STATS19 (2021–2025). Tài liệu này đóng vai trò là "Data Contract" và "Schema Definition" để các agent khác có thể đọc và hiểu ngữ cảnh, dữ liệu, cũng như cấu trúc CSDL phục vụ cho quá trình ETL hoặc phân tích.

## 1. Nguồn Dữ liệu và Phạm vi
- **Bộ dữ liệu**: UK Road Safety STATS19, giai đoạn 2021–2025.
- **Grain phân tích chính**: Một người thương vong (casualty) trong một vụ va chạm (collision), gắn với một phương tiện (vehicle).
- **Các file nguồn chính (Raw Data)**:
  - `collisions_2021_2025.csv`: 513.801 dòng (44 cột) - Dữ liệu vụ va chạm.
  - `vehicles_2021_2025.csv`: 937.265 dòng (32 cột) - Dữ liệu phương tiện liên quan.
  - `casualties_2021_2025.csv`: 652.821 dòng (23 cột) - Dữ liệu người thương vong.

## 2. Quy tắc Làm sạch và Chuyển đổi (Transform)
Quá trình chuyển đổi (Transform) không làm thay đổi file Raw gốc, mà tạo ra 3 file "Clean" (sạch) để làm đầu vào cho quá trình SSIS (nạp vào Data Warehouse).

### 2.1. Quy tắc xử lý chung
- **Chuyển mã thành nhãn (Code to Label)**: Các trường phân loại (ví dụ: `collision_severity = 1`) sẽ được thay bằng nhãn có ý nghĩa (`Fatal`) dựa vào Data Guide. KHÔNG giữ đồng thời cột mã và cột nhãn.
- **Giữ lại các mã định danh/khóa**: Các khóa như `collision_index`, `vehicle_reference`, `casualty_reference`, và `local_authority_district_code` vẫn giữ nguyên dạng mã. Các khóa này được đọc ở định dạng chuỗi (String) để tránh sai lệch.
- **Xử lý Missing/Unknown**:
  - Dữ liệu bị thiếu (`Unknown`, `-1`, `9`, `99`) sẽ được chuyển thành nhãn tương ứng (như `Not known`, `Not reported`, `Unknown`) đối với cột phân loại.
  - Đối với cột số (tuổi, tọa độ), giá trị thiếu/không hợp lệ chuyển thành rỗng (NULL).
  - Không tự ý xóa các bản ghi ngoại lai (outlier) hay các bản ghi có giá trị Unknown.

### 2.2. Dữ liệu đầu ra (Clean Files)
Quá trình xử lý sẽ sinh ra 3 file CSV có tổng cộng 37 cột:
1. **`collisions_clean.csv` (18 cột)**
   - Khóa: `collision_id` (String)
   - Thông tin: `collision_year`, `collision_date`, `collision_time`, `longitude`, `latitude`, `local_authority_district_code`, `collision_severity`, `first_road_class`, `road_type`, `speed_limit_mph`, `junction_detail`, `junction_control`, `pedestrian_crossing`, `light_conditions`, `weather_conditions`, `road_surface_conditions`, `area_type`.
2. **`vehicles_clean.csv` (8 cột)**
   - Khóa tự nhiên: `collision_id` + `vehicle_reference`
   - Thông tin: `vehicle_type`, `vehicle_manoeuvre`, `driver_age_band`, `driver_sex`, `skidding_and_overturning`, `vehicle_leaving_carriageway`.
3. **`casualties_clean.csv` (11 cột)**
   - Khóa tự nhiên: `collision_id` + `casualty_reference`
   - Thông tin: `vehicle_reference`, `casualty_class`, `casualty_sex`, `casualty_age`, `casualty_age_band`, `casualty_severity`, `casualty_type`, `pedestrian_location`, `pedestrian_movement`.

---

## 3. Thiết kế Schema Mới (Snowflake Schema)
Đây là bản thiết kế schema MỚI NHẤT và CHÍNH THỨC, sử dụng mô hình Snowflake để tổ chức kho dữ liệu (Data Warehouse).

### 3.1. Tổng quan kiến trúc
- **Bảng Fact**: 1 bảng (`FactCasualty`)
- **Dimension trực tiếp**: 9 bảng (`DimDate`, `DimTime`, `DimLocation`, `DimRoad`, `DimEnvironment`, `DimJunction`, `DimCasualtyProfile`, `DimVehicleProfile`, `DimSeverity`)
- **Dimension phụ (nhánh Snowflake)**: 3 bảng (`DimTimeBand`, `DimLocalAuthority`, `DimPedestrianContext`)

**Grain của Fact**: Mỗi dòng trong `FactCasualty` đại diện cho một casualty trong một collision, gắn với một vehicle involvement cụ thể.

### 3.2. Cấu trúc bảng Fact
**`FactCasualty`**
- `FactCasualtyKey` (BIGINT, PK, Surrogate Key)
- `CollisionID` (VARCHAR(20), Degenerate Dimension)
- `VehicleInvolvementID` (VARCHAR(30), Degenerate Dimension - tạo từ CollisionID + VehicleReference)
- `CasualtyReference` (INT, Thành phần Natural Key)
- `DateKey` (INT, FK -> DimDate)
- `TimeKey` (INT, FK -> DimTime)
- `LocationKey` (INT, FK -> DimLocation)
- `RoadKey` (INT, FK -> DimRoad)
- `EnvironmentKey` (INT, FK -> DimEnvironment)
- `JunctionKey` (INT, FK -> DimJunction)
- `CasualtyProfileKey` (INT, FK -> DimCasualtyProfile)
- `VehicleProfileKey` (INT, FK -> DimVehicleProfile)
- `CasualtySeverityKey` (TINYINT, FK -> DimSeverity đóng vai trò Casualty Severity)
- `CollisionSeverityKey` (TINYINT, FK -> DimSeverity đóng vai trò Collision Severity)
- `CasualtyAge` (SMALLINT, Có thể NULL) - Numeric Fact
- `CasualtyCount` (TINYINT) - Bằng 1 (Additive Measure)
- `KSIFlag` (BIT) - Bằng 1 nếu severity là Fatal/Serious, ngược lại bằng 0 (Additive Measure)

### 3.3. Cấu trúc các bảng Dimension

**1. Chiều Thời gian (Time / Date)**
* **`DimDate`**
  - `DateKey` (INT, PK, dạng YYYYMMDD, 0 cho Unknown)
  - `FullDate` (DATE, Business key)
  - `Day` (TINYINT)
  - `DayName` (NVARCHAR(10))
  - `DayOfWeek` (TINYINT)
  - `Month` (TINYINT)
  - `Quarter` (CHAR(2))
  - `Year` (SMALLINT)
  - `IsWeekend` (BIT)
* **`DimTimeBand`** (Dimension phụ)
  - `TimeBandKey` (TINYINT, PK)
  - `TimeBandName` (NVARCHAR(30))
  - `TimeBandSort` (TINYINT)
* **`DimTime`**
  - `TimeKey` (INT, PK)
  - `FullTime` (TIME(0))
  - `Hour` (TINYINT)
  - `Minute` (TINYINT)
  - `TimeBandKey` (TINYINT, FK -> DimTimeBand)

**2. Chiều Không gian (Location)**
* **`DimLocalAuthority`** (Dimension phụ)
  - `LocalAuthorityKey` (INT, PK)
  - `LocalAuthorityCode` (NVARCHAR(20), Business key)
  - `LocalAuthorityName` (NVARCHAR(150))
  - `RegionName` (NVARCHAR(100))
* **`DimLocation`**
  - `LocationKey` (INT, PK)
  - `Longitude` (DECIMAL(9,6), NULL)
  - `Latitude` (DECIMAL(9,6), NULL)
  - `LocalAuthorityKey` (INT, FK -> DimLocalAuthority)

**3. Chiều Môi trường và Đặc điểm Đường (Road & Environment)**
* **`DimRoad`**
  - `RoadKey` (INT, PK)
  - `RoadClass` (NVARCHAR(50))
  - `RoadType` (NVARCHAR(100))
  - `SpeedLimitMph` (SMALLINT, NULL)
  - `AreaType` (NVARCHAR(30))
* **`DimEnvironment`** (Junk dimension)
  - `EnvironmentKey` (INT, PK)
  - `LightCondition` (NVARCHAR(100))
  - `WeatherCondition` (NVARCHAR(100))
  - `RoadSurfaceCondition` (NVARCHAR(100))
* **`DimJunction`**
  - `JunctionKey` (INT, PK)
  - `JunctionDetail` (NVARCHAR(150))
  - `JunctionControl` (NVARCHAR(150))
  - `PedestrianCrossing` (NVARCHAR(150))

**4. Chiều Đối tượng (Vehicle & Casualty)**
* **`DimPedestrianContext`** (Dimension phụ)
  - `PedestrianContextKey` (INT, PK)
  - `PedestrianLocation` (NVARCHAR(150))
  - `PedestrianMovement` (NVARCHAR(150))
* **`DimCasualtyProfile`**
  - `CasualtyProfileKey` (INT, PK)
  - `CasualtyAgeBand` (NVARCHAR(50))
  - `CasualtySex` (NVARCHAR(30))
  - `CasualtyClass` (NVARCHAR(50))
  - `CasualtyType` (NVARCHAR(100))
  - `PedestrianContextKey` (INT, FK -> DimPedestrianContext)
* **`DimVehicleProfile`**
  - `VehicleProfileKey` (INT, PK)
  - `VehicleType` (NVARCHAR(100))
  - `DriverAgeBand` (NVARCHAR(50))
  - `DriverSex` (NVARCHAR(30))
  - `VehicleManoeuvre` (NVARCHAR(150))
  - `SkiddingAndOverturning` (NVARCHAR(150))
  - `VehicleLeavingCarriageway` (NVARCHAR(150))

**5. Chiều Mức độ (Severity)**
* **`DimSeverity`** (Role-playing dimension cho Casualty và Collision)
  - `SeverityKey` (TINYINT, PK)
  - `SeverityName` (NVARCHAR(20))
  - `IsKSI` (BIT, 1 nếu Fatal/Serious)
