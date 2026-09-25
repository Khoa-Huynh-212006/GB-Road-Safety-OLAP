r"""
validate_clean_data.py
======================
Kiểm tra ba file dữ liệu sạch của dự án STATS19 trước khi dùng cho SSIS
hoặc notebook ước tính số dòng Dimension.

Đặt file tại:
    D:\OLAP\Transform\validate_clean_data.py

Chạy:
    cd D:\OLAP\Transform
    py validate_clean_data.py
"""

from pathlib import Path
import sys

import pandas as pd


# ============================================================
# 1. CẤU HÌNH
# ============================================================

PROJECT_ROOT = Path(__file__).resolve().parent.parent

RAW_DIR = PROJECT_ROOT / "Data" / "Raw"
PROCESSED_DIR = PROJECT_ROOT / "Data" / "Processed"

RAW_VEHICLES_FILE = RAW_DIR / "vehicles_2021_2025.csv"
COLLISIONS_FILE = PROCESSED_DIR / "collisions_clean.csv"
VEHICLES_FILE = PROCESSED_DIR / "vehicles_clean.csv"
CASUALTIES_FILE = PROCESSED_DIR / "casualties_clean.csv"


EXPECTED_ROWS = {
    "Collisions": 513_801,
    "Vehicles": 937_265,
    "Casualties": 652_821,
}


EXPECTED_COLUMNS = {
    "Collisions": [
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
    ],
    "Vehicles": [
        "collision_id",
        "vehicle_reference",
        "vehicle_type",
        "vehicle_manoeuvre",
        "driver_age_band",
        "driver_sex",
        "skidding_and_overturning",
        "vehicle_leaving_carriageway",
    ],
    "Casualties": [
        "collision_id",
        "vehicle_reference",
        "casualty_reference",
        "casualty_class",
        "casualty_sex",
        "casualty_age",
        "casualty_age_band",
        "casualty_severity",
        "casualty_type",
        "pedestrian_location",
        "pedestrian_movement",
    ],
}


EXPECTED_FACT_VEHICLE_PAIRS = 566_945
EXPECTED_VEHICLES_OUTSIDE_FACT = 370_320


# ============================================================
# 2. HÀM HỖ TRỢ
# ============================================================

validation_results = []


def add_check(check_name, passed, actual, expected, note=""):
    """Ghi nhận kết quả của một phép kiểm tra."""
    validation_results.append(
        {
            "Check": check_name,
            "Status": "PASS" if passed else "FAIL",
            "Actual": actual,
            "Expected": expected,
            "Note": note,
        }
    )


def read_csv_as_text(path, usecols):
    """
    Đọc CSV nhưng không cho Pandas tự biến chuỗi 'None' thành NaN.

    Ô trống được giữ là chuỗi rỗng để có thể kiểm tra rõ ràng.
    """
    return pd.read_csv(
        path,
        usecols=usecols,
        dtype="string",
        encoding="utf-8-sig",
        keep_default_na=False,
        na_filter=False,
        low_memory=False,
    )


def blank_mask(series):
    """Xác định chuỗi rỗng hoặc chỉ chứa khoảng trắng."""
    return series.astype("string").str.strip().eq("")


def check_file_exists(path, file_name):
    exists = path.exists() and path.is_file()
    add_check(
        check_name=f"{file_name}: file tồn tại",
        passed=exists,
        actual=str(path) if exists else "Not found",
        expected="File exists",
    )
    return exists


def check_exact_columns(path, dataset_name):
    actual_columns = list(
        pd.read_csv(
            path,
            nrows=0,
            encoding="utf-8-sig",
        ).columns
    )

    expected_columns = EXPECTED_COLUMNS[dataset_name]

    add_check(
        check_name=f"{dataset_name}: danh sách cột",
        passed=actual_columns == expected_columns,
        actual=len(actual_columns),
        expected=len(expected_columns),
        note=(
            "Đúng cả số lượng, tên và thứ tự cột."
            if actual_columns == expected_columns
            else (
                f"Actual={actual_columns}; "
                f"Expected={expected_columns}"
            )
        ),
    )


# ============================================================
# 3. KIỂM TRA FILE VÀ CẤU TRÚC
# ============================================================

print("KIỂM TRA FILE ĐẦU VÀO\n")

