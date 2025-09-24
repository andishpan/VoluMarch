import time
import logging
import os
from pathlib import Path
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from tensorflow.keras.models import load_model
from tensorflow.keras.preprocessing.image import img_to_array
import numpy as np
from PIL import Image
#https://github.com/gorakhargosh/watchdog
# configuration
WATCH_DIR = r"C:\RT\VoluMarch\results\predictions"
PREFIXES = ("beer_lambert", "henyey_greenstein", "MOS", "powder")
MODEL_PATH = r"Cloud-Classification\ccsn_cloudNotCloud_classification_model.keras"
THRESH = 0.40

# logging setup
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] %(levelname)s: %(message)s",
    datefmt="%H:%M:%S"
)
logging.info(f"Using PREFIXES: {PREFIXES}")


# load model
logging.info(f"Loading model from {MODEL_PATH}")
model = load_model(MODEL_PATH)
logging.info("Model loaded; starting observer")


def classify_image(path: Path):
    try:
        with Image.open(path) as im:
            im = im.convert("RGB")
            im = im.resize((224, 224))
            arr = img_to_array(im) / 255.0
        x = np.expand_dims(arr, 0)
        p_not = float(model.predict(x, verbose=0)[0][0])
        p_cloud = 1 - p_not
        label = "cloud" if p_cloud >= THRESH else "notcloud"
        logging.info(f"Prediction for {path.name}: {label} (p_cloud={p_cloud:.4f})")

    except Exception as e:
        logging.error(f"Failed to process {path.name}: {e}")
        return

    try:
        os.remove(path)
        logging.info(f"Deleted image: {path.name}")
    except Exception as e:
        logging.warning(f"Could not delete {path.name}: {e}")



class ImageHandler(FileSystemEventHandler):


    def on_created(self, event):
        self._process(event)

    def on_modified(self, event):
        self._process(event)

    def _process(self, event):
        if event.is_directory:
            return

        src = Path(event.src_path)
        name_lower = src.name.lower()
        print(f"[DEBUG] Saw file: {name_lower}")

        if not any(name_lower.startswith(pref.lower()) for pref in PREFIXES):
            return

        for attempt in range(3):
            try:
                classify_image(src)
                break
            except (OSError, IOError):
                time.sleep(0.2)
        else:
            logging.error(f"Could not open {src} after multiple attempts.")


if __name__ == "__main__":
    observer = Observer()
    handler = ImageHandler()
    observer.schedule(handler, WATCH_DIR, recursive=False)
    observer.start()
    try:
        logging.info(f"Watching directory: {WATCH_DIR} for files starting with {PREFIXES}")
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        logging.info("Stopping observer…")
        observer.stop()
    observer.join()
    logging.info("Exited.")
