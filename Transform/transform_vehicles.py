from pathlib import Path

import pandas as pd



# 1. CẤU HÌNH ĐƯỜNG DẪN

# File này được đặt tại:
# D:\OLAP\Transform\transform_vehicles.py
#
# Khi đó PROJECT_ROOT sẽ là:
# D:\OLAP

PROJECT_ROOT = Path(__file__).resolve().parent.parent

INPUT_PATH = (
    PROJECT_ROOT
    / "Data"
    / "Raw"
    / "vehicles_2021_2025.csv"
)

DATA_GUIDE_PATH = (
    PROJECT_ROOT
    / "Data"
    / "Reference"
    / "data_guide.csv"
)

OUTPUT_PATH = (
    PROJECT_ROOT
    / "Data"
    / "Processed"
    / "vehicles_clean.csv"
)


# Các cột cần đọc từ file nguồn.
#
# vehicle_manoeuvre_historic là cột hỗ trợ:
# dùng để hợp nhất với vehicle_manoeuvre,
# nhưng không xuất hiện trong file clean.
SOURCE_COLUMNS = [
    "collision_index",
    "vehicle_reference",
    "vehicle_type",
    "vehicle_manoeuvre_historic",
    "vehicle_manoeuvre",
    "age_band_of_driver",
    "sex_of_driver",
    "skidding_and_overturning",
    "vehicle_leaving_carriageway",
]


# Thứ tự chính thức của 8 cột đầu ra.
OUTPUT_COLUMNS = [
    "collision_id",
    "vehicle_reference",
    "vehicle_type",
    "vehicle_manoeuvre",
    "driver_age_band",
    "driver_sex",
    "skidding_and_overturning",
    "vehicle_leaving_carriageway",
]


# Khóa tự nhiên của Vehicles.
NATURAL_KEY = [
    "collision_id",
    "vehicle_reference",
]


# Các nhãn được xem là dữ liệu thiếu hoặc không xác định.
#
# Nếu nhãn chứa một trong các cụm dưới đây,
# giá trị đầu ra sẽ được chuẩn hóa thành "Unknown".
UNKNOWN_LABEL_PATTERNS = [
    "unknown",
    "not known",
    "not reported",
    "not applicable",
    "data missing",
    "out of range",
    "undefined",
]



# 2. CÁC HÀM HỖ TRỢ


def normalize_column_name(column_name):
    """
    Chuẩn hóa tên cột của Data Guide.

    Ví dụ:
    field_name  -> field name
    Field Name  -> field name
    """
    return (
        str(column_name)
        .strip()
        .lower()
        .replace("_", " ")
    )


def normalize_code_series(series):
    """
    Chuẩn hóa mã trước khi tra Data Guide.

    Ví dụ:
    " 1 "  -> "1"
    "1.0"  -> "1"
    ""     -> pd.NA

    Mã vẫn được giữ dưới dạng chuỗi để việc tra cứu
    không làm mất ký tự hoặc thay đổi giá trị.
    """
    result = series.astype("string").str.strip()

    result = result.replace("", pd.NA)

    # Một số công cụ có thể đọc mã nguyên thành dạng 1.0.
    decimal_integer_mask = result.str.match(
        r"^-?\d+\.0+$",
        na=False,
    )

    result.loc[decimal_integer_mask] = (
        result.loc[decimal_integer_mask]
        .str.replace(r"\.0+$", "", regex=True)
    )

    return result


def normalize_text_series(series):
    """
    Chuẩn hóa chuỗi:

    - Bỏ khoảng trắng ở đầu và cuối.
    - Gộp nhiều khoảng trắng liên tiếp thành một.
    - Chuỗi rỗng được xem là thiếu.
    """
    result = series.astype("string")

    result = result.str.strip()

    result = result.str.replace(
        r"\s+",
        " ",
        regex=True,
    )

    result = result.replace("", pd.NA)

    return result


