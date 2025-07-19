import argparse
import re
from pathlib import Path
import pandas as pd
import plotly.express as px

RX = re.compile(r"^avg_(.+?)_(LOW|MID|HIGH|ULTRA).*\.csv$", re.I)
STAGE_METRICS = ["volume", "shadow", "sdf"]
TIME_METRIC = "gpu_ms"
SAMPLE_METRICS = ["spp", "hit_ratio"]
PRESET_ORDER = ["LOW", "MID", "HIGH", "ULTRA"]
DISTANCE_COLOR_MAP = {60: "red", 120: "blue"}
DISTANCE_STR_COLOR_MAP = {f"{d} Einheiten": c for d, c in DISTANCE_COLOR_MAP.items()}

MODEL_DISPLAY_MAPPING = {
    "beer_lambert": "Beer Lambert",
    "mos": "Multiple Octave Scattering",
    "powder": "Powder",
    "single_scattering": "Henyey Greenstein",
}

IMAGE_WIDTH, IMAGE_HEIGHT = 1600, 900


def quality_suffix(df: pd.DataFrame) -> str:
    presets = sorted(df["preset"].unique().tolist(), key=PRESET_ORDER.index)
    return f"_{presets[0]}" if len(presets) == 1 else ""


def save_fig(fig, outpath_base: Path):
    fig.update_layout(width=IMAGE_WIDTH, height=IMAGE_HEIGHT)
    fig.write_image(outpath_base.with_suffix(".png"))
    print(f"Erzeugt: {outpath_base.with_suffix('.png')}")


def read_csv(fp: Path) -> pd.DataFrame:
    try:
        distance = int(fp.parent.parent.name.split("=", 1)[1])
    except Exception:
        raise ValueError(f"Kann Entfernung nicht parsen aus Ordner: {fp.parent.parent.name}")
    m = RX.match(fp.name)
    if not m:
        raise ValueError(f"Ungültiger Dateiname: {fp}")
    model_raw, preset = m.group(1), m.group(2).upper()

    total_time = None
    for line in fp.open():
        if line.startswith("#Total Rendering Time"):
            try:
                total_time = float(line.split(":", 1)[1].strip())
            except Exception:
                total_time = None
            break

    df = pd.read_csv(fp, comment="#")
    df["model"] = model_raw
    df["preset"] = preset
    df["distance"] = distance
    df["total_time"] = total_time
    return df


def load_tidy(base: Path, latest_only=False) -> pd.DataFrame:
    all_csvs = list(base.rglob("avg_*_*.csv"))
    if latest_only and all_csvs:
        all_csvs = [max(all_csvs, key=lambda f: f.stat().st_mtime)]

    frames = []
    for p in all_csvs:
        try:
            frames.append(read_csv(p))
        except Exception as e:
            print(f"Warnung: überspringe {p}: {e}")
    if not frames:
        raise RuntimeError("Keine gültigen avg_*.csv-Dateien gefunden.")
    df = pd.concat(frames, ignore_index=True)
    df["model_lc"] = df["model"].str.lower()
    df["model_display"] = df["model_lc"].map(MODEL_DISPLAY_MAPPING).fillna(df["model"])
    df.drop(columns=["model_lc"], inplace=True)
    df["distance_units"] = df["distance"].astype(str) + " Einheiten"
    df["distance_str"] = df["distance_units"]
    return df


def sampling_efficiency(df: pd.DataFrame, outdir: Path, model: str = None) -> None:
    sub = df[df.metric.isin(SAMPLE_METRICS)]
    if model:
        sub = sub[sub.model == model]
    if not all(m in sub.metric.unique() for m in SAMPLE_METRICS):
        print("Überspringe Effizienz-Streuung – fehlende 'spp' oder 'hit_ratio'")
        return

    pivot = (
        sub.pivot_table(
            index=["model", "model_display", "preset", "distance"],
            columns="metric", values="mean"
        ).reset_index().dropna(subset=SAMPLE_METRICS)
    )
    if pivot.empty:
        print("Überspringe Effizienz-Streuung – keine Daten")
        return

    fig = px.scatter(
        pivot,
        x="spp", y="hit_ratio", color="preset",
        symbol=(None if model else "model_display"),
        size="distance", size_max=16,
        category_orders={"preset": PRESET_ORDER},
        labels={
            "spp": "Abtastungen pro Pixel",
            "hit_ratio": "Trefferrate",
            "preset": "Qualitätsstufe",
            "distance": "Entfernung (Einheiten)",
            "model_display": "Modell"
        },
        title="Effizienz der Abtastung"
    )
    fig.update_xaxes(ticksuffix=" spp")
    fig.update_yaxes(ticksuffix=" ratio")

    sfx = quality_suffix(sub)
    outpath = outdir / (f"effizienz_{model}{sfx}" if model else f"effizienz{sfx}")

    save_fig(fig, outpath)


