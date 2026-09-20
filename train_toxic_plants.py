"""
Train TFLite model for 21 toxic plant classes + Unknown.

Pipeline:
  1. Split ORIGINAL images into train/val/test (70/15/15) BEFORE augmenting
  2. Augment ONLY the training split
  3. Transfer learning with MobileNetV3-Small (lightweight, mobile-optimized)
  4. Phase 1: Train top layers (base frozen)
  5. Phase 2: Fine-tune last N layers
  6. Evaluate on TEST set -- confusion matrix, per-class accuracy
  7. Compute confidence threshold (deployment logic)
  8. Convert to TFLite and export

Usage:
    python train_toxic_plants.py
"""
import os
import sys
import sys
import shutil
import json
import random

import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models
from keras.utils import load_img, img_to_array
from sklearn.metrics import classification_report

# Fix Windows console encoding
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

# -- Paths -------------------------------------------------------------
PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_OF_PLANT_DIR = os.path.join(PROJECT_DIR, "data_of_plant")
DATASET_DIR = os.path.join(PROJECT_DIR, "dataset_split")
MODEL_DIR = os.path.join(PROJECT_DIR, "assets", "model")

# -- Hyperparameters ---------------------------------------------------
IMG_SIZE = 224
BATCH_SIZE = 32
TRAIN_FRACTION = 0.70
VAL_FRACTION = 0.15
TEST_FRACTION = 0.15
AUG_PER_IMAGE = 15       # Increased to create more variations for real-world photos
MIN_RECOMMENDED = 30
SEED = 42

# -- Phase 1 (frozen base) --------------------------------------------
PHASE1_EPOCHS = 40
PHASE1_LR = 0.0005
PHASE1_PATIENCE = 15      # EarlyStopping patience

# -- Phase 2 (fine-tune) ----------------------------------------------
PHASE2_EPOCHS = 30
PHASE2_LR = 0.000001
PHASE2_PATIENCE = 8
FINE_TUNE_LAYERS = 0    # 0 = unfreeze ALL layers of base model

# -- Label mapping (directory name -> scientific name) ------------------
LABEL_TO_SCIENTIFIC = {
    "1. Abrus precatorius — Rosary Pea": "Abrus precatorius",
    "2. Lantana camara — Lantana": "Lantana camara",
    "3. Parthenium hysterophorus — Congress Grass": "Parthenium hysterophorus",
    "4. Pteridium aquilinum — Bracken Fern": "Pteridium aquilinum",
    "5. Nerium oleander — Oleander": "Nerium oleander",
    "6. Thevetia peruviana — Yellow Oleander": "Thevetia peruviana",
    "7. Calotropis gigantea — Giant Milkweed": "Calotropis gigantea",
    "8. Datura stramonium — Datura  Jimson Weed": "Datura stramonium",
    "9. Mimosa pudica — Touch-Me-Not": "Mimosa pudica",
    "10. Immature Sorghum": "Sorghum bicolor (immature)",
    "11. Ricinus communis — Castor": "Ricinus communis",
    "12. Ipomoea": "Ipomoea",
    "13. Strychnos nux-vomica — Nux-vomica": "Strychnos nuxvomica",
    "14. Gloriosa superba — Flame Lily": "Gloriosa superba",
    "15. Argemone mexicana — Mexican Poppy": "Argemone mexicana",
    "16. Jatropha curcas — Physic Nut": "Jatropha curcas",
    "17. Jatropha multifida — Coral Plant": "Jatropha multifida",
    "18. Manihot esculenta —Cassava  Tapioca": "Manihot esculenta",
    "19. Antiaris toxicaria — Upas Tree": "Antiaris toxicaria",
    "20. Cerbera odollam — Suicide Tree": "Cerbera odollum",
    "21. Citrullus colocynthis — Bitter Apple": "Citrullus colocynthis",
    "22. Unknown — Other Plants": "Unknown",
}

random.seed(SEED)
np.random.seed(SEED)
tf.random.set_seed(SEED)


# ======================================================================
# STEP 1 -- Split originals into train / val / test, augment only train
# ======================================================================

