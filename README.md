<div align="center">

<img src="app/assets/images/" alt="" width="100" />

# 🌿 GreenGuard

### AI-Powered Crop Disease & Weed Detection App

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Python](https://img.shields.io/badge/Python-3.10+-3776AB?logo=python)](https://python.org)
[![TensorFlow](https://img.shields.io/badge/TensorFlow-2.16-FF6F00?logo=tensorflow)](https://tensorflow.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.111-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**GreenGuard** is a cross-platform mobile application that uses on-device AI to detect crop diseases and weed infestations from a single leaf photo — no internet connection required.

</div>

---

## ✨ Features

| Feature | Description |
|---|---|
| 🔍 **Disease Detection** | Identifies 46 crop disease classes across 15+ plant species using MobileNetV2 |
| 🌱 **Weed Detection** | Estimates weed density percentage using a TFLite segmentation model |
| 📸 **Camera & Gallery** | Scan leaves live via camera or upload from gallery |
| ⚡ **100% Offline** | All inference runs on-device via TFLite — no cloud, no latency |
| 📋 **Scan History** | Full history of past scans with timestamps, stored locally |
| 💊 **Treatment Advice** | Automatic actionable recommendations per detected condition |
| 🌙 **Clean UI** | Material 3 design with Lottie animations and Google Fonts |
| 🌐 **Optional API Backend** | FastAPI Python server for server-side inference (optional) |

---

## 🖼️ Sample Images

> Use these images in `sample_images/` to test the app right away:

| File | Expected Result |
|---|---|
| `corn_leaf_sample.jpg` | Corn / Maize leaf |
| `tomato_early_blight.png` | Tomato — Early Blight |
| `apple_healthy_leaf.png` | Apple — Healthy |

---

## 🏗️ Project Structure

```
GreenGuard/
├── app/                          # Flutter mobile application
│   ├── lib/
│   │   ├── main.dart             # App entry point
│   │   ├── screens/              # UI screens (Home, Upload, Camera, Result, History…)
│   │   ├── services/             # Inference, API, history, theme services
│   │   ├── widgets/              # Reusable UI components
│   │   ├── theme/                # AppTheme (colors, typography)
│   │   ├── utils/                # Image preprocessing utilities
│   │   └── data/                 # Static disease data
│   ├── assets/
│   │   ├── models/               # TFLite models + labels.txt (bundled in APK)
│   │   └── images/               # App logo & UI images
│   └── pubspec.yaml              # Flutter dependencies
│
├── backend/                      # Optional FastAPI Python server
│   ├── main.py                   # API endpoints (/health, /analyze-field)
│   ├── utils/
│   │   ├── inference.py          # TFLite model loading & inference engine
│   │   └── preprocessing.py      # Image preprocessing (PIL → NumPy)
│   ├── models/                   # TFLite models for the server
│   └── requirements.txt          # Python dependencies
│
├── training/                     # Model training scripts
│   ├── train_fresh.py            # Main training script (MobileNetV2 + fine-tuning)
│   ├── prepare_datasets.py       # Dataset preparation & augmentation pipeline
│   ├── convert_to_tflite.py      # Keras H5 → TFLite converter
│   ├── utils.py                  # Shared training utilities
│   ├── labels.txt                # 46 disease class labels
│   └── requirements.txt          # Python training dependencies
│
└── sample_images/                # 3 test leaf images for quick evaluation
```

---

## 🛠️ Tech Stack

### Mobile App
| Technology | Version | Purpose |
|---|---|---|
| **Flutter** | 3.x (Dart ≥3.2) | Cross-platform mobile framework |
| **TFLite Flutter** | 0.12.0 | On-device ML inference |
| **image** | 4.1.3 | Pixel-level image preprocessing |
| **image_picker** | 1.0.4 | Camera & gallery access |
| **camera** | 0.12.0 | Live camera feed for scanning |
| **provider** | 6.1.1 | State management |
| **shared_preferences** | 2.2.2 | Local scan history persistence |
| **lottie** | 2.7.0 | Smooth loading animations |
| **google_fonts** | 6.1.0 | Typography (custom fonts) |
| **http** | 1.1.0 | Optional API communication |

### AI / ML Models
| Component | Architecture | Input | Output |
|---|---|---|---|
| **Disease Classifier** | MobileNetV2 (fine-tuned) | 224×224 RGB | 46-class softmax |
| **Weed Segmentor** | Custom CNN | 224×224 RGB | Binary mask → density % |

**Training details:**
- Dataset: PlantVillage (augmented) + custom weed images
- Augmentation: rotation 20°, zoom 0.2, horizontal flip, brightness ±20%
- Optimizer: Adam · LR: 1e-4 · Batch size: 32
- Callbacks: EarlyStopping, ReduceLROnPlateau, ModelCheckpoint

### Backend (Optional)
| Technology | Version | Purpose |
|---|---|---|
| **FastAPI** | 0.111.0 | REST API framework |
| **Uvicorn** | 0.29.0 | ASGI server |
| **TensorFlow** | 2.16.1 | Model loading & TFLite runtime |
| **Pillow** | 10.3.0 | Server-side image processing |
| **NumPy** | 1.26.4 | Tensor operations |

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** ≥ 3.2 → [Install Flutter](https://flutter.dev/docs/get-started/install)
- **Android Studio** or **Xcode** (for device/emulator)
- **Python 3.10+** (only if running the optional API backend)

---

### 1. Clone the Repository

```bash
git clone https://github.com
cd GreenGuard-AI-Crop-Detection
```

---

### 2. Run the Flutter App

```bash
cd app

# Install dependencies
flutter pub get

# Check connected devices
flutter devices

# Run on Android device or emulator
flutter run

# Or build a release APK
flutter build apk --release
```

> **Note:** The TFLite models (`assets/models/*.tflite`) are already bundled in the app. No additional download needed.

---

### 3. Run the Optional FastAPI Backend

The backend provides a REST API for server-side analysis. The Flutter app works fully offline without it.

```bash
cd backend

# Create and activate a virtual environment
python -m venv .venv

# Windows
.venv\Scripts\activate
# macOS / Linux
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Place your TFLite model files in backend/models/
# (crop_disease_model.tflite and weed_segmentation_model.tflite)

# Start the server
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

The API will be available at `http://localhost:8000`.

**API Endpoints:**
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/health` | Server health check |
| `POST` | `/analyze-field` | Upload an image for full analysis |

**Interactive docs:** `http://localhost:8000/docs` (Swagger UI)

---

### 4. Train Your Own Model (Optional)

> **Requirements:** Python 3.10+, TensorFlow 2.16, 8GB+ RAM (GPU recommended)

```bash
cd training

# Install training dependencies
pip install -r requirements.txt

# 1. Prepare the dataset
#    Download PlantVillage from Kaggle and place it in:
#    ../data/PlantVillage-Dataset/
python prepare_datasets.py

# 2. Train the classification model
python train_fresh.py

# 3. Convert the best H5 model to TFLite
python convert_to_tflite.py
```

Training outputs are saved in `training/output_fresh/`:
- `green_guard_fresh_best.h5` — best Keras model
- `green_guard_fresh.tflite` — deployable TFLite model
- `classification_report.txt` — per-class accuracy report
- `confusion_matrix.png` — visual confusion matrix
- `training_curves.png` — accuracy & loss curves

---

## 🧪 Testing with Sample Images

The `sample_images/` folder contains 3 leaf photographs:

```bash
# Using the backend API (server must be running)
curl -X POST "http://localhost:8000/analyze-field" \
  -H "accept: application/json" \
  -F "file=@sample_images/tomato_early_blight.png"
```

Expected response:
```json
{
  "weed_density": "2.14%",
  "disease_detected": "tomato___early_blight",
  "confidence": 0.9312,
  "recommendation": "Low weed density. No action needed. | Detected Early Blight on Tomato. Consider applying specific fungicide/pesticide treatments."
}
```

---

## 🌿 Supported Crops & Diseases

<details>
<summary>Click to expand — 46 classes across 15 plant species</summary>

| Plant | Conditions |
|---|---|
| **Apple** | Apple Scab, Black Rot, Cedar Apple Rust, Healthy |
| **Blueberry** | Healthy |
| **Cherry** | Healthy, Powdery Mildew |
| **Corn (Maize)** | Cercospora Leaf Spot, Common Rust, Healthy, Northern Leaf Blight |
| **Grape** | Black Rot, Esca (Black Measles), Healthy, Leaf Blight |
| **Orange** | Huanglongbing (Citrus Greening) |
| **Peach** | Bacterial Spot, Healthy |
| **Pepper (Bell)** | Bacterial Spot, Healthy |
| **Potato** | Early Blight, Healthy, Late Blight |
| **Raspberry** | Healthy |
| **Rice** | Bacterial Leaf Blight, Brown Spot, Leaf Smut |
| **Soybean** | Healthy |
| **Squash** | Powdery Mildew |
| **Strawberry** | Healthy, Leaf Scorch |
| **Tomato** | Bacterial Spot, Early Blight, Healthy, Late Blight, Leaf Mold, Septoria Leaf Spot, Spider Mites, Target Spot, Mosaic Virus, Yellow Leaf Curl Virus |
| **Wheat** | Healthy, Septoria, Stripe Rust |
| **Weed** | Broadleaf, Grass |

</details>

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgements

- [PlantVillage Dataset](https://www.kaggle.com/datasets/emmarex/plantdisease) — plant disease image dataset
- [TFLite Flutter](https://pub.dev/packages/tflite_flutter) — on-device inference
- [MobileNetV2](https://arxiv.org/abs/1801.04381) — base model architecture (Howard et al., 2018)

---

<div align="center">
Made with ❤️ and 🌱 for sustainable agriculture
</div>