def cost_per_sample_plot(df: pd.DataFrame, outdir: Path, model: str = None) -> None:
    sub = df[df.metric.isin([TIME_METRIC, "spp"])]
    if model:
        sub = sub[sub.model == model]
    pivot = (
        sub.pivot_table(
            index=["model", "model_display", "preset", "distance"],
            columns="metric", values="mean"
        ).reset_index()
    )
    if TIME_METRIC not in pivot.columns or "spp" not in pivot.columns:
        print("Überspringe Kostenproben-Diagramm – fehlende Daten")
        return

    pivot = pivot.dropna(subset=[TIME_METRIC, "spp"])
    pivot["kosten_pro_abtastung"] = pivot[TIME_METRIC] / pivot["spp"]
    pivot["distance_str"] = pivot["distance"].astype(str) + " Einheiten"

    fig = px.bar(
        pivot,
        x="preset", y="kosten_pro_abtastung", color="distance_str",
        facet_col=(None if model else "model_display"),
        category_orders={"preset": PRESET_ORDER},
        color_discrete_map=DISTANCE_STR_COLOR_MAP,
        labels={
            "preset": "Qualitätsstufe",
            "kosten_pro_abtastung": "GPU-ms pro Abtastung",
            "distance_str": "Entfernung (Einheiten)",
            "model_display": "Modell"
        },
        barmode="group"
    )
    sfx = quality_suffix(pivot)
    outpath = outdir / (f"kosten_pro_abtastung_{model}{sfx}" if model else f"kosten_pro_abtastung{sfx}")

    save_fig(fig, outpath)


def total_time_plot(df: pd.DataFrame, outdir: Path, model: str = None) -> None:
    pivot = df[["model", "model_display", "preset", "distance", "total_time"]].drop_duplicates()
    if model:
        pivot = pivot[pivot.model == model]
    pivot = pivot.dropna(subset=["total_time"])
    if pivot.empty:
        print("Überspringe Gesamtzeit – keine Daten")
        return

    pivot["distance_str"] = pivot["distance"].astype(str) + " Einheiten"
    fig = px.bar(
        pivot,
        x="preset", y="total_time", color="distance_str",
        facet_col=(None if model else "model_display"),
        category_orders={"preset": PRESET_ORDER},
        color_discrete_map=DISTANCE_STR_COLOR_MAP,
        labels={
            "preset": "Qualitätsstufe",
            "total_time": "Gesamte Renderzeit (s)",
            "distance_str": "Entfernung (Einheiten)",
            "model_display": "Modell"
        },
        barmode="group"
    )
    sfx = quality_suffix(pivot)
    outpath = outdir / (f"gesamtzeit_{model}{sfx}" if model else f"gesamtzeit{sfx}")

    save_fig(fig, outpath)


def main():
    ap = argparse.ArgumentParser(description="Erzeuge PNG-Diagramme aus avg_*.csv")
    ap.add_argument("-b", "--base", type=Path, required=True, help="Stammordner: e.g. results/average/")
    ap.add_argument("--latest-only", action="store_true", help="Nur die neueste CSV analysieren")
    ap.add_argument("-q", "--quality", choices=PRESET_ORDER, default=None, help="Optionaler Preset-Filter")

    args = ap.parse_args()

    tidy = load_tidy(args.base, latest_only=args.latest_only)
    base_out = Path.cwd()

    for dist, df_dist in tidy.groupby("distance"):
        models = df_dist["model"].unique().tolist()
        print(f"[Info] Distance={dist}  Modelle={models}")

        if len(models) == 1:
            model = models[0]
            outdir = base_out / f"distance={dist}" / model
            outdir.mkdir(parents=True, exist_ok=True)
            sampling_efficiency(df_dist, outdir, model)
            cost_per_sample_plot(df_dist, outdir, model)
            total_time_plot(df_dist, outdir, model)
        else:
            outdir = base_out / f"distance={dist}"
            outdir.mkdir(parents=True, exist_ok=True)
            sampling_efficiency(df_dist, outdir)
            cost_per_sample_plot(df_dist, outdir)
            total_time_plot(df_dist, outdir)


if __name__ == "__main__":
    main()
