"""
train_fresh.py  — Green Guard Plant Disease Model (Fresh Training)
=================================================================
Architecture : MobileNetV2  (ImageNet pre-trained, base frozen during head training)
Classes      : 46 crop-disease classes  (no unknown classes)
Input size   : 224 × 224 × 3
Epochs       : 15
Learning rate: 1e-4
Batch size   : 32
Optimizer    : Adam
Loss         : categorical_crossentropy

Augmentation
------------
  rotation_range     = 20
  zoom_range         = 0.2
  horizontal_flip    = True
  brightness_range   = [0.8, 1.2]

Callbacks
---------
  EarlyStopping   (patience=3, monitor=val_loss, restore_best_weights=True)
  ReduceLROnPlateau (monitor=val_loss, factor=0.5, patience=2, min_lr=1e-7)
  ModelCheckpoint (save best val_accuracy checkpoint)
  CSVLogger

Outputs
-------
  green_guard_fresh_best.h5        — best H5 model
  green_guard_fresh.tflite         — TFLite model ready for the Flutter app
  labels_fresh.txt                 — ordered class labels
  output_fresh/training_history.csv
  output_fresh/classification_report.txt
  output_fresh/confusion_matrix.png
  output_fresh/training_curves.png
"""

import os
import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models, applications, optimizers
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.callbacks import (
    EarlyStopping,
    ModelCheckpoint,
    CSVLogger,
    ReduceLROnPlateau,
)
from sklearn.metrics import classification_report, confusion_matrix
import matplotlib.pyplot as plt
import seaborn as sns

# ─── GPU: enable memory growth so DirectML / CUDA doesn't OOM ─────────────────
gpus = tf.config.list_physical_devices("GPU")
if gpus:
    try:
        for gpu in gpus:
            tf.config.experimental.set_memory_growth(gpu, True)
        print(f"[INFO] Memory growth enabled for {len(gpus)} GPU(s).")
    except RuntimeError as e:
        print(f"[WARN] Could not enable memory growth: {e}")
else:
    print("[INFO] No GPU detected — training on CPU.")

# ─── Configuration ─────────────────────────────────────────────────────────────
IMG_SIZE        = (224, 224)
BATCH_SIZE      = 32
EPOCHS          = 15
LEARNING_RATE   = 1e-4

# Classes that must NOT appear in training (leftover from previous experiments)
EXCLUDE_CLASSES = ["unknown_healthy", "unknown_unhealthy"]

# ─── Paths ─────────────────────────────────────────────────────────────────────
BASE_DIR        = os.path.dirname(os.path.abspath(__file__))
DATA_DIR        = os.path.join(BASE_DIR, "..", "green_guard_data_prep", "dataset_balanced")
CHECKPOINT_DIR  = os.path.join(BASE_DIR, "checkpoints_fresh")
OUTPUT_DIR      = os.path.join(BASE_DIR, "output_fresh")

os.makedirs(CHECKPOINT_DIR, exist_ok=True)
os.makedirs(OUTPUT_DIR,     exist_ok=True)

BEST_MODEL_H5      = os.path.join(BASE_DIR, "green_guard_fresh_best.h5")
FINAL_TFLITE       = os.path.join(BASE_DIR, "green_guard_fresh.tflite")
LABELS_TXT         = os.path.join(BASE_DIR, "labels_fresh.txt")
HISTORY_CSV        = os.path.join(OUTPUT_DIR, "training_history.csv")


# ─── Helper: discover the 46 target classes ───────────────────────────────────
def get_target_classes() -> list[str]:
    """Return sorted list of class folder names, excluding EXCLUDE_CLASSES."""
    train_dir = os.path.join(DATA_DIR, "train")
    if not os.path.isdir(train_dir):
        raise FileNotFoundError(f"Training directory not found: {train_dir}")

    all_classes = sorted(
        d for d in os.listdir(train_dir)
        if os.path.isdir(os.path.join(train_dir, d))
    )
    target = [c for c in all_classes if c not in EXCLUDE_CLASSES]
    print(f"[INFO] Found {len(target)} target classes (excluded {EXCLUDE_CLASSES}).")
    assert len(target) == 46, (
        f"Expected 46 classes but found {len(target)}. "
        f"Check dataset or EXCLUDE_CLASSES list."
    )
    return target