required_files = {
    "Raw Vehicles": RAW_VEHICLES_FILE,
    "Collisions": COLLISIONS_FILE,
    "Vehicles": VEHICLES_FILE,
    "Casualties": CASUALTIES_FILE,
}

all_files_exist = True

for name, path in required_files.items():
    exists = check_file_exists(path, name)
    all_files_exist = all_files_exist and exists
    print(f"{name:<15}: {'OK' if exists else 'NOT FOUND'}")

if not all_files_exist:
    print("\nThiếu file bắt buộc. Dừng validation.")
    sys.exit(1)


check_exact_columns(COLLISIONS_FILE, "Collisions")
check_exact_columns(VEHICLES_FILE, "Vehicles")
check_exact_columns(CASUALTIES_FILE, "Casualties")


# ============================================================
# 4. ĐỌC CÁC CỘT CẦN CHO VALIDATION
# ============================================================

print("\nĐang đọc các cột cần kiểm tra...")

df_col = read_csv_as_text(
    COLLISIONS_FILE,
    [
        "collision_id",
        "collision_year",
        "collision_date",
        "collision_time",
        "area_type",
        "collision_severity",
    ],
)

df_veh = read_csv_as_text(
    VEHICLES_FILE,
    [
        "collision_id",
        "vehicle_reference",
        "skidding_and_overturning",
    ],
)

df_cas = read_csv_as_text(
    CASUALTIES_FILE,
    [
        "collision_id",
        "vehicle_reference",
        "casualty_reference",
        "casualty_severity",
        "casualty_class",
        "pedestrian_location",
        "pedestrian_movement",
    ],
)


# ============================================================
# 5. SỐ DÒNG
# ============================================================

dataframes = {
    "Collisions": df_col,
    "Vehicles": df_veh,
    "Casualties": df_cas,
}

for name, dataframe in dataframes.items():
    actual_rows = len(dataframe)
    expected_rows = EXPECTED_ROWS[name]

    add_check(
        check_name=f"{name}: số dòng",
        passed=actual_rows == expected_rows,
        actual=f"{actual_rows:,}",
        expected=f"{expected_rows:,}",
    )


# ============================================================
# 6. KHÓA TỰ NHIÊN
# ============================================================

natural_keys = {
    "Collisions": (
        df_col,
        ["collision_id"],
    ),
    "Vehicles": (
        df_veh,
        ["collision_id", "vehicle_reference"],
    ),
    "Casualties": (
        df_cas,
        ["collision_id", "casualty_reference"],
    ),
}

for name, (dataframe, key_columns) in natural_keys.items():
    missing_key_mask = pd.Series(False, index=dataframe.index)

    for column in key_columns:
        missing_key_mask |= blank_mask(dataframe[column])

    missing_key_count = int(missing_key_mask.sum())
    duplicate_count = int(
        dataframe.duplicated(
            subset=key_columns,
            keep=False,
        ).sum()
    )

    add_check(
        check_name=f"{name}: khóa không rỗng",
        passed=missing_key_count == 0,
        actual=missing_key_count,
        expected=0,
    )

    add_check(
        check_name=f"{name}: khóa không trùng",
        passed=duplicate_count == 0,
        actual=duplicate_count,
        expected=0,
    )


# ============================================================
# 7. NĂM, NGÀY VÀ GIỜ CỦA COLLISIONS
# ============================================================

collision_year_numeric = pd.to_numeric(
    df_col["collision_year"],
    errors="coerce",
)

valid_year_mask = collision_year_numeric.isin(
    [2021, 2022, 2023, 2024, 2025]
)

invalid_year_count = int((~valid_year_mask).sum())

add_check(
    check_name="Collisions: năm thuộc 2021-2025",
    passed=invalid_year_count == 0,
    actual=invalid_year_count,
    expected=0,
)


parsed_dates = pd.to_datetime(
    df_col["collision_date"],
    format="%Y-%m-%d",
    errors="coerce",
)

invalid_date_count = int(parsed_dates.isna().sum())

add_check(
    check_name="Collisions: định dạng ngày hợp lệ",
    passed=invalid_date_count == 0,
    actual=invalid_date_count,
    expected=0,
)


date_year_mismatch = int(
    (
        parsed_dates.notna()
        & collision_year_numeric.notna()
        & parsed_dates.dt.year.ne(collision_year_numeric)
    ).sum()
)

