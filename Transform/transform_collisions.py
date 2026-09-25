from datetime import datetime
from pathlib import Path

import pandas as pd


# 1. CẤU HÌNH

PROJECT_ROOT = Path(__file__).resolve().parent.parent

INPUT_PATH = (
    PROJECT_ROOT
    / "Data"
    / "Raw"
    / "collisions_2021_2025.csv"
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
    / "collisions_clean.csv"
)


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


NATURAL_KEY = [
    "collision_id",
]


VALID_YEARS = {
    2021,
    2022,
    2023,
    2024,
    2025,
}


UNKNOWN_LABEL_PATTERNS = [
    "unknown",
    "not known",
    "not reported",
    "not applicable",
    "data missing",
    "out of range",
    "undefined",
    "unallocated",
]


# 2. HÀM HỖ TRỢ

def normalize_column_name(value):
    """Chuẩn hóa tên cột trong Data Guide."""
    return (
        str(value)
        .strip()
        .lower()
        .replace("_", " ")
    )


def normalize_code_series(series):
    """
    Chuẩn hóa mã trước khi lookup.

    Ví dụ:
    " 1 " -> "1"
    "1.0" -> "1"
    ""    -> pd.NA
    """
    result = (
        series
        .astype("string")
        .str.strip()
        .replace("", pd.NA)
    )

    integer_decimal_mask = result.str.match(
        r"^-?\d+\.0+$",
        na=False,
    )

    result.loc[integer_decimal_mask] = (
        result.loc[integer_decimal_mask]
        .str.replace(
            r"\.0+$",
            "",
            regex=True,
        )
    )

    return result


def normalize_text_series(series):
    """
    Chuẩn hóa chuỗi:

    - Xóa khoảng trắng đầu/cuối.
    - Gộp nhiều khoảng trắng.
    - Chuỗi rỗng thành pd.NA.
    """
    return (
        series
        .astype("string")
        .str.strip()
        .str.replace(
            r"\s+",
            " ",
            regex=True,
        )
        .replace("", pd.NA)
    )


def standardize_unknown_labels(series):
    """
    Chuẩn hóa các nhãn thiếu hoặc không xác định
    thành nhãn thống nhất: Unknown.
    """
    result = normalize_text_series(series)

    lowered = result.str.lower()

    unknown_mask = result.isna()

    for pattern in UNKNOWN_LABEL_PATTERNS:
        unknown_mask = (
            unknown_mask
            | lowered.str.contains(
                pattern,
                regex=False,
                na=False,
            )
        )

    return (
        result
        .mask(unknown_mask, "Unknown")
        .astype("string")
    )


