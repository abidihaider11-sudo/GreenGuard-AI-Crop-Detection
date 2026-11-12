import tensorflow as tf
import os

h5_model_path = r'C:\Users\PC\.gemini\antigravity\scratch\green_guard_training\green_guard_stage4_fine_tuned.h5'
tflite_model_path = r'C:\Users\PC\.gemini\antigravity\scratch\green_guard_training\green_guard_model.tflite'

print(f"Loading model from {h5_model_path}...")
model = tf.keras.models.load_model(h5_model_path)

print("Converting to TFLite...")
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()

print(f"Saving TFLite model to {tflite_model_path}...")
with open(tflite_model_path, 'wb') as f:
    f.write(tflite_model)

print("Conversion complete.")
