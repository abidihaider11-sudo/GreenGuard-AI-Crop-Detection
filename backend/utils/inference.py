import numpy as np
import tensorflow as tf
import os

# Define the absolute paths to models
MODELS_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "models")
SEGMENTATION_MODEL_PATH = os.path.join(MODELS_DIR, "weed_segmentation_model.tflite")
CLASSIFICATION_MODEL_PATH = os.path.join(MODELS_DIR, "crop_disease_model.tflite")

# Disease Classes (based on dataset folders)
DISEASE_CLASSES = [
    "apple___apple_scab", "apple___black_rot", "apple___cedar_apple_rust", "apple___healthy",
    "blueberry___healthy", "cherry_(including_sour)___healthy", "cherry_(including_sour)___powdery_mildew",
    "corn_(maize)___cercospora_leaf_spot_gray_leaf_spot", "corn_(maize)___common_rust_", "corn_(maize)___healthy",
    "corn_(maize)___northern_leaf_blight", "grape___black_rot", "grape___esca_(black_measles)", "grape___healthy",
    "grape___leaf_blight_(isariopsis_leaf_spot)", "orange___haunglongbing_(citrus_greening)",
    "peach___bacterial_spot", "peach___healthy", "pepper,_bell___bacterial_spot", "pepper,_bell___healthy",
    "potato___early_blight", "potato___healthy", "potato___late_blight", "raspberry___healthy",
    "soybean___healthy", "squash___powdery_mildew", "strawberry___healthy", "strawberry___leaf_scorch",
    "tomato___bacterial_spot", "tomato___early_blight", "tomato___healthy", "tomato___late_blight",
    "tomato___leaf_mold", "tomato___septoria_leaf_spot", "tomato___spider_mites_two-spotted_spider_mite",
    "tomato___target_spot", "tomato___tomato_mosaic_virus", "tomato___tomato_yellow_leaf_curl_virus"
]

class TFLiteInference:
    def __init__(self):
        # Load Segmentation Model
        self.seg_interpreter = tf.lite.Interpreter(model_path=SEGMENTATION_MODEL_PATH)
        self.seg_interpreter.allocate_tensors()
        self.seg_input_details = self.seg_interpreter.get_input_details()
        self.seg_output_details = self.seg_interpreter.get_output_details()

        # Load Classification Model
        self.cls_interpreter = tf.lite.Interpreter(model_path=CLASSIFICATION_MODEL_PATH)
        self.cls_interpreter.allocate_tensors()
        self.cls_input_details = self.cls_interpreter.get_input_details()
        self.cls_output_details = self.cls_interpreter.get_output_details()

    def run_segmentation(self, input_tensor):
        """Runs segmentation and returns weed density %"""
        self.seg_interpreter.set_tensor(self.seg_input_details[0]['index'], input_tensor)
        self.seg_interpreter.invoke()
        
        output = self.seg_interpreter.get_tensor(self.seg_output_details[0]['index'])
        
        # Binary mask threshold (assuming sigmoid/probability output)
        mask = (output[0, :, :, 0] > 0.5).astype(np.uint8)
        
        # Calculate density
        total_pixels = mask.size
        weed_pixels = np.sum(mask)
        density = (weed_pixels / total_pixels) * 100
        
        return round(density, 2)

    def run_classification(self, input_tensor):
        """Runs classification and returns class name + confidence"""
        self.cls_interpreter.set_tensor(self.cls_input_details[0]['index'], input_tensor)
        self.cls_interpreter.invoke()
        
        output = self.cls_interpreter.get_tensor(self.cls_output_details[0]['index'])
        
        # Get highest probability index
        class_idx = np.argmax(output[0])
        confidence = float(output[0][class_idx])
        class_name = DISEASE_CLASSES[class_idx]
        
        return class_name, round(confidence, 4)