def read_data_guide():
    """Đọc Data Guide chính thức."""

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
            "Data Guide thiếu cột bắt buộc: "
            f"{sorted(missing_columns)}"
        )

    guide["table"] = (
        guide["table"]
        .str.strip()
        .str.lower()
    )

    guide["field name"] = (
        guide["field name"]
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


def get_lookup(guide, field_name):
    """Lấy dictionary mã → nhãn của một trường Collision."""

    rows = guide.loc[
        (
            guide["table"].eq("collision")
            & guide["field name"].eq(field_name.lower())
        ),
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
            "Không tìm thấy lookup cho "
            f"collision.{field_name}"
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
    """Thay mã phân loại bằng nhãn trong Data Guide."""

    source_codes = normalize_code_series(
        source_series
    )

    lookup = get_lookup(
        guide,
        field_name,
    )

    mapped = (
        source_codes
        .map(lookup)
        .astype("string")
    )

    unmapped_count = int(
        (
            source_codes.notna()
            & mapped.isna()
        ).sum()
    )

    mapped = standardize_unknown_labels(
        mapped
    )

    return mapped, unmapped_count


def to_nullable_integer(series):
    """Chuyển sang số nguyên nullable Int64."""
    return pd.to_numeric(
        series,
        errors="coerce",
    ).astype("Int64")


def to_nullable_float(
    series,
    minimum,
    maximum,
):
    """
    Chuyển sang số thực.

    Giá trị không chuyển được hoặc ngoài miền
    được chuyển thành ô trống.
    """
    result = pd.to_numeric(
        series,
        errors="coerce",
    )

    return result.where(
        result.between(
            minimum,
            maximum,
            inclusive="both",
        ),
        pd.NA,
    )


def parse_date(value):
    """
    Chuẩn hóa ngày thành YYYY-MM-DD.

    Không chuyển được -> pd.NA.
    """
    if pd.isna(value):
        return pd.NA

    text = str(value).strip()

    if text == "":
        return pd.NA

    formats = [
        "%d/%m/%Y",
        "%Y-%m-%d",
        "%m/%d/%Y",
    ]

    for date_format in formats:
        try:
            return datetime.strptime(
                text,
                date_format,
            ).strftime("%Y-%m-%d")

        except ValueError:
            continue

    return pd.NA


def parse_time(value):
    """
    Chuẩn hóa thời gian thành HH:MM:SS.

    Không chuyển được -> pd.NA.
    """
    if pd.isna(value):
        return pd.NA

    text = str(value).strip()

    if text == "":
        return pd.NA

    formats = [
        "%H:%M",
        "%H:%M:%S",
    ]

    for time_format in formats:
        try:
            return datetime.strptime(
                text,
                time_format,
            ).strftime("%H:%M:%S")

        except ValueError:
            continue

    return pd.NA


def check_required_columns():
    """Kiểm tra file Raw có đủ cột cần thiết."""

    if not INPUT_PATH.exists():
        raise FileNotFoundError(
            f"Không tìm thấy file nguồn: {INPUT_PATH}"
        )

    header = pd.read_csv(
        INPUT_PATH,
        nrows=0,
        encoding="utf-8-sig",
    )

    missing_columns = (
        set(SOURCE_COLUMNS)
        - set(header.columns)
    )

    if missing_columns:
        raise ValueError(
            "File Collisions thiếu cột: "
            f"{sorted(missing_columns)}"
        )


# 3. TRANSFORM

def main():
    print(f"Đang đọc: {INPUT_PATH}")

    check_required_columns()

    source = pd.read_csv(
        INPUT_PATH,
        usecols=SOURCE_COLUMNS,
        dtype="string",
        encoding="utf-8-sig",
        low_memory=False,
    )

    guide = read_data_guide()

    input_rows = len(source)

    print(f"Số dòng đầu vào: {input_rows:,}")
    print(
        "Số cột nguồn được đọc: "
        f"{len(SOURCE_COLUMNS)}"
    )

    # --------------------------------------------------------
    # Khóa, ngày, giờ và số
    # --------------------------------------------------------

    collision_id = normalize_text_series(
        source["collision_index"]
    )

    collision_year = to_nullable_integer(
        source["collision_year"]
    )

    collision_date = source["date"].apply(
        parse_date
    )

    collision_time = source["time"].apply(
        parse_time
    )

    longitude = to_nullable_float(
        source["longitude"],
        minimum=-8.65,
        maximum=1.78,
    )

    latitude = to_nullable_float(
        source["latitude"],
        minimum=49.9,
        maximum=60.9,
    )

    local_authority = normalize_text_series(
        source["local_authority_ons_district"]
    )

    local_authority = (
        local_authority
        .replace("-1", pd.NA)
        .fillna("Unknown")
    )

    speed_limit = to_nullable_integer(
        source["speed_limit"]
    )

    speed_limit = speed_limit.where(
        speed_limit.between(
            1,
            80,
            inclusive="both",
        ),
        pd.NA,
    )

    # --------------------------------------------------------
    # Mapping mã thành nhãn
    # --------------------------------------------------------

    unmapped_counts = {}

    def mapped(source_column):
        result, count = map_category(
            source[source_column],
            guide,
            source_column,
        )

        unmapped_counts[source_column] = count

        return result

    # Các cột hiện hành đã được DfT thu thập theo
    # hoặc quy đổi sang đặc tả STATS19 2024.
    #
    # Vì vậy không ghép thêm các cột _historic.

    output = pd.DataFrame(
        {
            "collision_id":
                collision_id,

            "collision_year":
                collision_year,

            "collision_date":
                collision_date,

            "collision_time":
                collision_time,

            "longitude":
                longitude,

            "latitude":
                latitude,

            "local_authority_district_code":
                local_authority,

            "collision_severity":
                mapped("collision_severity"),

            "first_road_class":
                mapped("first_road_class"),

            "road_type":
                mapped("road_type"),

            "speed_limit_mph":
                speed_limit,

            "junction_detail":
                mapped("junction_detail"),

            "junction_control":
                mapped("junction_control"),

            "pedestrian_crossing":
                mapped("pedestrian_crossing"),

            "light_conditions":
                mapped("light_conditions"),

            "weather_conditions":
                mapped("weather_conditions"),

            "road_surface_conditions":
                mapped("road_surface_conditions"),

            "area_type":
                mapped("urban_or_rural_area"),
        }
    )

    output = output[OUTPUT_COLUMNS]

    # --------------------------------------------------------
    # Kiểm tra khóa
    # --------------------------------------------------------

    missing_key_count = int(
        output[NATURAL_KEY]
        .isna()
        .any(axis=1)
        .sum()
    )

    if missing_key_count > 0:
        raise ValueError(
            f"Có {missing_key_count:,} dòng thiếu collision_id."
        )

    # --------------------------------------------------------
    # Chỉ giữ dữ liệu 2021-2025
    # --------------------------------------------------------

    bad_year_mask = (
        ~output["collision_year"]
        .isin(VALID_YEARS)
    )

    bad_year_count = int(
        bad_year_mask.sum()
    )

    output = output.loc[
        ~bad_year_mask
    ].copy()

    # --------------------------------------------------------
    # Drop duplicate theo natural key
    # --------------------------------------------------------

    duplicate_count = int(
        output.duplicated(
            subset=NATURAL_KEY,
            keep="first",
        ).sum()
    )

    output = output.drop_duplicates(
        subset=NATURAL_KEY,
        keep="first",
    ).copy()

    # --------------------------------------------------------
    # Xuất CSV
    # --------------------------------------------------------

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

    # --------------------------------------------------------
    # Kết quả
    # --------------------------------------------------------

    print()
    print("TRANSFORM COLLISIONS HOÀN THÀNH")
    print(f"Input rows        : {input_rows:,}")
    print(f"Bad year removed  : {bad_year_count:,}")
    print(f"Duplicates removed: {duplicate_count:,}")
    print(f"Output rows       : {len(output):,}")
    print(f"Output columns    : {len(output.columns)}")
    print(f"Output file       : {OUTPUT_PATH}")

    print()
    print("DATA GUIDE MAPPING")

    if sum(unmapped_counts.values()) == 0:
        print("Không phát hiện mã chưa được ánh xạ.")

    else:
        for field_name, count in unmapped_counts.items():
            if count > 0:
                print(
                    f"  {field_name}: "
                    f"{count:,} mã chưa ánh xạ → Unknown"
                )


if __name__ == "__main__":
    main()