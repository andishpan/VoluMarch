# plots data depending on distance

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
    "henyey_greenstein": "Henyey Greenstein",
}

IMAGE_WIDTH, IMAGE_HEIGHT = 1600, 900


def save_fig(fig, outpath_base: Path):
    fig.update_layout(width=IMAGE_WIDTH, height=IMAGE_HEIGHT)
    fig.write_image(outpath_base.with_suffix('.png'))
    print(f"Erzeugt: {outpath_base.with_suffix('.png')}")

#extracts distance from folder name and model and preset from file name
# reads CSV into DataFrame and adds columns model, preset, distance, total_time
# raises ValueError if parsing fails
# expects folder structure: .../distance=*/avg_<model>_<preset>*.csv
# e.g. .../distance=60/avg_beer_lambert_HIGH_*.csv
# total_time is read from comment line starting with #Total Rendering Time
# if not found, total_time is None
# returns DataFrame with added columns
def read_csv(fp: Path) -> pd.DataFrame:
    try:
        distance = int(fp.parent.name.split("=", 1)[1])
    except Exception:
        raise ValueError(f"Kann Entfernung nicht parsen aus Ordner: {fp.parent.name}")
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

# loads all avg_*.csv files under base path into a tidy DataFrame
# adds model_display and distance_str columns
# fills model_display using MODEL_DISPLAY_MAPPING
# distance_str is distance + " Einheiten"
# raises RuntimeError if no CSVs found
def load_tidy(base: Path) -> pd.DataFrame:
    frames = []
    for p in base.rglob("avg_*_*.csv"):
        try:
            frames.append(read_csv(p))
        except Exception as e:
            print(f"Warnung: überspringe {p}: {e}")
    if not frames:
        raise RuntimeError(f"Keine CSVs unter {base} gefunden")
    df = pd.concat(frames, ignore_index=True)
    df["model_lc"] = df["model"].str.lower()
    df["model_display"] = df["model_lc"].map(MODEL_DISPLAY_MAPPING).fillna(df["model"])
    df.drop(columns=["model_lc"], inplace=True)
    df["distance_units"] = df["distance"].astype(str) + " Einheiten"
    df["distance_str"] = df["distance_units"]
    return df


def sampling_efficiency(df: pd.DataFrame, outdir: Path, model: str = None) -> None:
    sub = df[df.metric.isin(SAMPLE_METRICS)]# filter to relevant metrics
    if model:# filter to specific model if given
        sub = sub[sub.model == model]
    if not all(m in sub.metric.unique() for m in SAMPLE_METRICS):# check if both metrics are present
        print("Überspringe Effizienz-Streuung – fehlende 'spp' oder 'hit_ratio'")
        return
# create pivot table with mean values for each combination of model, preset, distance
    #eine Zeile pro Modell
    pivot = (
        sub.pivot_table(
            index=["model", "model_display", "preset", "distance"],
            columns="metric", values="mean"
        ).reset_index().dropna(subset=SAMPLE_METRICS)# drop rows with NaN in either metric
    )
    if pivot.empty:
        print("Überspringe Effizienz-Streuung – keine Daten")
        return
# scatter plot of hit_ratio vs spp, colored by preset, sized by distance
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

    outpath = outdir / (f"effizienz_{model}" if model else "effizienz")
    save_fig(fig, outpath)

# plots cost per sample (gpu_ms / spp) vs preset, colored by distance
# bar plot with facets for each model if no model filter
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
    outpath = outdir / (f"kosten_pro_abtastung_{model}" if model else "kosten_pro_abtastung")
    save_fig(fig, outpath)

# plots total rendering time vs preset, colored by distance
def total_time_plot(df: pd.DataFrame, outdir: Path, model: str = None) -> None:
    pivot = df[["model", "model_display", "preset", "distance", "total_time"]].drop_duplicates()
    if model:
        pivot = pivot[pivot.model == model]
    pivot = pivot.dropna(subset=["total_time"])
    if pivot.empty:
        print("Überspringe Gesamtzeit – keine Daten")
        return

    pivot["distance_str"] = pivot["distance"].astype(str) + " Einheiten"# create distance string for legend
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
    outpath = outdir / (f"gesamtzeit_{model}" if model else "gesamtzeit")
    save_fig(fig, outpath)