def standardize_unknown_labels(series):
    """
    Chuẩn hóa các nhãn thiếu hoặc không xác định
    thành một giá trị duy nhất là "Unknown".
    """
    result = normalize_text_series(series)

    lower_result = result.str.lower()

    unknown_mask = result.isna()

    for pattern in UNKNOWN_LABEL_PATTERNS:
        unknown_mask = (
            unknown_mask
            | lower_result.str.contains(
                pattern,
                regex=False,
                na=False,
            )
        )

    result = result.mask(
        unknown_mask,
        "Unknown",
    )

    return result.astype("string")


def read_data_guide():
    """
    Đọc Data Guide.

    sep=None và engine="python" cho phép pandas
    tự nhận diện dấu phân cách, ví dụ dấu chấm phẩy.
    """
    if not DATA_GUIDE_PATH.exists():
        raise FileNotFoundError(
            f"Không tìm thấy Data Guide: {DATA_GUIDE_PATH}"
        )

    guide = pd.read_csv(
        DATA_GUIDE_PATH,
        sep=None,
        engine="python",
        dtype="string",
        encoding="utf-8-sig",
        keep_default_na=False,
    )
    
    guide.columns = [
        normalize_column_name(column)
        for column in guide.columns
    ]

    required_columns = {
        "table",
        "field name",
        "code/format",
        "label",
    }

    missing_columns = (
        required_columns
        - set(guide.columns)
    )

    if missing_columns:
        raise ValueError(
            "Data Guide thiếu các cột bắt buộc: "
            f"{sorted(missing_columns)}"
        )

    guide["table"] = (
        guide["table"]
        .astype("string")
        .str.strip()
        .str.lower()
    )

    guide["field name"] = (
        guide["field name"]
        .astype("string")
        .str.strip()
        .str.lower()
    )

    guide["code/format"] = normalize_code_series(
        guide["code/format"]
    )

    guide["label"] = normalize_text_series(
        guide["label"]
    )

    return guide


def get_lookup(guide, table_name, field_name):
    """
    Lấy dictionary ánh xạ cho một field cụ thể.

    Khóa lookup gồm:
    table + field name + code

    Ví dụ:
    vehicle + vehicle_type + 9 -> Car
    """
    table_name = table_name.strip().lower()
    field_name = field_name.strip().lower()

    rows = guide.loc[
        (guide["table"] == table_name)
        & (guide["field name"] == field_name),
        [
            "code/format",
            "label",
        ],
    ].copy()

    rows = rows.dropna(
        subset=[
            "code/format",
            "label",
        ]
    )

    rows = rows.drop_duplicates(
        subset=["code/format"],
        keep="last",
    )

    if rows.empty:
        raise KeyError(
            "Không tìm thấy lookup trong Data Guide cho "
            f"{table_name}.{field_name}"
        )

    return dict(
        zip(
            rows["code/format"],
            rows["label"],
        )
    )


def map_category(
    source_series,
    guide,
    field_name,
):
    """
    Thay mã của một thuộc tính phân loại bằng nhãn
    tương ứng trong Data Guide.

    Mã không tìm thấy trong Data Guide sẽ được chuyển
    thành Unknown và được đếm để hiển thị cảnh báo.
    """
    source_codes = normalize_code_series(
        source_series
    )

    lookup = get_lookup(
        guide=guide,
        table_name="vehicle",
        field_name=field_name,
    )

    mapped = source_codes.map(lookup)

    mapped = mapped.astype("string")

    unmapped_mask = (
        source_codes.notna()
        & mapped.isna()
    )

    unmapped_count = int(
        unmapped_mask.sum()
    )

    mapped = standardize_unknown_labels(
        mapped
    )

    return mapped, unmapped_count