add_check(
    check_name="Collisions: năm của date khớp collision_year",
    passed=date_year_mismatch == 0,
    actual=date_year_mismatch,
    expected=0,
)


time_pattern = r"^(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d$"

time_blank = blank_mask(df_col["collision_time"])
time_valid = df_col["collision_time"].str.match(
    time_pattern,
    na=False,
)

invalid_nonblank_time_count = int(
    (~time_blank & ~time_valid).sum()
)

add_check(
    check_name="Collisions: định dạng giờ hợp lệ",
    passed=invalid_nonblank_time_count == 0,
    actual=invalid_nonblank_time_count,
    expected=0,
    note="Giờ trống được chấp nhận và sẽ vào Unknown member.",
)


# ============================================================
# 8. KIỂM TRA MAPPING NGHIỆP VỤ QUAN TRỌNG
# ============================================================

# 8.1 Raw code 0 của skidding phải trở thành nhãn None.
raw_skidding = read_csv_as_text(
    RAW_VEHICLES_FILE,
    ["skidding_and_overturning"],
)

raw_skidding_codes = (
    raw_skidding["skidding_and_overturning"]
    .str.strip()
)

clean_skidding_labels = (
    df_veh["skidding_and_overturning"]
    .str.strip()
)

raw_code_zero_count = int(
    raw_skidding_codes.eq("0").sum()
)

clean_none_count = int(
    clean_skidding_labels.eq("None").sum()
)

clean_skidding_blank_count = int(
    clean_skidding_labels.eq("").sum()
)

add_check(
    check_name="Vehicles: code 0 được map thành None",
    passed=(
        raw_code_zero_count == clean_none_count
        and raw_code_zero_count > 0
    ),
    actual=f"Raw 0={raw_code_zero_count:,}; Clean None={clean_none_count:,}",
    expected="Hai số bằng nhau và lớn hơn 0",
    note="None là nhãn nghiệp vụ hợp lệ, không phải missing.",
)

add_check(
    check_name="Vehicles: skidding không còn ô trống",
    passed=clean_skidding_blank_count == 0,
    actual=clean_skidding_blank_count,
    expected=0,
)


# 8.2 area_type không còn Unallocated.
area_type_normalized = (
    df_col["area_type"]
    .str.strip()
    .str.casefold()
)

unallocated_count = int(
    area_type_normalized.eq("unallocated").sum()
)

unknown_area_count = int(
    area_type_normalized.eq("unknown").sum()
)

add_check(
    check_name="Collisions: area_type không còn Unallocated",
    passed=unallocated_count == 0,
    actual=unallocated_count,
    expected=0,
    note=f"Số dòng area_type=Unknown: {unknown_area_count:,}",
)


# 8.3 Severity chỉ chứa các nhãn hợp lệ.
allowed_severity = {
    "Fatal",
    "Serious",
    "Slight",
    "Unknown",
}

for dataset_name, severity_series in [
    ("Collisions", df_col["collision_severity"]),
    ("Casualties", df_cas["casualty_severity"]),
]:
    observed = set(
        severity_series
        .astype("string")
        .str.strip()
        .unique()
    )

    unexpected = sorted(observed - allowed_severity)

    add_check(
        check_name=f"{dataset_name}: nhãn severity hợp lệ",
        passed=len(unexpected) == 0,
        actual=unexpected if unexpected else "No unexpected labels",
        expected=sorted(allowed_severity),
    )


# 8.4 Thống kê bất nhất ngữ nghĩa đã có sẵn trong dữ liệu nguồn.
#
# Không dùng điều kiện này để làm validation FAIL. Trong STATS19 có 22 bản ghi
# được gán casualty_class là Driver/Passenger nhưng vẫn mang pedestrian context.
# Đây là bất nhất nghiệp vụ của nguồn, không phải lỗi do quá trình transform.
confirmed_non_pedestrian_mask = (
    df_cas["casualty_class"]
    .str.strip()
    .str.casefold()
    .isin(["driver or rider", "passenger"])
)

source_pedestrian_context_anomaly_count = int(
    (
        confirmed_non_pedestrian_mask
        & (
            df_cas["pedestrian_location"]
            .str.strip()
            .str.casefold()
            .ne("not a pedestrian")
            |
            df_cas["pedestrian_movement"]
            .str.strip()
            .str.casefold()
            .ne("not a pedestrian")
        )
    ).sum()
)


