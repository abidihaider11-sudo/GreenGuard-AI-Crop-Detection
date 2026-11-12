import numpy as np
from PIL import Image
import io

def preprocess_image(image_bytes: bytes, target_size=(224, 224)):
    """
    Preprocess image for TFLite inference:
    1. Read bytes as PIL Image
    2. Convert to RGB
    3. Resize to target size
    4. Convert to NumPy array
    5. Normalize to [0, 1]
    6. Add batch dimension
    """
    # Open image from bytes
    image = Image.open(io.BytesIO(image_bytes))
    
    # Ensure RGB (3 channels)
    if image.mode != "RGB":
        image = image.convert("RGB")
    
    # Resize
    image = image.resize(target_size)
    
    # Convert to numpy and normalize
    img_array = np.array(image, dtype=np.float32) / 255.0
    
    # Add batch dimension [1, H, W, C]
    img_array = np.expand_dims(img_array, axis=0)
    
    return img_array
