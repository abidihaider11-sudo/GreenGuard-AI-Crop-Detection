import os
import tensorflow as tf
import matplotlib.pyplot as plt

def plot_history(history, save_path, model_type='segmentation'):
    """
    Plots training and validation metrics.
    """
    acc_key = 'accuracy' if 'accuracy' in history.history else 'acc'
    loss = history.history['loss']
    val_loss = history.history['val_loss']
    acc = history.history[acc_key]
    val_acc = history.history['val_' + acc_key]
    
    epochs = range(1, len(loss) + 1)
    
    plt.figure(figsize=(12, 5))
    
    # Loss Plot
    plt.subplot(1, 2, 1)
    plt.plot(epochs, loss, 'y', label='Training loss')
    plt.plot(epochs, val_loss, 'r', label='Validation loss')
    plt.title(f'{model_type.capitalize()} Loss')
    plt.xlabel('Epochs')
    plt.ylabel('Loss')
    plt.legend()
    
    # Accuracy Plot
    plt.subplot(1, 2, 2)
    plt.plot(epochs, acc, 'y', label='Training acc')
    plt.plot(epochs, val_acc, 'r', label='Validation acc')
    plt.title(f'{model_type.capitalize()} Accuracy')
    plt.xlabel('Epochs')
    plt.ylabel('Accuracy')
    plt.legend()
    
    plt.tight_layout()
    plt.savefig(save_path)
    print(f"History plot saved to {save_path}")
    plt.close()

def convert_to_tflite(model_path, tflite_path):
    """
    Converts a Keras model to TFLite format.
    """
    print(f"Converting {model_path} to TFLite...")
    try:
        # Load model
        model = tf.keras.models.load_model(model_path, compile=False)
        
        # Convert
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        # Optimizations for mobile
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        
        tflite_model = converter.convert()
        
        # Save
        with open(tflite_path, 'wb') as f:
            f.write(tflite_model)
            
        print(f"TFLite model saved to {tflite_path}")
        
    except Exception as e:
        print(f"Error converting to TFLite: {e}")
