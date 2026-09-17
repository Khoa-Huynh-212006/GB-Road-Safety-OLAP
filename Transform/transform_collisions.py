"""
transform_collisions.py
=======================
Chuyển đổi collisions_2021_2025.csv → collisions_clean.csv

Data contract (18 cột):
    collision_id, collision_year, collision_date, collision_time,
    longitude, latitude, local_authority_district_code,
    collision_severity, first_road_class, road_type, speed_limit_mph,
    junction_detail, junction_control, pedestrian_crossing,
    light_conditions, weather_conditions, road_surface_conditions, area_type

Logic gán nhãn (theo data_guide):
    Bước 1 – Chuẩn hóa missing:
        - Trường phân loại : mã không tìm thấy → "Unknown"
        - Trường số        : giá trị thiếu/không hợp lệ → ô trống (pd.NA)
    Bước 2 – Gán nhãn từ data_guide (2024_code_list):
        - Nếu kết quả vẫn là "Unknown" → thử field _historic tương ứng
          qua bảng 2011_to_2024_conversion để lấy nhãn 2024 đúng nghĩa.

Chạy:
    python transform_collisions.py

Yêu cầu:
    pip install pandas openpyxl
"""

from pathlib import Path
import pandas as pd
import sys
from datetime import datetime


# 1. CẤU HÌNH ĐƯỜNG DẪN

PROJECT_ROOT = Path(__file__).resolve().parent.parent

INPUT_PATH = PROJECT_ROOT / "Data" / "Raw" / "collisions_2021_2025.csv"

DATA_GUIDE_PATH = PROJECT_ROOT / "Data" / "Reference" / "data_guide.csv"

OUTPUT_PATH = PROJECT_ROOT / "Data" / "Processed" / "collisions_clean.csv"

ERROR_PATH = PROJECT_ROOT / "Data" / "Processed" / "collisions_errors.csv"


# 18 cột nguồn cần đọc (không kể _historic, sẽ được phát hiện động)
SOURCE_COLUMNS = [
    "collision_index",
    "collision_year",
    "date",
    "time",
    "longitude",
    "latitude",
    "local_authority_ons_district",
    "collision_severity",
    "first_road_class",
    "road_type",
    "speed_limit",
    "junction_detail",
    "junction_control",
    "pedestrian_crossing",
    "light_conditions",
    "weather_conditions",
    "road_surface_conditions",
    "urban_or_rural_area",
]

# Thứ tự chính thức 18 cột đầu ra
OUTPUT_COLUMNS = [
    "collision_id",
    "collision_year",
    "collision_date",
    "collision_time",
    "longitude",
    "latitude",
    "local_authority_district_code",
    "collision_severity",
    "first_road_class",
    "road_type",
    "speed_limit_mph",
    "junction_detail",
    "junction_control",
    "pedestrian_crossing",
    "light_conditions",
    "weather_conditions",
    "road_surface_conditions",
    "area_type",
]

# Khóa tự nhiên của Collisions
NATURAL_KEY = ["collision_id"]

VALID_YEARS = {2021, 2022, 2023, 2024, 2025}

# Nhãn được xem là dữ liệu thiếu / không xác định
UNKNOWN_LABEL_PATTERNS = [
    "unknown",
    "not known",
    "not reported",
    "not applicable",
    "data missing",
    "out of range",
    "undefined",
]

# Field _historic dùng làm fallback (key = field hiện tại, value = danh sách historic)
HISTORIC_FALLBACKS: dict[str, list[str]] = {
    "junction_detail": [
        "junction_detail_historic",
    ],
    "pedestrian_crossing": [
        "pedestrian_crossing_human_control_historic",
        "pedestrian_crossing_physical_facilities_historic",
    ],
}


# 2. CÁC HÀM HỖ TRỢ


def normalize_column_name(column_name):
    """Chuẩn hóa tên cột trong Data Guide."""
    return str(column_name).strip().lower().replace("_", " ")