def combine_historic_and_current(
    historic_labels,
    current_labels,
):
    """
    Hợp nhất field Historic và Current thành một field chuẩn.

    Quy tắc:
    1. Ưu tiên giá trị Current nếu Current hợp lệ.
    2. Nếu Current là Unknown thì dùng Historic.
    3. Nếu cả hai đều Unknown thì kết quả là Unknown.
    4. Nếu cả hai hợp lệ nhưng khác nhau thì vẫn ưu tiên Current.
    """
    historic_labels = standardize_unknown_labels(
        historic_labels
    )

    current_labels = standardize_unknown_labels(
        current_labels
    )

    historic_valid = (
        historic_labels.notna()
        & historic_labels.ne("Unknown")
    )

    current_valid = (
        current_labels.notna()
        & current_labels.ne("Unknown")
    )

    # Đếm số dòng mà Current không có dữ liệu,
    # nhưng Historic có thể bổ sung.
    historic_used_mask = (
        ~current_valid
        & historic_valid
    )

    # Đếm số dòng mà cả hai đều hợp lệ nhưng khác nhãn.
    # Theo quy tắc đã chốt, Current được ưu tiên.
    conflict_mask = (
        current_valid
        & historic_valid
        & (
            current_labels.str.casefold()
            != historic_labels.str.casefold()
        )
    )

    combined = current_labels.where(
        current_valid,
        historic_labels,
    )

    combined = combined.fillna("Unknown")

    statistics = {
        "historic_used": int(
            historic_used_mask.sum()
        ),
        "current_historic_conflicts": int(
            conflict_mask.sum()
        ),
    }

    return combined.astype("string"), statistics


def check_required_columns(csv_path):
    """
    Kiểm tra file nguồn có đủ các cột cần thiết
    trước khi đọc toàn bộ dữ liệu.
    """
    if not csv_path.exists():
        raise FileNotFoundError(
            f"Không tìm thấy file nguồn: {csv_path}"
        )

    header = pd.read_csv(
        csv_path,
        nrows=0,
        encoding="utf-8-sig",
    )

    missing_columns = (
        set(SOURCE_COLUMNS)
        - set(header.columns)
    )

    if missing_columns:
        raise ValueError(
            "File Vehicles thiếu các cột bắt buộc: "
            f"{sorted(missing_columns)}"
        )



# 3. QUY TRÌNH TRANSFORM VEHICLES