def _save_resized(src_path, dst_path):
    """Load an image, resize to IMG_SIZExIMG_SIZE, save as JPEG."""
    img = load_img(src_path, target_size=(IMG_SIZE, IMG_SIZE))
    img.save(dst_path)
    return img


def prepare_dataset():
    """Split raw photos 70/15/15, then augment ONLY the train split."""
    print("=" * 60)
    print("STEP 1 -- Preparing leakage-safe dataset")
    print("        Split: 70% train / 15% val / 15% test")
    print("        Augmentation: TRAIN ONLY")
    print("=" * 60)

    if not os.path.exists(DATA_OF_PLANT_DIR):
        print(f"ERROR: {DATA_OF_PLANT_DIR} not found!")
        sys.exit(1)

    # Clean slate
    if os.path.exists(DATASET_DIR):
        shutil.rmtree(DATASET_DIR)

    train_root = os.path.join(DATASET_DIR, "train")
    val_root = os.path.join(DATASET_DIR, "val")
    test_root = os.path.join(DATASET_DIR, "test")

    augmentor = tf.keras.preprocessing.image.ImageDataGenerator(
        rotation_range=45,
        width_shift_range=0.2,
        height_shift_range=0.2,
        shear_range=0.2,
        zoom_range=0.4,
        horizontal_flip=True,
        vertical_flip=True,
        brightness_range=[0.7, 1.3],
        channel_shift_range=20.0,
        fill_mode='reflect',
    )

    plant_dirs = sorted(os.listdir(DATA_OF_PLANT_DIR))
    summary = []

    for dir_name in plant_dirs:
        dir_path = os.path.join(DATA_OF_PLANT_DIR, dir_name)
        if not os.path.isdir(dir_path):
            continue

        images = [f for f in os.listdir(dir_path)
                  if f.lower().endswith(('.jpg', '.jpeg', '.png', '.webp'))]
        if not images:
            print(f"  [!] SKIP: No images in {dir_name}")
            continue
        if len(images) < MIN_RECOMMENDED:
            print(f"  [!] WARNING: '{dir_name}' has only {len(images)} photos "
                  f"(recommended >= {MIN_RECOMMENDED})")

        # Shuffle and split
        random.shuffle(images)
        n = len(images)
        n_test = max(1, round(n * TEST_FRACTION))
        n_val = max(1, round(n * VAL_FRACTION))
        n_train = n - n_val - n_test
        if n_train < 1:
            n_train = 1

        test_imgs = images[:n_test]
        val_imgs = images[n_test:n_test + n_val]
        train_imgs = images[n_test + n_val:]
        if not train_imgs:
            train_imgs = images[:1]  # at minimum 1 train image

        # Create directories
        train_cls = os.path.join(train_root, dir_name)
        val_cls = os.path.join(val_root, dir_name)
        test_cls = os.path.join(test_root, dir_name)
        os.makedirs(train_cls, exist_ok=True)
        os.makedirs(val_cls, exist_ok=True)
        os.makedirs(test_cls, exist_ok=True)

        print(f"\n  {dir_name}: {n} images -> "
              f"train={len(train_imgs)} val={len(val_imgs)} test={len(test_imgs)}")

        # Save TEST images (no augmentation, no data leakage)
        for img_file in test_imgs:
            src = os.path.join(dir_path, img_file)
            try:
                safe = img_file.replace(' ', '_')[:30]
                _save_resized(src, os.path.join(test_cls, f"test_{safe}.jpg"))
            except Exception as e:
                print(f"    Error (test) {img_file}: {e}")

        # Save VAL images (no augmentation)
        for img_file in val_imgs:
            src = os.path.join(dir_path, img_file)
            try:
                safe = img_file.replace(' ', '_')[:30]
                _save_resized(src, os.path.join(val_cls, f"val_{safe}.jpg"))
            except Exception as e:
                print(f"    Error (val) {img_file}: {e}")

        # Save TRAIN images and balance classes to exactly 500 images per class
        target_train_count = 500
        
        # 1. Save original train images up to target_train_count
        saved_train_count = 0
        saved_train_images = []
        for img_file in train_imgs[:target_train_count]:
            src = os.path.join(dir_path, img_file)
            try:
                safe = img_file.replace(' ', '_')[:30]
                dst = os.path.join(train_cls, f"orig_{safe}.jpg")
                img = _save_resized(src, dst)
                saved_train_images.append((img, safe))
                saved_train_count += 1
            except Exception as e:
                print(f"    Error (train) {img_file}: {e}")
                
        # 2. If we have fewer than target_train_count, augment to reach it
        if saved_train_count > 0 and saved_train_count < target_train_count:
            needed = target_train_count - saved_train_count
            print(f"    -> Augmenting {needed} images to reach {target_train_count}")
            
            aug_count = 0
            while aug_count < needed:
                img, safe_name = random.choice(saved_train_images)
                x = img_to_array(img)
                x = x.reshape((1,) + x.shape)
                
                for batch in augmentor.flow(x, batch_size=1, save_to_dir=train_cls, save_prefix=f"aug_{safe_name}", save_format='jpg'):
                    aug_count += 1
                    break

        t_count = len(os.listdir(train_cls))
        v_count = len(os.listdir(val_cls))
        te_count = len(os.listdir(test_cls))
        summary.append((dir_name, t_count, v_count, te_count))
        print(f"    -> train={t_count}  val={v_count}  test={te_count}")

    print(f"\n{'='*60}")
    print("Dataset split summary:")
    print(f"  {'Class':<50} {'Train':>6} {'Val':>5} {'Test':>5}")
    print(f"  {'-'*50} {'-'*6} {'-'*5} {'-'*5}")
    for name, t, v, te in summary:
        short = name[:48]
        print(f"  {short:<50} {t:>6} {v:>5} {te:>5}")
    print(f"\nDataset ready at: {DATASET_DIR}")