def normalize_code_series(series):
    """
    Chuẩn hóa mã trước khi tra cứu Data Guide.

    Ví dụ:
    " 1 "  -> "1"
    "1.0"  -> "1"
    ""     -> pd.NA
    """
    result = series.astype("string").str.strip()
    result = result.replace("", pd.NA)
    decimal_integer_mask = result.str.match(r"^-?\d+\.0+$", na=False)
    result.loc[decimal_integer_mask] = (
        result.loc[decimal_integer_mask].str.replace(r"\.0+$", "", regex=True)
    )
    return result


def normalize_text_series(series):
    """
    Chuẩn hóa chuỗi:
    - Bỏ khoảng trắng đầu/cuối.
    - Gộp nhiều khoảng trắng liên tiếp.
    - Chuỗi rỗng → pd.NA.
    """
    result = series.astype("string").str.strip()
    result = result.str.replace(r"\s+", " ", regex=True)
    result = result.replace("", pd.NA)
    return result


def standardize_unknown_labels(series):
    """
    Chuẩn hóa các nhãn thiếu / không xác định thành "Unknown".
    """
    result = normalize_text_series(series)
    lower_result = result.str.lower()
    unknown_mask = result.isna()
    for pattern in UNKNOWN_LABEL_PATTERNS:
        unknown_mask = unknown_mask | lower_result.str.contains(
            pattern, regex=False, na=False
        )
    return result.mask(unknown_mask, "Unknown").astype("string")


def read_data_guide():
    """Đọc Data Guide (Excel - sheet 2024_code_list)."""
    if not DATA_GUIDE_PATH.exists():
        raise FileNotFoundError(f"Không tìm thấy Data Guide: {DATA_GUIDE_PATH}")
    guide = pd.read_csv(
        DATA_GUIDE_PATH,
        sep=None,
        engine="python",
        dtype="string",
        encoding="utf-8-sig",
        keep_default_na=False,
    )
    guide.columns = [normalize_column_name(c) for c in guide.columns]
    required = {"table", "field name", "code/format", "label"}
    missing = required - set(guide.columns)
    if missing:
        raise ValueError(f"Data Guide thiếu cột bắt buộc: {sorted(missing)}")
    guide["table"] = guide["table"].astype("string").str.strip().str.lower()
    guide["field name"] = guide["field name"].astype("string").str.strip().str.lower()
    guide["code/format"] = normalize_code_series(guide["code/format"])
    guide["label"] = normalize_text_series(guide["label"])
    return guide


def read_historic_guide():
    """
    Đọc bảng chuyển đổi historic → 2024 từ Data Guide.
    (Đã loại bỏ vì file CSV không hỗ trợ sheet 2011_to_2024_conversion)
    """
    return {}


def get_lookup(guide, table_name, field_name):
    """Lấy dict ánh xạ mã → nhãn cho một field."""
    table_name = table_name.strip().lower()
    field_name = field_name.strip().lower()
    rows = guide.loc[
        (guide["table"] == table_name) & (guide["field name"] == field_name),
        ["code/format", "label"],
    ].copy()
    rows = rows.dropna(subset=["code/format", "label"])
    rows = rows.loc[rows["code/format"].ne("") & rows["label"].ne("")]
    rows = rows.drop_duplicates(subset=["code/format"], keep="last")
    if rows.empty:
        raise KeyError(f"Không tìm thấy lookup trong Data Guide cho {table_name}.{field_name}")
    return dict(zip(rows["code/format"], rows["label"]))


def map_category(source_series, guide, field_name, table_name="collision"):
    """
    Thay mã của thuộc tính phân loại bằng nhãn trong Data Guide.
    Mã không tìm thấy → Unknown.
    """
    source_codes = normalize_code_series(source_series)
    lookup = get_lookup(guide, table_name, field_name)
    mapped = source_codes.map(lookup).astype("string")
    unmapped_count = int((source_codes.notna() & mapped.isna()).sum())
    mapped = standardize_unknown_labels(mapped)
    return mapped, unmapped_count


