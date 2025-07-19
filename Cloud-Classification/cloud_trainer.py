import os
import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras import layers, models, metrics
from tensorflow.keras.callbacks import ModelCheckpoint, EarlyStopping, ReduceLROnPlateau
import matplotlib.pyplot as plt
from sklearn.metrics import classification_report, confusion_matrix

# === Configuration ===
base_dir = 'datap'
train_dir = os.path.join(base_dir, 'train')
val_dir = os.path.join(base_dir, 'val')
test_dir = os.path.join(base_dir, 'test')
model_save_path = 'ccsn_cloudNotCloud_model_weights.keras'

# === Data Augmentation ===
train_datagen = ImageDataGenerator(
    rescale=1. / 255,
    rotation_range=40,
    width_shift_range=0.2,
    height_shift_range=0.2,
    shear_range=0.2,
    zoom_range=0.2,
    horizontal_flip=True,
    fill_mode='nearest'
)
val_datagen = ImageDataGenerator(rescale=1. / 255)
test_datagen = ImageDataGenerator(rescale=1. / 255)

train_generator = train_datagen.flow_from_directory(
    train_dir,
    target_size=(224, 224),
    batch_size=32,
    class_mode='binary'
)
print("Class indices:", train_generator.class_indices)
val_generator = val_datagen.flow_from_directory(
    val_dir,
    target_size=(224, 224),
    batch_size=32,
    class_mode='binary'
)
test_generator = test_datagen.flow_from_directory(
    test_dir,
    target_size=(224, 224),
    batch_size=32,
    class_mode='binary',
    shuffle=False
)

# === Model ===
base_model = MobileNetV2(
    weights='imagenet',
    include_top=False,
    input_shape=(224, 224, 3)
)
base_model.trainable = False

model = models.Sequential([
    base_model,
    layers.GlobalAveragePooling2D(),
    layers.Dense(128, activation='relu'),
    layers.BatchNormalization(),
    layers.Dropout(0.5),
    layers.Dense(1, activation='sigmoid')
])

# model.compile(optimizer='adam', loss='binary_crossentropy', metrics=['accuracy'])
model.compile(
    optimizer='adam',
    loss='binary_crossentropy',
    metrics=[
        'accuracy',
        metrics.Precision(name='precision'),
        metrics.Recall(name='recall'),
        metrics.AUC(name='auc')
    ]
)

# === Callbacks ===
checkpoint = ModelCheckpoint(
    model_save_path,
    monitor='val_loss',
    save_best_only=True,
    mode='min'
)
early_stopping = EarlyStopping(
    monitor='val_loss',
    patience=10,
    restore_best_weights=True
)
reduce_lr = ReduceLROnPlateau(
    monitor='val_loss',
    factor=0.2,
    patience=5,
    min_lr=1e-4
)

# === Training ===
history = model.fit(
    train_generator,
    steps_per_epoch=train_generator.samples // train_generator.batch_size,
    validation_data=val_generator,
    validation_steps=val_generator.samples // val_generator.batch_size,
    epochs=30,
    callbacks=[checkpoint, early_stopping, reduce_lr]
)

# === Save final model ===
model.save('ccsn_cloudNotCloud_classification_model.keras')
print(f"Training complete. Best weights saved to {model_save_path}")

# === Evaluation on Test Set ===
test_results = model.evaluate(
    test_generator,
    steps=test_generator.samples // test_generator.batch_size,
    verbose=1
)

# === Print Final Test Metrics ===
for name, value in zip(model.metrics_names, test_results):
    print(f"{name}: {value:.4f}")

# === Plot training vs validation curves ===
metrics_to_plot = ['accuracy', 'precision', 'recall', 'auc']
epochs = range(1, len(history.history['accuracy']) + 1)

plt.figure(figsize=(12, 8))
for i, m in enumerate(metrics_to_plot, 1):
    plt.subplot(2, 2, i)
    plt.plot(epochs, history.history[m], label=f'train {m}')
    plt.plot(epochs, history.history[f'val_{m}'], label=f'val {m}')
    plt.xlabel('Epoch')
    plt.ylabel(m)
    plt.legend()
    plt.tight_layout()

plt.suptitle('Training vs. Validation Metrics', y=1.02, fontsize=16)
plt.show()

# === Plot bar chart of final test metrics ===
test_metric_names = model.metrics_names
test_metric_vals = test_results


names = test_metric_names[1:]
vals = test_metric_vals[1:]

plt.figure(figsize=(6, 4))
plt.bar(names, vals)
plt.ylabel('Score')
plt.title('Final Test Set Metrics')
plt.ylim(0, 1)
plt.show()
