"""
Train TFLite model for Lantana camara & Parthenium hysterophorus detection.
Uses the user's own photos + data augmentation to create a working demo model.
"""
import os
import sys
import shutil

import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models
from tensorflow.keras.preprocessing.image import load_img, img_to_array

# Paths
PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
DATASET_DIR = os.path.join(PROJECT_DIR, "dataset")
MODEL_DIR = os.path.join(PROJECT_DIR, "assets", "model")
IMG_SIZE = 224

# The two user-provided photos
USER_PHOTOS = {
    "Lantana_camara": os.path.join(PROJECT_DIR, "Lantana camara.jpg"),
    "Parthenium_hysterophorus": os.path.join(PROJECT_DIR, "Parthenium hysterophorus.jpg"),
}

def prepare_dataset():
    """Create augmented dataset from the two user photos."""
    print("=" * 50)
    print("Preparing dataset from user photos...")
    print("=" * 50)

    # Clean and create dataset directories
    if os.path.exists(DATASET_DIR):
        shutil.rmtree(DATASET_DIR)

    for class_name in USER_PHOTOS:
        class_dir = os.path.join(DATASET_DIR, class_name)
        os.makedirs(class_dir, exist_ok=True)

    # Data augmentation generator
    augmentor = tf.keras.preprocessing.image.ImageDataGenerator(
        rotation_range=40,
        width_shift_range=0.3,
        height_shift_range=0.3,
        shear_range=0.3,
        zoom_range=0.4,
        horizontal_flip=True,
        vertical_flip=False,
        brightness_range=[0.6, 1.4],
        fill_mode='reflect',
    )

    # Generate augmented images for each class
    for class_name, photo_path in USER_PHOTOS.items():
        if not os.path.exists(photo_path):
            print(f"ERROR: Photo not found: {photo_path}")
            continue

        print(f"\nProcessing: {class_name}")
        print(f"  Source: {photo_path}")

        # Load and resize original image
        img = load_img(photo_path, target_size=(IMG_SIZE, IMG_SIZE))
        img_array = img_to_array(img)
        img_array = np.expand_dims(img_array, axis=0)

        # Save original
        class_dir = os.path.join(DATASET_DIR, class_name)
        original_path = os.path.join(class_dir, "original.jpg")
        img.save(original_path)

        # Generate 60 augmented images per class (heavy augmentation from single photo)
        count = 0
        target_count = 60
        for batch in augmentor.flow(img_array, batch_size=1, save_to_dir=class_dir,
                                      save_prefix="aug", save_format="jpg"):
            count += 1
            if count >= target_count:
                break

        total = len(os.listdir(class_dir))
        print(f"  Generated {total} images (1 original + {total - 1} augmented)")

    print(f"\nDataset ready at: {DATASET_DIR}")


def train_model():
    """Train a MobileNetV2-based classifier and export to TFLite."""
    print("\n" + "=" * 50)
    print("Training model with MobileNetV2 transfer learning...")
    print("=" * 50)

    # Load dataset
    train_ds = tf.keras.utils.image_dataset_from_directory(
        DATASET_DIR,
        validation_split=0.2,
        subset="training",
        seed=42,
        image_size=(IMG_SIZE, IMG_SIZE),
        batch_size=8,
    )

    val_ds = tf.keras.utils.image_dataset_from_directory(
        DATASET_DIR,
        validation_split=0.2,
        subset="validation",
        seed=42,
        image_size=(IMG_SIZE, IMG_SIZE),
        batch_size=8,
    )

    class_names = train_ds.class_names
    num_classes = len(class_names)
    print(f"Classes: {class_names}")
    print(f"Number of classes: {num_classes}")

    # Prefetch for performance
    AUTOTUNE = tf.data.AUTOTUNE
    train_ds = train_ds.cache().shuffle(100).prefetch(buffer_size=AUTOTUNE)
    val_ds = val_ds.cache().prefetch(buffer_size=AUTOTUNE)

    # Use MobileNetV2 as base (pretrained on ImageNet)
    base_model = tf.keras.applications.MobileNetV2(
        input_shape=(IMG_SIZE, IMG_SIZE, 3),
        include_top=False,
        weights='imagenet'
    )
    base_model.trainable = False  # Freeze base

    # Build model
    model = models.Sequential([
        layers.Rescaling(1./127.5, offset=-1, input_shape=(IMG_SIZE, IMG_SIZE, 3)),
        base_model,
        layers.GlobalAveragePooling2D(),
        layers.Dropout(0.3),
        layers.Dense(64, activation='relu'),
        layers.Dropout(0.2),
        layers.Dense(num_classes, activation='softmax'),
    ])

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )

    model.summary()

    # Train (frozen base)
    print("\nPhase 1: Training top layers (base frozen)...")
    history1 = model.fit(train_ds, validation_data=val_ds, epochs=10)

    # Fine-tune: unfreeze last 30 layers of base
    print("\nPhase 2: Fine-tuning last layers of MobileNetV2...")
    base_model.trainable = True
    for layer in base_model.layers[:-30]:
        layer.trainable = False

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.0001),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )

    history2 = model.fit(train_ds, validation_data=val_ds, epochs=10)

    # Evaluate
    loss, acc = model.evaluate(val_ds)
    print(f"\nFinal validation accuracy: {acc:.4f}")

    # Convert to TFLite
    print("\nConverting to TFLite...")
    os.makedirs(MODEL_DIR, exist_ok=True)

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    tflite_path = os.path.join(MODEL_DIR, "plant_classifier.tflite")
    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)

    labels_path = os.path.join(MODEL_DIR, "labels.txt")
    with open(labels_path, 'w') as f:
        f.write("\n".join(class_names))

    model_size = os.path.getsize(tflite_path) / (1024 * 1024)
    print(f"\n{'=' * 50}")
    print(f"SUCCESS!")
    print(f"  Model: {tflite_path} ({model_size:.1f} MB)")
    print(f"  Labels: {labels_path}")
    print(f"  Classes: {class_names}")
    print(f"  Accuracy: {acc:.1%}")
    print(f"{'=' * 50}")


if __name__ == "__main__":
    prepare_dataset()
    train_model()