def combine_historic_and_current(historic_labels, current_labels):
    """
    Hợp nhất field Historic và Current:
    1. Ưu tiên Current nếu hợp lệ (không phải Unknown).
    2. Nếu Current là Unknown → dùng Historic.
    3. Cả hai Unknown → "Unknown".
    4. Cả hai hợp lệ nhưng khác → ưu tiên Current.
    """
    historic_labels = standardize_unknown_labels(historic_labels)
    current_labels = standardize_unknown_labels(current_labels)
    historic_valid = historic_labels.notna() & historic_labels.ne("Unknown")
    current_valid = current_labels.notna() & current_labels.ne("Unknown")
    historic_used_count = int((~current_valid & historic_valid).sum())
    conflict_count = int(
        (current_valid & historic_valid
         & current_labels.str.casefold().ne(historic_labels.str.casefold())).sum()
    )
    combined = current_labels.where(current_valid, historic_labels).fillna("Unknown")
    return combined.astype("string"), {
        "historic_used": historic_used_count,
        "current_historic_conflicts": conflict_count,
    }


def convert_nullable_integer(series):
    """Chuyển sang Int64. Không parse được → pd.NA."""
    return pd.to_numeric(series, errors="coerce").astype("Int64")


def convert_nullable_float(series, min_val=None, max_val=None):
    """Chuyển sang float. Ngoài miền → pd.NA."""
    result = pd.to_numeric(series, errors="coerce")
    if min_val is not None:
        result = result.where(result >= min_val, other=pd.NA)
    if max_val is not None:
        result = result.where(result <= max_val, other=pd.NA)
    return result


def check_required_columns(csv_path, required_cols):
    """Kiểm tra file nguồn có đủ các cột bắt buộc."""
    if not csv_path.exists():
        raise FileNotFoundError(f"Không tìm thấy file nguồn: {csv_path}")
    header = pd.read_csv(csv_path, nrows=0, encoding="utf-8-sig")
    missing = set(required_cols) - set(header.columns)
    if missing:
        raise ValueError(f"File Collisions thiếu cột bắt buộc: {sorted(missing)}")
    return list(header.columns)


# 3. QUY TRÌNH TRANSFORM COLLISIONS