# ======================================================================
# STEP 2 -- Build and train the model
# ======================================================================

def _compute_class_weights(train_ds, num_classes):
    """Compute class weights inversely proportional to class frequency."""
    counts = np.zeros(num_classes)
    for _, labels in train_ds:
        for label in labels.numpy():
            counts[int(label)] += 1
    total = counts.sum()
    weights = {}
    for i in range(num_classes):
        if counts[i] > 0:
            weights[i] = total / (num_classes * counts[i])
        else:
            weights[i] = 1.0
    return weights


def train_model():
    print("\n" + "=" * 60)
    print("STEP 2 -- Training with EfficientNetB0 transfer learning")
    print("=" * 60)

    # -- Load datasets -------------------------------------------------
    train_ds = tf.keras.utils.image_dataset_from_directory(
        os.path.join(DATASET_DIR, "train"),
        seed=SEED, image_size=(IMG_SIZE, IMG_SIZE), batch_size=BATCH_SIZE,
    )
    val_ds = tf.keras.utils.image_dataset_from_directory(
        os.path.join(DATASET_DIR, "val"),
        seed=SEED, image_size=(IMG_SIZE, IMG_SIZE), batch_size=BATCH_SIZE,
        shuffle=False,
    )
    test_ds = tf.keras.utils.image_dataset_from_directory(
        os.path.join(DATASET_DIR, "test"),
        seed=SEED, image_size=(IMG_SIZE, IMG_SIZE), batch_size=BATCH_SIZE,
        shuffle=False,
    )

    class_names = train_ds.class_names
    num_classes = len(class_names)
    print(f"\nClasses ({num_classes}): {class_names}")

    # -- Class weights (smoothed balanced weights for plant classes) -------
    class_weights = _compute_class_weights(train_ds, num_classes)
    # Dampen extreme class weight ratios with square root scaling for stability
    for k in class_weights:
        class_weights[k] = float(np.sqrt(class_weights[k]))
    print(f"Smoothed class weight range: "
          f"{min(class_weights.values()):.2f} - {max(class_weights.values()):.2f}")

    # -- Dynamic Data Augmentation Pipeline ----------------------------
    data_augmentation = tf.keras.Sequential([
        layers.RandomFlip("horizontal_and_vertical"),
        layers.RandomRotation(0.25),
        layers.RandomZoom(0.2),
        layers.RandomTranslation(0.15, 0.15),
        layers.RandomContrast(0.2),
    ], name="data_augmentation")

    AUTOTUNE = tf.data.AUTOTUNE
    train_ds = train_ds.map(
        lambda x, y: (data_augmentation(x, training=True), y),
        num_parallel_calls=AUTOTUNE
    ).prefetch(AUTOTUNE)
    
    val_ds = val_ds.cache().prefetch(AUTOTUNE)
    test_ds = test_ds.cache().prefetch(AUTOTUNE)

    # -- Build model with EfficientNetV2B0 / EfficientNetB0 ------------
    try:
        base_model = tf.keras.applications.EfficientNetV2B0(
            input_shape=(IMG_SIZE, IMG_SIZE, 3),
            include_top=False,
            weights='imagenet',
        )
        print("Using EfficientNetV2B0 backbone")
    except Exception:
        base_model = tf.keras.applications.EfficientNetB0(
            input_shape=(IMG_SIZE, IMG_SIZE, 3),
            include_top=False,
            weights='imagenet',
        )
        print("Using EfficientNetB0 backbone")
        
    base_model.trainable = False

    model = models.Sequential([
        layers.InputLayer(input_shape=(IMG_SIZE, IMG_SIZE, 3)),
        base_model,
        layers.GlobalAveragePooling2D(),
        layers.BatchNormalization(),
        layers.Dropout(0.5),
        layers.Dense(
            512, 
            activation='swish', 
            kernel_regularizer=tf.keras.regularizers.l2(1e-4)
        ),
        layers.BatchNormalization(),
        layers.Dropout(0.4),
        layers.Dense(num_classes, activation='softmax'),
    ])

    # -- Callbacks -----------------------------------------------------
    early_stop = tf.keras.callbacks.EarlyStopping(
        monitor='val_accuracy', patience=PHASE1_PATIENCE,
        restore_best_weights=True, verbose=1,
    )
    lr_reduce = tf.keras.callbacks.ReduceLROnPlateau(
        monitor='val_loss', factor=0.5, patience=3, min_lr=1e-6, verbose=1,
    )

    # -- Phase 1: Train top layers -------------------------------------
    print(f"\n{'-'*60}")
    print(f"Phase 1: Training top layers (base frozen)")
    print(f"  Epochs: up to {PHASE1_EPOCHS}, EarlyStopping patience={PHASE1_PATIENCE}")
    print(f"  LR: {PHASE1_LR}")
    print(f"{'-'*60}")

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=PHASE1_LR),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy'],
    )
    model.summary()

    model.fit(
        train_ds, validation_data=val_ds, epochs=PHASE1_EPOCHS,
        class_weight=class_weights,
        callbacks=[early_stop, lr_reduce],
    )

    # -- Phase 2: Fine-tune top layers of backbone model ----------------
    print(f"\n{'-'*60}")
    print("Phase 2: Fine-tuning top 30% of backbone layers")
    print(f"  Epochs: up to {PHASE2_EPOCHS}, EarlyStopping patience={PHASE2_PATIENCE}")
    print(f"  LR: {PHASE2_LR} -> 1e-7")
    print(f"{'-'*60}")

    # Only unfreeze the top 30% of layers to prevent catastrophic forgetting
    base_model.trainable = True
    total_layers = len(base_model.layers)
    freeze_until = int(total_layers * 0.7)
    for layer in base_model.layers[:freeze_until]:
        layer.trainable = False
    print(f"  Base model: {total_layers} layers, frozen first {freeze_until}, "
          f"fine-tuning last {total_layers - freeze_until}")

    early_stop_ft = tf.keras.callbacks.EarlyStopping(
        monitor='val_accuracy', patience=PHASE2_PATIENCE,
        restore_best_weights=True, verbose=1,
    )
    lr_reduce_ft = tf.keras.callbacks.ReduceLROnPlateau(
        monitor='val_loss', factor=0.5, patience=3, min_lr=1e-7, verbose=1,
    )

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=PHASE2_LR),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy'],
    )

    model.fit(
        train_ds, validation_data=val_ds, epochs=PHASE2_EPOCHS,
        class_weight=class_weights,
        callbacks=[early_stop_ft, lr_reduce_ft],
    )

    # -- Validation accuracy -------------------------------------------
    val_loss, val_acc = model.evaluate(val_ds)
    print(f"\nValidation accuracy: {val_acc:.4f}")

    # ==================================================================
    # STEP 3 -- Evaluate on TEST set (never seen during training)
    # ==================================================================
    print("\n" + "=" * 60)
    print("STEP 3 -- Test Set Evaluation + Confusion Matrix")
    print("=" * 60)

    test_loss, test_acc = model.evaluate(test_ds)
    print(f"\n* Test accuracy: {test_acc:.4f}  (loss: {test_loss:.4f})")

    # Collect predictions on TEST set
    y_true, y_pred, y_probs = [], [], []
    for images, labels in test_ds:
        preds = model.predict(images, verbose=0)
        y_probs.extend(np.max(preds, axis=1))
        y_pred.extend(np.argmax(preds, axis=1))
        y_true.extend(labels.numpy())

    y_true = np.array(y_true)
    y_pred = np.array(y_pred)
    y_probs = np.array(y_probs)

    # -- Confusion Matrix ----------------------------------------------
    cm = np.zeros((num_classes, num_classes), dtype=int)
    for t, p in zip(y_true, y_pred):
        cm[t, p] += 1

    report_lines = [
        "TRAINING REPORT",
        "=" * 50,
        f"Validation accuracy: {val_acc:.4f}",
        f"Test accuracy:       {test_acc:.4f}",
        "",
        "Per-class test accuracy:",
    ]

    print(f"\n{'Class':<50} {'Acc':>6} {'Correct':>8} {'Total':>6}")
    print("-" * 75)

    confused_pairs = []
    for i, name in enumerate(class_names):
        total = cm[i].sum()
        correct = cm[i, i]
        class_acc = correct / total if total else 0.0
        line = f"  {name}: {class_acc:.0%} ({correct}/{total})"
        short = name[:48]
        print(f"  {short:<48} {class_acc:>5.0%} {correct:>7}/{total:<5}")
        report_lines.append(line)

        # Identify confusions for classes below 70% accuracy
        if class_acc < 0.7 and total > 0:
            top_confusions = sorted(
                [(cm[i, c], class_names[c])
                 for c in range(num_classes) if c != i and cm[i, c] > 0],
                reverse=True
            )[:3]
            if top_confusions:
                for count_c, name_c in top_confusions:
                    confused_pairs.append((name, name_c, count_c))
                desc = ", ".join(
                    f"{n2} ({n}x)" for n, n2 in top_confusions)
                conf_line = f"    -> confused with: {desc}"
                print(conf_line)
                report_lines.append(conf_line)

    # -- Classification Report -----------------------------------------
    print("\nClassification Report (Precision, Recall, F1):")
    cls_report = classification_report(y_true, y_pred, target_names=class_names, zero_division=0)
    print(cls_report)
    report_lines.append("\nClassification Report:\n" + cls_report)

    # -- Print confusion matrix (abbreviated) --------------------------
    if num_classes <= 25:
        print(f"\nConfusion Matrix (rows=actual, cols=predicted):")
        # Header
        short_names = [cn[:6] for cn in class_names]
        header = "        " + " ".join(f"{s:>6}" for s in short_names)
        print(header)
        for i, name in enumerate(class_names):
            row = " ".join(f"{cm[i, j]:>6}" for j in range(num_classes))
            print(f"  {short_names[i]:>6} {row}")

    # ==================================================================
    # STEP 4 -- Confidence threshold (deployment logic)
    # ==================================================================
    print(f"\n{'='*60}")
    print("Confidence Threshold (deployment logic)")
    print(f"{'='*60}")
    report_lines.append("\n" + "="*60 + "\nConfidence Threshold Evaluation\n" + "="*60)

    print(f"\n{'Threshold':<10} {'Accepted':<10} {'Acc (Accepted)':<20} {'Rejection Rate':<15}")
    print("-" * 60)
    report_lines.append(f"\n{'Threshold':<10} {'Accepted':<10} {'Acc (Accepted)':<20} {'Rejection Rate':<15}")
    report_lines.append("-" * 60)

    thresholds = [0.0, 0.50, 0.70, 0.80, 0.90, 0.95, 0.98]
    for t in thresholds:
        accepted_mask = y_probs >= t
        accepted_count = np.sum(accepted_mask)
        rejected_count = len(y_probs) - accepted_count
        rejection_rate = rejected_count / len(y_probs) if len(y_probs) > 0 else 0.0

        if accepted_count > 0:
            accepted_correct = np.sum((y_true == y_pred) & accepted_mask)
            accepted_acc = accepted_correct / accepted_count
        else:
            accepted_acc = 0.0

        line = f"{t:<10.2f} {accepted_count:<10} {accepted_acc:<20.2%} {rejection_rate:<15.2%}"
        print(line)
        report_lines.append(line)

    correct_probs = y_probs[y_true == y_pred]
    incorrect_probs = y_probs[y_true != y_pred]

    print(f"\n  Correct predictions   -- mean conf: {correct_probs.mean():.3f}, "
          f"min: {correct_probs.min():.3f}")
    if len(incorrect_probs) > 0:
        print(f"  Incorrect predictions -- mean conf: {incorrect_probs.mean():.3f}, "
              f"max: {incorrect_probs.max():.3f}")
        # Threshold: reject anything below the 90th percentile of incorrect preds
        suggested_threshold = float(np.percentile(incorrect_probs, 90))
    else:
        suggested_threshold = 0.65

    suggested_threshold = max(0.60, min(0.95, suggested_threshold))
    print(f"\n  -> Suggested threshold: {suggested_threshold:.4f}")
    print(f"    Below this -> show 'Plant not recognized' in the app")
    report_lines.append(f"\nConfidence Threshold: {suggested_threshold:.4f}")

    # ==================================================================
    # STEP 5 -- Export: TFLite + labels + threshold
    # ==================================================================
    print(f"\n{'='*60}")
    print("Exporting TFLite model")
    print(f"{'='*60}")

    os.makedirs(MODEL_DIR, exist_ok=True)

    # Convert to TFLite with quantization
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    tflite_path = os.path.join(MODEL_DIR, "plant_classifier.tflite")
    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)

    # Labels
    labels_path = os.path.join(MODEL_DIR, "labels.txt")
    label_lines = [LABEL_TO_SCIENTIFIC.get(cn, cn) for cn in class_names]
    with open(labels_path, 'w') as f:
        f.write("\n".join(label_lines))

    # Label mapping JSON
    mapping_path = os.path.join(MODEL_DIR, "label_mapping.json")
    mapping = {
        i: {"dir_name": cn, "scientific_name": label_lines[i]}
        for i, cn in enumerate(class_names)
    }
    with open(mapping_path, 'w') as f:
        json.dump(mapping, f, indent=2)

    # Threshold JSON
    threshold_path = os.path.join(MODEL_DIR, "threshold.json")
    with open(threshold_path, 'w') as f:
        json.dump({"confidence_threshold": suggested_threshold}, f, indent=2)

    # Training report
    report_path = os.path.join(PROJECT_DIR, "training_report.txt")
    with open(report_path, 'w') as f:
        f.write("\n".join(report_lines))

    model_size = os.path.getsize(tflite_path) / (1024 * 1024)
    print(f"\n[OK] Model saved:     {tflite_path}  ({model_size:.1f} MB)")
    print(f"[OK] Labels saved:    {labels_path}")
    print(f"[OK] Threshold saved: {threshold_path}")
    print(f"[OK] Report saved:    {report_path}")
    print(f"\n* Final test accuracy: {test_acc:.1%}")
    print(f"* Confidence threshold: {suggested_threshold:.4f}")

    if confused_pairs:
        print(f"\n[!] Most confused plant pairs:")
        for actual, predicted, count in confused_pairs[:5]:
            a_short = actual[:30]
            p_short = predicted[:30]
            print(f"    {a_short} -> {p_short} ({count}x)")


# ======================================================================

if __name__ == "__main__":
    prepare_dataset()
    train_model()