def main():
    print(f"Đang đọc: {INPUT_PATH}")

    check_required_columns(INPUT_PATH)

    # Đọc các cột cần thiết dưới dạng string trước.
    #
    # Điều này giúp bảo toàn collision_index và các mã
    # trước khi chuyển kiểu hoặc ánh xạ.
    source = pd.read_csv(
        INPUT_PATH,
        usecols=SOURCE_COLUMNS,
        dtype="string",
        encoding="utf-8-sig",
        low_memory=False,
    )

    input_rows = len(source)

    print(f"Số dòng đầu vào: {input_rows:,}")
    print(
        "Số cột nguồn được đọc: "
        f"{len(SOURCE_COLUMNS)}"
    )

    # Đọc từ điển dữ liệu.
    guide = read_data_guide()

    
    # 3.1. Xử lý khóa
    

    collision_id = normalize_text_series(
        source["collision_index"]
    )

    vehicle_reference = pd.to_numeric(
        source["vehicle_reference"],
        errors="coerce",
    ).astype("Int64")

    
    # 3.2. Ánh xạ các trường phân loại
    

    unmapped_counts = {}

    vehicle_type, unmapped_counts["vehicle_type"] = (
        map_category(
            source["vehicle_type"],
            guide,
            "vehicle_type",
        )
    )

    manoeuvre_historic, unmapped_counts[
        "vehicle_manoeuvre_historic"
    ] = map_category(
        source["vehicle_manoeuvre_historic"],
        guide,
        "vehicle_manoeuvre_historic",
    )

    manoeuvre_current, unmapped_counts[
        "vehicle_manoeuvre"
    ] = map_category(
        source["vehicle_manoeuvre"],
        guide,
        "vehicle_manoeuvre",
    )

    vehicle_manoeuvre, manoeuvre_statistics = (
        combine_historic_and_current(
            historic_labels=manoeuvre_historic,
            current_labels=manoeuvre_current,
        )
    )

    driver_age_band, unmapped_counts[
        "age_band_of_driver"
    ] = map_category(
        source["age_band_of_driver"],
        guide,
        "age_band_of_driver",
    )

    driver_sex, unmapped_counts[
        "sex_of_driver"
    ] = map_category(
        source["sex_of_driver"],
        guide,
        "sex_of_driver",
    )

    skidding_and_overturning, unmapped_counts[
        "skidding_and_overturning"
    ] = map_category(
        source["skidding_and_overturning"],
        guide,
        "skidding_and_overturning",
    )

    vehicle_leaving_carriageway, unmapped_counts[
        "vehicle_leaving_carriageway"
    ] = map_category(
        source["vehicle_leaving_carriageway"],
        guide,
        "vehicle_leaving_carriageway",
    )

    
    # 3.3. Tạo DataFrame đầu ra
    

    output = pd.DataFrame(
        {
            "collision_id": collision_id,
            "vehicle_reference": vehicle_reference,
            "vehicle_type": vehicle_type,
            "vehicle_manoeuvre": vehicle_manoeuvre,
            "driver_age_band": driver_age_band,
            "driver_sex": driver_sex,
            "skidding_and_overturning":
                skidding_and_overturning,
            "vehicle_leaving_carriageway":
                vehicle_leaving_carriageway,
        }
    )

    # Đảm bảo đúng thứ tự 8 cột đã chốt.
    output = output[OUTPUT_COLUMNS]

    
    # 3.4. Kiểm tra khóa tự nhiên
    

    missing_key_mask = (
        output[NATURAL_KEY]
        .isna()
        .any(axis=1)
    )

    missing_key_count = int(
        missing_key_mask.sum()
    )

    if missing_key_count > 0:
        raise ValueError(
            "Phát hiện "
            f"{missing_key_count:,} dòng thiếu khóa tự nhiên "
            "(collision_id hoặc vehicle_reference)."
        )

    
    # 3.5. Drop duplicate theo khóa tự nhiên
    

    duplicate_mask = output.duplicated(
        subset=NATURAL_KEY,
        keep="first",
    )

    duplicate_count = int(
        duplicate_mask.sum()
    )

    output = output.drop_duplicates(
        subset=NATURAL_KEY,
        keep="first",
    ).copy()

    
    # 3.6. Xuất CSV
    

    OUTPUT_PATH.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    output.to_csv(
        OUTPUT_PATH,
        index=False,
        encoding="utf-8-sig",
        na_rep="",
        lineterminator="\n",
    )


    print()
    print("TRANSFORM VEHICLES HOÀN THÀNH")
    print(f"Input rows       : {input_rows:,}")
    print(f"Duplicates removed: {duplicate_count:,}")
    print(f"Output rows      : {len(output):,}")
    print(f"Output columns   : {len(output.columns)}")
    print(f"Output file      : {OUTPUT_PATH}")

    print()
    print("HISTORIC/CURRENT MERGE")
    print(
        "Rows using historic vehicle_manoeuvre: "
        f"{manoeuvre_statistics['historic_used']:,}"
    )
    print(
        "Rows where current and historic differ: "
        f"{manoeuvre_statistics['current_historic_conflicts']:,}"
    )

    total_unmapped = sum(
        unmapped_counts.values()
    )

    print()
    print("DATA GUIDE MAPPING")

    if total_unmapped == 0:
        print("Không phát hiện mã chưa được ánh xạ.")
    else:
        print(
            "Các mã không tìm thấy trong Data Guide "
            "đã được chuyển thành Unknown:"
        )

        for field_name, count in unmapped_counts.items():
            if count > 0:
                print(
                    f"  {field_name}: {count:,}"
                )


if __name__ == "__main__":
    main()