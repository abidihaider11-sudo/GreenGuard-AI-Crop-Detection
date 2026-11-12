from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from utils.preprocessing import preprocess_image
from utils.inference import TFLiteInference
import uvicorn

app = FastAPI(title="Green Guard API", description="AI Backend for Crop Disease & Weed Detection")

# Enable CORS for mobile integration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Adjust for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize TFLite Inference
try:
    inference_engine = TFLiteInference()
    print("AI Models loaded successfully!")
except Exception as e:
    print(f"Error loading models: {e}")
    inference_engine = None

@app.get("/health")
def health_check():
    return {"status": "Green Guard API is running", "models_loaded": inference_engine is not None}

@app.post("/analyze-field")
async def analyze_field(file: UploadFile = File(...)):
    if not inference_engine:
        raise HTTPException(status_code=500, detail="Models not loaded")

    try:
        # Read image
        image_bytes = await file.read()
        
        # Preprocess
        input_tensor = preprocess_image(image_bytes)
        
        # Run AI Tasks
        weed_density = inference_engine.run_segmentation(input_tensor)
        disease_class, confidence = inference_engine.run_classification(input_tensor)
        
        # Generate Recommendations
        recommendations = []
        
        # Weed Recommendations
        if weed_density > 15:
            recommendations.append("High weed density detected! Recommend targeted herbicide application or mechanical weeding.")
        elif weed_density > 5:
            recommendations.append("Moderate weed density. Keep monitoring the field.")
        else:
            recommendations.append("Low weed density. No action needed.")

        # Disease Recommendations
        if "healthy" in disease_class:
            recommendations.append("Plant looks healthy! Continue standard care.")
        else:
            plant_name = disease_class.split("___")[0].replace("_", " ")
            problem = disease_class.split("___")[1].replace("_", " ")
            recommendations.append(f"Detected {problem} on {plant_name}. Consider applying specific fungicide/pesticide treatments.")

        return {
            "weed_density": f"{weed_density}%",
            "disease_detected": disease_class,
            "confidence": confidence,
            "recommendation": " | ".join(recommendations)
        }

    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