# ============================================================
# 9. QUAN HỆ GIỮA BA FILE
# ============================================================

collision_ids = set(df_col["collision_id"])

vehicle_orphan_collision_count = int(
    (~df_veh["collision_id"].isin(collision_ids)).sum()
)

casualty_orphan_collision_count = int(
    (~df_cas["collision_id"].isin(collision_ids)).sum()
)

add_check(
    check_name="Vehicles → Collisions: không có orphan",
    passed=vehicle_orphan_collision_count == 0,
    actual=vehicle_orphan_collision_count,
    expected=0,
)

add_check(
    check_name="Casualties → Collisions: không có orphan",
    passed=casualty_orphan_collision_count == 0,
    actual=casualty_orphan_collision_count,
    expected=0,
)


vehicle_keys = pd.MultiIndex.from_frame(
    df_veh[
        [
            "collision_id",
            "vehicle_reference",
        ]
    ]
)

casualty_vehicle_keys = pd.MultiIndex.from_frame(
    df_cas[
        [
            "collision_id",
            "vehicle_reference",
        ]
    ]
)

casualty_orphan_vehicle_count = int(
    (~casualty_vehicle_keys.isin(vehicle_keys)).sum()
)

add_check(
    check_name="Casualties → Vehicles: không có orphan",
    passed=casualty_orphan_vehicle_count == 0,
    actual=casualty_orphan_vehicle_count,
    expected=0,
)


# ============================================================
# 10. PHẠM VI VEHICLE CỦA FACTCASUALTY
# ============================================================

fact_vehicle_pair_count = int(
    df_cas[
        [
            "collision_id",
            "vehicle_reference",
        ]
    ]
    .drop_duplicates()
    .shape[0]
)

vehicles_outside_fact_count = (
    len(df_veh)
    - fact_vehicle_pair_count
)

add_check(
    check_name="FactCasualty: số vehicle được tham chiếu",
    passed=(
        fact_vehicle_pair_count
        == EXPECTED_FACT_VEHICLE_PAIRS
    ),
    actual=f"{fact_vehicle_pair_count:,}",
    expected=f"{EXPECTED_FACT_VEHICLE_PAIRS:,}",
)

add_check(
    check_name="Vehicles ngoài phạm vi FactCasualty",
    passed=(
        vehicles_outside_fact_count
        == EXPECTED_VEHICLES_OUTSIDE_FACT
    ),
    actual=f"{vehicles_outside_fact_count:,}",
    expected=f"{EXPECTED_VEHICLES_OUTSIDE_FACT:,}",
)


# ============================================================
# 11. KẾT QUẢ CUỐI
# ============================================================

result_df = pd.DataFrame(validation_results)

print("\n" + "=" * 80)
print("VALIDATION RESULT")
print("=" * 80)

print(
    result_df.to_string(
        index=False,
        max_colwidth=70,
    )
)

passed_count = int(
    result_df["Status"].eq("PASS").sum()
)

failed_count = int(
    result_df["Status"].eq("FAIL").sum()
)

print("\nVALIDATION SUMMARY")
print(f"Total checks: {len(result_df)}")
print(f"Passed      : {passed_count}")
print(f"Failed      : {failed_count}")

print("\nSEMANTIC SUMMARY")
print(f"Raw skidding code 0      : {raw_code_zero_count:,}")
print(f"Clean skidding label None: {clean_none_count:,}")
print(f"Clean area_type Unknown  : {unknown_area_count:,}")
print(f"Fact-linked vehicles     : {fact_vehicle_pair_count:,}")
print(f"Vehicles outside Fact    : {vehicles_outside_fact_count:,}")
print(
    "Source pedestrian-context anomalies: "
    f"{source_pedestrian_context_anomaly_count:,}"
)
print(
    "  (Thông tin nguồn được bảo toàn; không tính là lỗi transform.)"
)


if failed_count > 0:
    print(
        "\nVALIDATION FAILED. "
        "Chưa sử dụng ba file Clean cho notebook hoặc SSIS."
    )
    sys.exit(1)


print(
    "\nTẤT CẢ KIỂM TRA ĐỀU PASS. "
    "Ba file Clean có thể được sử dụng cho notebook và SSIS."
)