# ─── Model definition ─────────────────────────────────────────────────────────
def build_model(num_classes: int) -> tf.keras.Model:
    """
    MobileNetV2 (ImageNet weights) with frozen base + custom classification head.
    Head: GlobalAveragePooling2D → Dense(256, relu) → Dropout(0.5) → Dense(num_classes, softmax)
    """
    base_model = applications.MobileNetV2(
        input_shape=IMG_SIZE + (3,),
        include_top=False,
        weights="imagenet",
    )
    # Freeze ALL base layers — only the custom head trains in this phase
    base_model.trainable = False
    print(f"[INFO] MobileNetV2 base frozen ({len(base_model.layers)} layers).")

    inputs = tf.keras.Input(shape=IMG_SIZE + (3,), name="image_input")
    x = base_model(inputs, training=False)          # always run in inference mode
    x = layers.GlobalAveragePooling2D(name="gap")(x)
    x = layers.Dense(256, activation="relu", name="fc_256")(x)
    x = layers.Dropout(0.5, name="dropout")(x)
    outputs = layers.Dense(num_classes, activation="softmax", name="predictions")(x)

    model = tf.keras.Model(inputs, outputs, name="GreenGuard_Fresh")
    model.compile(
        optimizer=optimizers.Adam(learning_rate=LEARNING_RATE),
        loss="categorical_crossentropy",
        metrics=["accuracy"],
    )
    model.summary()
    return model


# ─── Data generators ──────────────────────────────────────────────────────────
def make_generators(target_classes: list[str]):
    """Return (train_gen, val_gen) with exact augmentation from user spec."""

    # Training: augmentation as specified
    train_datagen = ImageDataGenerator(
        rescale=1.0 / 255,
        rotation_range=20,
        zoom_range=0.2,
        horizontal_flip=True,
        brightness_range=[0.8, 1.2],
        fill_mode="nearest",
    )

    # Validation / test: NO augmentation, only rescale
    val_datagen = ImageDataGenerator(rescale=1.0 / 255)

    common_kwargs = dict(
        target_size=IMG_SIZE,
        batch_size=BATCH_SIZE,
        classes=target_classes,
        class_mode="categorical",
    )

    train_gen = train_datagen.flow_from_directory(
        os.path.join(DATA_DIR, "train"),
        shuffle=True,
        **common_kwargs,
    )
    val_gen = val_datagen.flow_from_directory(
        os.path.join(DATA_DIR, "validation"),
        shuffle=False,
        **common_kwargs,
    )

    print(f"[INFO] Train batches: {len(train_gen)} | Val batches: {len(val_gen)}")
    return train_gen, val_gen, val_datagen


# ─── Callbacks ────────────────────────────────────────────────────────────────
def make_callbacks() -> list:
    checkpoint_path = os.path.join(
        CHECKPOINT_DIR, "fresh_epoch{epoch:02d}_val{val_accuracy:.4f}.h5"
    )
    return [
        ModelCheckpoint(
            filepath=BEST_MODEL_H5,
            monitor="val_accuracy",
            save_best_only=True,
            verbose=1,
        ),
        EarlyStopping(
            monitor="val_loss",
            patience=3,
            restore_best_weights=True,
            verbose=1,
        ),
        ReduceLROnPlateau(
            monitor="val_loss",
            factor=0.5,
            patience=2,
            min_lr=1e-7,
            verbose=1,
        ),
        CSVLogger(HISTORY_CSV, append=False),
    ]


# ─── TFLite conversion ────────────────────────────────────────────────────────
def convert_to_tflite(h5_path: str, tflite_path: str) -> None:
    print("\n[INFO] Converting H5 model → TFLite …")
    loaded = tf.keras.models.load_model(h5_path)
    converter = tf.lite.TFLiteConverter.from_keras_model(loaded)
    tflite_model = converter.convert()
    with open(tflite_path, "wb") as fh:
        fh.write(tflite_model)
    size_mb = os.path.getsize(tflite_path) / 1_048_576
    print(f"[INFO] TFLite saved → {tflite_path}  ({size_mb:.1f} MB)")