def main():
    print(f"Đang đọc: {INPUT_PATH}")

    all_cols = check_required_columns(INPUT_PATH, SOURCE_COLUMNS)

    # Phát hiện cột _historic có trong file nguồn
    all_historic = [h for hlist in HISTORIC_FALLBACKS.values() for h in hlist]
    historic_present = [c for c in all_historic if c in all_cols]
    cols_to_read = SOURCE_COLUMNS + historic_present

    # Đọc toàn bộ dưới dạng string để bảo toàn collision_index và mã
    source = pd.read_csv(
        INPUT_PATH,
        usecols=cols_to_read,
        dtype="string",
        encoding="utf-8-sig",
        low_memory=False,
    )

    input_rows = len(source)
    print(f"Số dòng đầu vào   : {input_rows:,}")
    print(f"Số cột được đọc   : {len(cols_to_read)}")
    print(f"Cột historic có   : {historic_present or 'không có'}")

    guide = read_data_guide()

    # 3.1. Xử lý khóa và trường số

    collision_id = normalize_text_series(source["collision_index"])

    collision_year = convert_nullable_integer(source["collision_year"])

    collision_date = source["date"].apply(_parse_date)

    collision_time = source["time"].apply(_parse_time)

    # Tọa độ – ngoài miền GB → ô trống
    longitude = convert_nullable_float(source["longitude"], min_val=-8.65, max_val=1.78)
    latitude  = convert_nullable_float(source["latitude"],  min_val=49.9,  max_val=60.9)

    # Mã địa lý – giữ nguyên String
    local_authority_district_code = normalize_text_series(
        source["local_authority_ons_district"]
    )

    # Speed limit – số nguyên; giá trị -1/ngoài [1,80] → ô trống
    speed_limit_mph = convert_nullable_integer(source["speed_limit"])
    speed_limit_mph = speed_limit_mph.where(
        speed_limit_mph.between(1, 80, inclusive="both"), other=pd.NA
    )

    # 3.2. Ánh xạ trường phân loại → nhãn

    unmapped_counts = {}

    collision_severity, unmapped_counts["collision_severity"] = map_category(
        source["collision_severity"], guide, "collision_severity"
    )

    first_road_class, unmapped_counts["first_road_class"] = map_category(
        source["first_road_class"], guide, "first_road_class"
    )

    road_type, unmapped_counts["road_type"] = map_category(
        source["road_type"], guide, "road_type"
    )

    # junction_detail: thử current trước, nếu Unknown thử historic
    junction_detail_curr, unmapped_counts["junction_detail"] = map_category(
        source["junction_detail"], guide, "junction_detail"
    )
    if "junction_detail_historic" in source.columns:
        junction_detail_hist, unmapped_counts["junction_detail_historic"] = map_category(
            source["junction_detail_historic"], guide, "junction_detail_historic"
        )
        junction_detail, jd_stats = combine_historic_and_current(
            junction_detail_hist, junction_detail_curr
        )
    else:
        junction_detail = junction_detail_curr
        jd_stats = {"historic_used": 0, "current_historic_conflicts": 0}

    junction_control, unmapped_counts["junction_control"] = map_category(
        source["junction_control"], guide, "junction_control"
    )

    # pedestrian_crossing: thử current trước, nếu Unknown thử 2 historic
    pedestrian_crossing_curr, unmapped_counts["pedestrian_crossing"] = map_category(
        source["pedestrian_crossing"], guide, "pedestrian_crossing"
    )
    pc_stats = {"historic_used": 0, "current_historic_conflicts": 0}
    pedestrian_crossing = pedestrian_crossing_curr
    for hist_col in ["pedestrian_crossing_human_control_historic",
                     "pedestrian_crossing_physical_facilities_historic"]:
        if hist_col in source.columns:
            hist_labels, _ = map_category(source[hist_col], guide, hist_col)
            pedestrian_crossing, stats = combine_historic_and_current(
                hist_labels, pedestrian_crossing
            )
            pc_stats["historic_used"] += stats["historic_used"]
            pc_stats["current_historic_conflicts"] += stats["current_historic_conflicts"]

    light_conditions, unmapped_counts["light_conditions"] = map_category(
        source["light_conditions"], guide, "light_conditions"
    )

    weather_conditions, unmapped_counts["weather_conditions"] = map_category(
        source["weather_conditions"], guide, "weather_conditions"
    )

    road_surface_conditions, unmapped_counts["road_surface_conditions"] = map_category(
        source["road_surface_conditions"], guide, "road_surface_conditions"
    )

    area_type, unmapped_counts["urban_or_rural_area"] = map_category(
        source["urban_or_rural_area"], guide, "urban_or_rural_area"
    )

    # 3.3. Tạo DataFrame đầu ra

    output: pd.DataFrame = pd.DataFrame({
        "collision_id":                   collision_id,
        "collision_year":                 collision_year,
        "collision_date":                 collision_date,
        "collision_time":                 collision_time,
        "longitude":                      longitude,
        "latitude":                       latitude,
        "local_authority_district_code":  local_authority_district_code,
        "collision_severity":             collision_severity,
        "first_road_class":               first_road_class,
        "road_type":                      road_type,
        "speed_limit_mph":                speed_limit_mph,
        "junction_detail":                junction_detail,
        "junction_control":               junction_control,
        "pedestrian_crossing":            pedestrian_crossing,
        "light_conditions":               light_conditions,
        "weather_conditions":             weather_conditions,
        "road_surface_conditions":        road_surface_conditions,
        "area_type":                      area_type,
    })

    output = output[OUTPUT_COLUMNS]

    # 3.4. Kiểm tra khóa tự nhiên – collision_id không được rỗng
    missing_key_mask = output[NATURAL_KEY].isna().any(axis=1)
    missing_key_count = int(missing_key_mask.sum())
    if missing_key_count > 0:
        raise ValueError(
            f"Phát hiện {missing_key_count:,} dòng thiếu khóa tự nhiên (collision_id)."
        )

    # 3.5. Kiểm tra năm hợp lệ 2021-2025
    bad_year_mask = ~output["collision_year"].isin(VALID_YEARS)
    bad_year_count = int(bad_year_mask.sum())
    if bad_year_count > 0:
        print(f"[WARN] {bad_year_count:,} dòng có collision_year ngoài 2021-2025 → loại.")
        output = output[~bad_year_mask].copy()

    # 3.6. Drop duplicate theo khóa tự nhiên
    duplicate_mask = output.duplicated(subset=NATURAL_KEY, keep="first")
    duplicate_count = int(duplicate_mask.sum())
    output = output.drop_duplicates(subset=NATURAL_KEY, keep="first").copy()

    # 3.7. Xuất CSV
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    output.to_csv(
        OUTPUT_PATH,
        index=False,
        encoding="utf-8-sig",
        na_rep="",
        lineterminator="\n",
    )

    # 3.8. In kết quả
    print()
    print("TRANSFORM COLLISIONS HOÀN THÀNH")
    print(f"Input rows        : {input_rows:,}")
    print(f"Bad year removed  : {bad_year_count:,}")
    print(f"Duplicates removed: {duplicate_count:,}")
    print(f"Output rows       : {len(output):,}")
    print(f"Output columns    : {len(output.columns)}")
    print(f"Output file       : {OUTPUT_PATH}")

    print()
    print("HISTORIC/CURRENT MERGE")
    print(f"  junction_detail    – historic used: {jd_stats['historic_used']:,}, conflicts: {jd_stats['current_historic_conflicts']:,}")
    print(f"  pedestrian_crossing – historic used: {pc_stats['historic_used']:,}, conflicts: {pc_stats['current_historic_conflicts']:,}")

    total_unmapped = sum(unmapped_counts.values())
    print()
    print("DATA GUIDE MAPPING")
    if total_unmapped == 0:
        print("Không phát hiện mã chưa được ánh xạ.")
    else:
        print("Các mã không tìm thấy trong Data Guide đã được chuyển thành Unknown:")
        for field_name, count in unmapped_counts.items():
            if count > 0:
                print(f"  {field_name}: {count:,}")


# Hàm parse ngày/giờ (dùng nội bộ)

def _parse_date(value):
    """DD/MM/YYYY | YYYY-MM-DD → 'YYYY-MM-DD'. Không parse được → pd.NA."""
    if pd.isna(value) or str(value).strip() == "":
        return pd.NA
    s = str(value).strip()
    for fmt in ("%d/%m/%Y", "%Y-%m-%d", "%m/%d/%Y"):
        try:
            return datetime.strptime(s, fmt).strftime("%Y-%m-%d")
        except ValueError:
            continue
    return pd.NA


def _parse_time(value):
    """HH:MM | HH:MM:SS → 'HH:MM:SS'. Thiếu → pd.NA."""
    if pd.isna(value) or str(value).strip() == "":
        return pd.NA
    s = str(value).strip()
    for fmt in ("%H:%M", "%H:%M:%S"):
        try:
            return datetime.strptime(s, fmt).strftime("%H:%M:%S")
        except ValueError:
            continue
    return pd.NA


if __name__ == "__main__":
    main()
