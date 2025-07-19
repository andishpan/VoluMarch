import os
import csv
import re
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from tensorflow.keras.models import load_model
from tensorflow.keras.preprocessing.image import load_img, img_to_array
import plotly.graph_objects as go


def get_scores(model, path, label):
    scores = []
    for f in os.listdir(path):
        if not f.lower().endswith(('.png', '.jpg', '.jpeg')):
            continue

        m = re.search(r'--width=\d+_(LOW|MID|HIGH|ULTRA)_', f)
        quality = m.group(1) if m else 'UNKNOWN'

        img_path = os.path.join(path, f)
        img = load_img(img_path, target_size=(224, 224))
        x = np.expand_dims(img_to_array(img) / 255.0, 0)
        p_not = float(model.predict(x, verbose=0)[0][0])
        score = 1 - p_not

        scores.append((img_path, label, quality, score))
    return scores


model = load_model('ccsn_cloudNotCloud_classification_model.keras')

folders = {
    'Beer-Lambert': 'renders/Beer_Lambert',
    'Henyey-Greenstein': 'renders/HG',
    'Powder': 'renders/Powder',
    'MOS': 'renders/MOS',
}

all_scores = []
for label, path in folders.items():
    all_scores += get_scores(model, path, label)

csv_path = 'results/classifier_scores_with_quality.csv'
with open(csv_path, 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['image_path', 'label', 'quality', 'p_cloud'])
    writer.writerows(all_scores)
print(f"Saved detailed scores to '{csv_path}'")

df = pd.read_csv(csv_path)

qualities = ['LOW', 'MID', 'HIGH', 'ULTRA']
models = df['label'].unique()
means = (df
         .groupby(['label', 'quality'])['p_cloud']
         .mean()
         .unstack(level='quality')
         .reindex(columns=qualities)
         )

x = np.arange(len(qualities))
n = len(models)
width = 0.8 / n

fig = go.Figure()

for model_label in models:
    fig.add_trace(go.Bar(
        x=qualities,
        y=means.loc[model_label].values,
        name=model_label
    ))

fig.update_layout(
    barmode='group',
    # title='Mittlere Wolkenwahrscheinlichkeit nach Modell und Qualitätsstufe',
    xaxis_title='Qualitätsstufe',
    yaxis_title='Mittlere Klassifikationswahrscheinlichkeit P',
    legend_title='Absorptions-/Streuungsverfahren',
    font=dict(size=10),
    width=800,
    height=500,
    margin=dict(l=60, r=40, t=80, b=60),
    legend=dict(
        orientation="h",
        yanchor="bottom",
        y=1.02,
        xanchor="center",
        x=0.5
    )
)

fig.write_image("wolkenwahrscheinlichkeit.png", scale=2)
