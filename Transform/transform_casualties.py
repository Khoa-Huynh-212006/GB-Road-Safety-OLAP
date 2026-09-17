from pathlib import Path

import pandas as pd



# 1. CẤU HÌNH ĐƯỜNG DẪN


PROJECT_ROOT = Path(__file__).resolve().parent.parent

INPUT_PATH = (
    PROJECT_ROOT
    / "Data"
    / "Raw"
    / "casualties_2021_2025.csv"
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
    / "casualties_clean.csv"
)


# 11 cột nguồn được giữ lại.
SOURCE_COLUMNS = [
    "collision_index",
    "vehicle_reference",
    "casualty_reference",
    "casualty_class",
    "sex_of_casualty",
    "age_of_casualty",
    "age_band_of_casualty",
    "casualty_severity",
    "casualty_type",
    "pedestrian_location",
    "pedestrian_movement",
]


# Thứ tự chính thức của các cột đầu ra.
OUTPUT_COLUMNS = [
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
]


# Khóa tự nhiên của Casualties.
NATURAL_KEY = [
    "collision_id",
    "casualty_reference",
]


# Những nhãn thể hiện dữ liệu thiếu hoặc không xác định.
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
    Chuẩn hóa tên cột trong Data Guide.

    Ví dụ:
    field_name -> field name
    Field Name -> field name
    """
    return (
        str(column_name)
        .strip()
        .lower()
        .replace("_", " ")
    )


def normalize_code_series(series):
    """
    Chuẩn hóa mã trước khi tra cứu Data Guide.

    Ví dụ:
    " 1 " -> "1"
    "1.0" -> "1"
    ""    -> pd.NA
    """
    result = series.astype("string").str.strip()

    result = result.replace("", pd.NA)

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
    - Gộp nhiều khoảng trắng liên tiếp.
    - Chuỗi rỗng được chuyển thành pd.NA.
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
    Chuyển các nhãn thiếu hoặc không xác định
    thành một cách biểu diễn thống nhất: Unknown.
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

    keep_default_na=False rất quan trọng:
    nó ngăn pandas tự hiểu nhãn "None"
    trong Data Guide là giá trị thiếu.
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
    Lấy dictionary ánh xạ mã sang nhãn cho một field.

    Lookup được xác định bằng:
    table + field name + code
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

    rows = rows.loc[
        rows["code/format"].ne("")
        & rows["label"].ne("")
    ]

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
    Thay mã của một thuộc tính phân loại
    bằng nhãn trong Data Guide.

    Mã không tìm thấy được chuyển thành Unknown
    và được đếm để hiển thị ở cuối chương trình.
    """
    source_codes = normalize_code_series(
        source_series
    )

    lookup = get_lookup(
        guide=guide,
        table_name="casualty",
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


def convert_nullable_integer(series):
    """
    Chuyển dữ liệu sang số nguyên có thể rỗng.

    Giá trị không chuyển được sẽ thành pd.NA.
    """
    return pd.to_numeric(
        series,
        errors="coerce",
    ).astype("Int64")


def check_required_columns(csv_path):
    """
    Kiểm tra file nguồn có đủ 11 cột đã chốt.
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
            "File Casualties thiếu các cột bắt buộc: "
            f"{sorted(missing_columns)}"
        )



# 3. QUY TRÌNH TRANSFORM CASUALTIES


def main():
    print(f"Đang đọc: {INPUT_PATH}")

    check_required_columns(INPUT_PATH)

    # Đọc tất cả cột nguồn dưới dạng chuỗi trước
    # để bảo toàn collision_index và các mã phân loại.
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

    guide = read_data_guide()

    
    # 3.1. Xử lý khóa và các trường số
    

    collision_id = normalize_text_series(
        source["collision_index"]
    )

    vehicle_reference = convert_nullable_integer(
        source["vehicle_reference"]
    )

    casualty_reference = convert_nullable_integer(
        source["casualty_reference"]
    )

    casualty_age = convert_nullable_integer(
        source["age_of_casualty"]
    )

    # age_of_casualty = -1 biểu diễn dữ liệu thiếu.
    # Vì tuổi là dữ liệu số nên chuyển thành ô trống.
    casualty_age = casualty_age.mask(
        casualty_age < 0,
        pd.NA,
    )

    
    # 3.2. Ánh xạ mã thành nhãn
    

    unmapped_counts = {}

    casualty_class, unmapped_counts[
        "casualty_class"
    ] = map_category(
        source["casualty_class"],
        guide,
        "casualty_class",
    )

    casualty_sex, unmapped_counts[
        "sex_of_casualty"
    ] = map_category(
        source["sex_of_casualty"],
        guide,
        "sex_of_casualty",
    )

    casualty_age_band, unmapped_counts[
        "age_band_of_casualty"
    ] = map_category(
        source["age_band_of_casualty"],
        guide,
        "age_band_of_casualty",
    )

    casualty_severity, unmapped_counts[
        "casualty_severity"
    ] = map_category(
        source["casualty_severity"],
        guide,
        "casualty_severity",
    )

    casualty_type, unmapped_counts[
        "casualty_type"
    ] = map_category(
        source["casualty_type"],
        guide,
        "casualty_type",
    )

    pedestrian_location, unmapped_counts[
        "pedestrian_location"
    ] = map_category(
        source["pedestrian_location"],
        guide,
        "pedestrian_location",
    )

    pedestrian_movement, unmapped_counts[
        "pedestrian_movement"
    ] = map_category(
        source["pedestrian_movement"],
        guide,
        "pedestrian_movement",
    )
    
    # 3.3. Tạo DataFrame đầu ra

    output = pd.DataFrame(
        {
            "collision_id": collision_id,
            "vehicle_reference": vehicle_reference,
            "casualty_reference": casualty_reference,
            "casualty_class": casualty_class,
            "casualty_sex": casualty_sex,
            "casualty_age": casualty_age,
            "casualty_age_band": casualty_age_band,
            "casualty_severity": casualty_severity,
            "casualty_type": casualty_type,
            "pedestrian_location": pedestrian_location,
            "pedestrian_movement": pedestrian_movement,
        }
    )

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
            "(collision_id hoặc casualty_reference)."
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

    
    # 3.7. In kết quả
    

    print()
    print("TRANSFORM CASUALTIES HOÀN THÀNH")
    print(f"Input rows        : {input_rows:,}")
    print(f"Duplicates removed: {duplicate_count:,}")
    print(f"Output rows       : {len(output):,}")
    print(f"Output columns    : {len(output.columns)}")
    print(f"Output file       : {OUTPUT_PATH}")

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