# plots sampling comparison for all models or a specific quality preset
# scatter plot of hit_ratio vs spp, colored by model, symbol by preset if no quality
def sampling_comparison_plot(df: pd.DataFrame, outdir: Path, quality: str = None) -> None:
    sub = df[df.metric.isin(SAMPLE_METRICS)]
    if quality:
        sub = sub[sub.preset == quality]

    pivot = (# create pivot table with mean values for each combination of model, preset, distance
        sub.pivot_table(
            index=["model", "model_display", "preset", "distance"],
            columns="metric", values="mean"
        ).reset_index().dropna(subset=SAMPLE_METRICS)
    )
    if pivot.empty:
        print("Überspringe Abtastvergleich – keine gültigen Daten")
        return

    fig = px.scatter(
        pivot,
        x="spp", y="hit_ratio",
        color="model_display",
        symbol=None if quality else "preset",
        size="distance", size_max=16,
        category_orders={"preset": PRESET_ORDER},
        labels={
            "spp": "Abtastungen pro Pixel",
            "hit_ratio": "Hit Ratio",
            "model_display": "Modell",
            "preset": "Qualitätsstufe",
            "distance": "Entfernung (Einheiten)"
        }
    )
    fig.update_xaxes(ticksuffix=" spp")
    fig.update_yaxes(ticksuffix=" ratio")
    fig.update_layout(width=IMAGE_WIDTH, height=IMAGE_HEIGHT)

    outpath = outdir / f"abtastungsvergleich{('_' + quality) if quality else ''}"
    fig.write_image(outpath.with_suffix(".png"))
    print(f"Erzeugt: {outpath.with_suffix('.png')}")


def main() -> None:
    # command line arguments
    # -b/--base : base directory with distance=* subdirs (required)
    # -m/--model : optional model filter (e.g. beer_lambert)
    # -r/--run : only run specific plot (choices: sampling_comparison)
    # -q/--quality : preset for sampling_comparison (choices: LOW, MID, HIGH, ULTRA)
    # if -r is sampling_comparison, -q is required
    # output PNGs are saved to ./plot_data_plots/
    ap = argparse.ArgumentParser(description="Erzeuge PNG-Diagramme aus avg_*.csv")
    ap.add_argument("-b", "--base", type=Path, required=True, help="Stammordner mit Unterordnern distance=*")
    ap.add_argument("-m", "--model", type=str, default=None, help="(Optional) Modellfilter z.B. 'beer_lambert'")
    ap.add_argument("-r", "--run", choices=["sampling_comparison"], default=None,
                    help="Nur Abtastungsdiagramm erzeugen")
    ap.add_argument("-q", "--quality", choices=PRESET_ORDER, default=None, help="Preset für sampling_comparison")

    args = ap.parse_args()
    tidy = load_tidy(args.base)
    outdir = Path.cwd() / "plot_data_plots"
    outdir.mkdir(parents=True, exist_ok=True)
    # can run like this : python plot_data.py -b /path/to/data -r sampling_comparison -q HIGH
# or like this : python plot_data.py -b /path/to/data -m beer_lambert
# or like this : python plot_data.py -b /path/to/data
    if args.run == "sampling_comparison":
        if not args.quality:
            print("Fehler: -q/--quality ist erforderlich bei -r sampling_comparison")
            return
        sampling_comparison_plot(tidy, outdir, quality=args.quality)
        return

    sampling_efficiency(tidy, outdir, args.model)
    cost_per_sample_plot(tidy, outdir, args.model)
    total_time_plot(tidy, outdir, args.model)
# if no model filter, also do sampling comparison for all models
    if args.quality:
        sampling_comparison_plot(tidy, outdir, quality=args.quality)
    else:
        sampling_comparison_plot(tidy, outdir)


if __name__ == "__main__":
    main()