# ─── Evaluation ───────────────────────────────────────────────────────────────
def evaluate_and_report(model: tf.keras.Model, val_datagen, target_classes: list[str]) -> None:
    print("\n[INFO] Running final evaluation …")

    test_dir = os.path.join(DATA_DIR, "test")
    eval_dir = test_dir if os.path.isdir(test_dir) else os.path.join(DATA_DIR, "validation")
    if not os.path.isdir(test_dir):
        print("[WARN] No test/ split found — evaluating on validation set instead.")

    test_gen = val_datagen.flow_from_directory(
        eval_dir,
        target_size=IMG_SIZE,
        batch_size=BATCH_SIZE,
        classes=target_classes,
        class_mode="categorical",
        shuffle=False,
    )

    loss, acc = model.evaluate(test_gen, verbose=1)
    print(f"[RESULT] Loss: {loss:.4f}  |  Accuracy: {acc:.4f}")

    Y_pred = model.predict(test_gen, verbose=1)
    y_pred = np.argmax(Y_pred, axis=1)
    y_true = test_gen.classes
    class_labels = list(test_gen.class_indices.keys())

    report = classification_report(y_true, y_pred, target_names=class_labels, zero_division=0)
    print("\nClassification Report:\n", report)

    report_path = os.path.join(OUTPUT_DIR, "classification_report.txt")
    with open(report_path, "w") as f:
        f.write(f"Loss: {loss:.4f}  Accuracy: {acc:.4f}\n\n")
        f.write(report)
    print(f"[INFO] Report saved → {report_path}")

    # Confusion matrix
    cm = confusion_matrix(y_true, y_pred)
    fig, ax = plt.subplots(figsize=(24, 22))
    sns.heatmap(
        cm, annot=False, fmt="d", cmap="Blues",
        xticklabels=class_labels, yticklabels=class_labels, ax=ax,
    )
    ax.set_title("Confusion Matrix — Green Guard Fresh Model", fontsize=14)
    ax.set_ylabel("True Label")
    ax.set_xlabel("Predicted Label")
    plt.tight_layout()
    cm_path = os.path.join(OUTPUT_DIR, "confusion_matrix.png")
    plt.savefig(cm_path, dpi=100)
    plt.close()
    print(f"[INFO] Confusion matrix saved → {cm_path}")


# ─── Training curves ──────────────────────────────────────────────────────────
def plot_training_curves(history) -> None:
    fig, axes = plt.subplots(1, 2, figsize=(14, 5))

    axes[0].plot(history.history["accuracy"],     label="Train Acc")
    axes[0].plot(history.history["val_accuracy"], label="Val Acc")
    axes[0].set_title("Accuracy")
    axes[0].set_xlabel("Epoch")
    axes[0].legend()
    axes[0].grid(True)

    axes[1].plot(history.history["loss"],     label="Train Loss")
    axes[1].plot(history.history["val_loss"], label="Val Loss")
    axes[1].set_title("Loss")
    axes[1].set_xlabel("Epoch")
    axes[1].legend()
    axes[1].grid(True)

    plt.suptitle("Green Guard — Fresh Training Curves", fontsize=14)
    plt.tight_layout()
    curve_path = os.path.join(OUTPUT_DIR, "training_curves.png")
    plt.savefig(curve_path, dpi=100)
    plt.close()
    print(f"[INFO] Training curves saved → {curve_path}")


# ─── Main ─────────────────────────────────────────────────────────────────────
def main() -> None:
    print("=" * 65)
    print("  Green Guard — Fresh Model Training")
    print(f"  TF version : {tf.__version__}")
    print(f"  Epochs     : {EPOCHS}")
    print(f"  Batch size : {BATCH_SIZE}")
    print(f"  LR         : {LEARNING_RATE}")
    print(f"  Input size : {IMG_SIZE}")
    print("=" * 65)

    # 1. Classes
    target_classes = get_target_classes()
    num_classes    = len(target_classes)

    # 2. Save label file  (format: "<index> <class_name>")
    with open(LABELS_TXT, "w") as f:
        for idx, cls in enumerate(target_classes):
            f.write(f"{idx} {cls}\n")
    print(f"[INFO] Labels written → {LABELS_TXT}  ({num_classes} classes)")

    # 3. Data generators
    train_gen, val_gen, val_datagen = make_generators(target_classes)

    # 4. Model
    model = build_model(num_classes)

    # 5. Train
    history = model.fit(
        train_gen,
        epochs=EPOCHS,
        validation_data=val_gen,
        callbacks=make_callbacks(),
        verbose=1,
    )

    print(f"\n[INFO] Training complete. Best model saved → {BEST_MODEL_H5}")

    # 6. Training curves
    plot_training_curves(history)

    # 7. TFLite conversion
    convert_to_tflite(BEST_MODEL_H5, FINAL_TFLITE)

    # 8. Evaluation report
    best_model = tf.keras.models.load_model(BEST_MODEL_H5)
    evaluate_and_report(best_model, val_datagen, target_classes)

    print("\n" + "=" * 65)
    print("  All done!")
    print(f"  TFLite model : {FINAL_TFLITE}")
    print(f"  Labels       : {LABELS_TXT}")
    print(f"  Reports      : {OUTPUT_DIR}")
    print("=" * 65)


if __name__ == "__main__":
    main()
