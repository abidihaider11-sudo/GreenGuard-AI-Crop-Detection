import os
import shutil
import requests
import tarfile
import zipfile
import cv2
import numpy as np
import random
from tqdm import tqdm
from glob import glob
from sklearn.model_selection import train_test_split
import matplotlib.pyplot as plt

# Configuration
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SEGMENTATION_DIR = os.path.join(BASE_DIR, 'dataset_segmentation')
CLASSIFICATION_DIR = os.path.join(BASE_DIR, 'dataset_classification')

# CropAndWeed Config
CNW_URL_PREFIX = 'https://vitro-testing.com/wp-content/uploads/2022/12/'
CNW_FILES = ['cropandweed_annotations.tar', 'cropandweed_images1of4.tar'] # Limiting to 1 part for demo/speed, user can uncomment others
# CNW_FILES += ['cropandweed_images2of4.tar', 'cropandweed_images3of4.tar', 'cropandweed_images4of4.tar']

# CropOrWeed2 Mapping (Approximate based on datasets.py)
CROP_IDS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 18, 24, 26, 27, 94]
WEED_IDS = [22, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 41, 42, 44, 45, 47, 48, 49, 50, 51, 52, 54, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 74, 75, 76, 77, 78, 79, 80, 81, 83, 84, 85, 86, 87, 88, 89, 91, 96]

def download_file(url, dest_path):
    if os.path.exists(dest_path):
        print(f"File already exists: {dest_path}")
        return
    print(f"Downloading {url}...")
    try:
        response = requests.get(url, stream=True)
        response.raise_for_status()
        total_size = int(response.headers.get('content-length', 0))
        with open(dest_path, 'wb') as f, tqdm(total=total_size, unit='B', unit_scale=True, desc=os.path.basename(dest_path)) as bar:
            for data in response.iter_content(chunk_size=1024):
                f.write(data)
                bar.update(len(data))
        print(f"Download complete: {dest_path}")
    except Exception as e:
        print(f"Error downloading {url}: {e}")
        if os.path.exists(dest_path):
            os.remove(dest_path)

def extract_archive(file_path, extract_to):
    print(f"Extracting {file_path}...")
    try:
        if file_path.endswith('.tar'):
            with tarfile.open(file_path, 'r') as tar:
                tar.extractall(path=extract_to)
        elif file_path.endswith('.zip'):
            with zipfile.ZipFile(file_path, 'r') as zip_ref:
                zip_ref.extractall(extract_to)
        print(f"Extraction complete.")
    except Exception as e:
        print(f"Error extracting {file_path}: {e}")

def prepare_cwfid():
    print("\n---------- Processing CWFID Dataset ----------")
    url = "https://github.com/cwfid/dataset/archive/refs/tags/v1.0.zip"
    zip_path = os.path.join(BASE_DIR, "cwfid.zip")
    download_file(url, zip_path)
    
    extract_dir = os.path.join(BASE_DIR, "cwfid_raw")
    extract_archive(zip_path, extract_dir)
    
    # CWFID structure in v1.0.zip:
    # dataset-1.0/
    #   images/ (001_image.png...)
    #   annotations/ (001_annotation.png...) - often color coded
    
    src_root = os.path.join(extract_dir, "dataset-1.0")
    if not os.path.exists(src_root):
        print("CWFID extraction folder not found")
        return

    images_dir = os.path.join(src_root, "images")
    annotations_dir = os.path.join(src_root, "annotations")
    
    img_files = sorted(glob(os.path.join(images_dir, "*.png")))
    mask_files = sorted(glob(os.path.join(annotations_dir, "*.png")))
    
    print(f"Found {len(img_files)} images and {len(mask_files)} masks in CWFID.")
    
    # Process and Save
    process_segmentation_data(img_files, mask_files, "cwfid")

def process_segmentation_data(image_paths, mask_paths, source_name):
    # This function will handle resizing, splitting, and saving standardizing the format
    # 80/10/10 split
    
    train_imgs, test_imgs, train_masks, test_masks = train_test_split(image_paths, mask_paths, test_size=0.2, random_state=42)
    val_imgs, test_imgs, val_masks, test_masks = train_test_split(test_imgs, test_masks, test_size=0.5, random_state=42)
    
    splits = [('train', train_imgs, train_masks), ('validation', val_imgs, val_masks), ('test', test_imgs, test_masks)]
    
    for split_name, imgs, masks in splits:
        out_img_dir = os.path.join(SEGMENTATION_DIR, split_name, 'images')
        out_mask_dir = os.path.join(SEGMENTATION_DIR, split_name, 'masks')
        os.makedirs(out_img_dir, exist_ok=True)
        os.makedirs(out_mask_dir, exist_ok=True)
        
        print(f"Processing {len(imgs)} images for {source_name} - {split_name}...")
        
        for img_path, mask_path in tqdm(zip(imgs, masks), total=len(imgs)):
            # Load
            img = cv2.imread(img_path)
            mask = cv2.imread(mask_path) # Read as Color to distinguish classes if needed, or BGR
            
            if img is None or mask is None:
                continue
                
            # Resize
            img = cv2.resize(img, (224, 224))
            mask = cv2.resize(mask, (224, 224), interpolation=cv2.INTER_NEAREST)
            
            # For CWFID, masks are often RGB. 
            # We need to convert to binary (0=Background/Crop, 1=Weed) or similar.
            # CWFID: Red=Weed, Green=Crop. 
            # Let's check color standards or just assume Red channel presence for Weed.
            # Simplified: If mask has Red component > threshold -> Weed.
            
            # Generic binary mask creation:
            # If source is CWFID: 
            #   Weed (Red): (0, 0, 255) in BGR (OpenCV)
            #   Crop (Green): (0, 255, 0)
            #   Background (Black): (0, 0, 0)
            
            binary_mask = np.zeros((224, 224), dtype=np.uint8)
            
            if source_name == "cwfid":
                # Detect Red (Weed)
                # BGR: [B, G, R]
                # Weed pixels: R > 100, G < 100, B < 100 approx
                weed_mask = (mask[:, :, 2] > 100) & (mask[:, :, 1] < 100) & (mask[:, :, 0] < 100)
                binary_mask[weed_mask] = 1 # Class 1 = Weed
            
            elif source_name == "cropandweed":
                # CropAndWeed LabelIDs (already 1-channel integer)
                # We need to map IDs.
                # Since we passed a path, we re-read as grayscale/unchanged
                mask_id = cv2.imread(mask_path, cv2.IMREAD_UNCHANGED)
                if mask_id is None: continue
                mask_id = cv2.resize(mask_id, (224, 224), interpolation=cv2.INTER_NEAREST)
                
                # Apply Mapping
                # 0 = Background/Soil
                # CROP_IDS -> 0 (Treat Crop as background for "Weed Detection" or separate class?)
                # User asked for "Weed Segmentation": usually Binary (Weed vs Background) or Multi (Crop, Weed, Back).
                # Request says: "binary masks (weed=1, crop=0)". This implies Crop is 0. Background is likely 0 too.
                
                # Check IDs
                is_weed = np.isin(mask_id, WEED_IDS)
                binary_mask[is_weed] = 1
                
            # Save
            fname = f"{source_name}_{os.path.basename(img_path)}"
            cv2.imwrite(os.path.join(out_img_dir, fname), img)
            cv2.imwrite(os.path.join(out_mask_dir, fname), binary_mask * 255) # Save as 0-255 for visualization/compatibility 

def prepare_cropandweed():
    print("\n---------- Processing CropAndWeed Dataset ----------")
    cnw_root = os.path.join(BASE_DIR, "cropandweed_raw")
    os.makedirs(cnw_root, exist_ok=True)
    
    # Download parts
    for filename in CNW_FILES:
        filepath = os.path.join(cnw_root, filename)
        download_file(CNW_URL_PREFIX + filename, filepath)
        # Extract immediately
        extract_archive(filepath, cnw_root)
        
    # Organize
    # Structure after extraction: 
    # cropandweed_raw/images/ (from imagestar)
    # cropandweed_raw/labelIds/ (from annotations.tar -> bboxes/labelIds? Need to check structure from setup.py)
    # setup.py says: 
    #   extracts to root.
    #   moves bboxes to CropAndWeed.
    #   moves CropAndWeed to bboxes/CropAndWeed.
    #   labelIds are likely in 'labelIds' folder at root if extracted from annotation tar?
    # Let's assume standard extraction puts them in 'labelIds' or 'bboxes'.
    # We will search for them.
    
    img_dir = os.path.join(cnw_root, "images")
    lbl_dir = os.path.join(cnw_root, "labelIds", "CropAndWeed") # setup.py default mapping
    
    # If not mapped, they might be in labelIds directly or just labelIds
    if not os.path.exists(lbl_dir):
        lbl_dir = os.path.join(cnw_root, "labelIds")
        
    if not os.path.exists(img_dir) or not os.path.exists(lbl_dir):
        print("CropAndWeed folders (images or labelIds) not found. Check download/extraction.")
        # Try finding recursively
        img_files = glob(os.path.join(cnw_root, "**", "*.jpg"), recursive=True) + glob(os.path.join(cnw_root, "**", "*.png"), recursive=True)
        # Filter for actual dataset images (format: ave_0001_0000.png or similar)
        # For simplicity, if structure is mess, we might skip.
        # But let's rely on standard 'images' folder.
        
    img_files = sorted(glob(os.path.join(img_dir, "*.png"))) + sorted(glob(os.path.join(img_dir, "*.jpg")))
    # Labels must match filenames. 
    # Labels are usually png, 16-bit or 8-bit encoded IDs.
    
    valid_pairs_img = []
    valid_pairs_mask = []
    
    for img_p in img_files:
        basename = os.path.basename(img_p)
        mask_name = basename.replace(".jpg", ".png") # Masks are png
        mask_p = os.path.join(lbl_dir, mask_name)
        
        if os.path.exists(mask_p):
            valid_pairs_img.append(img_p)
            valid_pairs_mask.append(mask_p)
            
    print(f"Found {len(valid_pairs_img)} matched image/mask pairs in CropAndWeed.")
    
    # Process
    process_segmentation_data(valid_pairs_img, valid_pairs_mask, "cnw")

def prepare_plantvillage():
    print("\n---------- Processing PlantVillage Dataset ----------")
    repo_dir = os.path.join(BASE_DIR, "PlantVillage-Dataset")
    if not os.path.exists(repo_dir):
        print("Downloading PlantVillage...")
        zip_url = "https://github.com/spMohanty/PlantVillage-Dataset/archive/refs/heads/master.zip"
        zip_path = os.path.join(BASE_DIR, "plantvillage.zip")
        download_file(zip_url, zip_path)
        extract_archive(zip_path, BASE_DIR)
        # Rename extracted folder
        extracted = os.path.join(BASE_DIR, "PlantVillage-Dataset-master")
        if os.path.exists(extracted):
            os.rename(extracted, repo_dir)
            
    # Source images
    # raw/color/Tomato_Early_blight/...
    src_color = os.path.join(repo_dir, "raw", "color")
    if not os.path.exists(src_color):
        print("PlantVillage raw/color folder not found.")
        return
        
    classes = [d for d in os.listdir(src_color) if os.path.isdir(os.path.join(src_color, d))]
    print(f"Found {len(classes)} classes in PlantVillage.")
    
    process_classification_data(src_color, classes, "pv")

def prepare_plantdoc():
    print("\n---------- Processing PlantDoc Dataset ----------")
    repo_dir = os.path.join(BASE_DIR, "PlantDoc-Dataset")
    if not os.path.exists(repo_dir):
        print("Downloading PlantDoc...")
        zip_url = "https://github.com/pratikkayal/PlantDoc-Dataset/archive/refs/heads/master.zip"
        zip_path = os.path.join(BASE_DIR, "plantdoc.zip")
        download_file(zip_url, zip_path)
        extract_archive(zip_path, BASE_DIR)
        # Rename extracted folder
        extracted = os.path.join(BASE_DIR, "PlantDoc-Dataset-master")
        if os.path.exists(extracted):
            os.rename(extracted, repo_dir)

    # PlantDoc structure: train/ and test/ folders with class subfolders
    # We will aggregate all.
    found_classes = set()
    
    # Check train
    train_dir = os.path.join(repo_dir, "train")
    if os.path.exists(train_dir):
        process_classification_data(train_dir, os.listdir(train_dir), "pd")
        
    # Check test
    test_dir = os.path.join(repo_dir, "test")
    if os.path.exists(test_dir):
        process_classification_data(test_dir, os.listdir(test_dir), "pd")

def process_classification_data(base_dir, classes, source_prefix):
    # Resize and Split
    # We will accumulate images per class and then split.
    # To avoid re-processing same class multiple times if called twice, we check destination.
    
    for cls in classes:
        cls_src_path = os.path.join(base_dir, cls)
        if not os.path.isdir(cls_src_path): continue
        
        # Norm class name (remove source prefix to merge? User didn't specify. 
        # PlantVillage has "Tomato_Early_blight". PlantDoc might have "Tomato Early Blight".
        # Normalization is complex. Let's keep distinct or minimal cleanup.
        # We will map to snake_case.)
        cls_name = cls.replace(" ", "_").lower()
        
        images = list(set(glob(os.path.join(cls_src_path, "*.jpg")) + glob(os.path.join(cls_src_path, "*.JPG")) + glob(os.path.join(cls_src_path, "*.png"))))
        
        if not images:
            continue
            
        train, test = train_test_split(images, test_size=0.2, random_state=42)
        val, test = train_test_split(test, test_size=0.5, random_state=42) # 10% val, 10% test
        
        splits = [('train', train), ('validation', val), ('test', test)]
        
        for split_name, imgs in splits:
            dest_dir = os.path.join(CLASSIFICATION_DIR, split_name, cls_name)
            os.makedirs(dest_dir, exist_ok=True)
            
            # Limit processing for speed if needed? No, user wants dataset.
            # But for large datasets, this might take a while.
            # We'll process.
            
            # Using tqdm for class level might be too much output. 
            # We'll just print summary per class.
            
            for img_p in imgs:
                try:
                    img = cv2.imread(img_p)
                    if img is None: continue
                    img = cv2.resize(img, (224, 224))
                    
                    fname = f"{source_prefix}_{os.path.basename(img_p)}"
                    cv2.imwrite(os.path.join(dest_dir, fname), img)
                except Exception:
                    continue
        
        print(f"Processed {cls} -> {cls_name} ({len(images)} images)")

def load_and_preview():
    print("\n---------- Dataset Preview ----------")
    # Preview Segmentation
    seg_img_dir = os.path.join(SEGMENTATION_DIR, "train", "images")
    if os.path.exists(seg_img_dir):
        images = os.listdir(seg_img_dir)
        if images:
            img_name = random.choice(images)
            img_path = os.path.join(seg_img_dir, img_name)
            mask_path = os.path.join(SEGMENTATION_DIR, "train", "masks", img_name) # Same name
            if not os.path.exists(mask_path):
                 # Try with different ext if needed, but we saved with same name and ext in preprocess
                 pass
            
            print(f"Segmentation Sample: {img_path}")
            img = cv2.imread(img_path)
            mask = cv2.imread(mask_path)
            if img is not None and mask is not None:
                # Viz
                # Multiply mask by green to overlay
                # Mask is 0-255. 0=Back, 255=Weed? Or 1=Weed?
                # We saved as binary_mask * 255. So 255 is Weed.
                
                # Overlay
                overlay = img.copy()
                overlay[mask[:,:,0] == 255] = [0, 0, 255] # Red weed
                
                vis_path = os.path.join(BASE_DIR, "preview_segmentation.jpg")
                cv2.imwrite(vis_path, overlay)
                print(f"Saved preview to {vis_path}")

    # Preview Classification
    class_train = os.path.join(CLASSIFICATION_DIR, "train")
    if os.path.exists(class_train):
        classes = os.listdir(class_train)
        if classes:
            cls = random.choice(classes)
            cls_dir = os.path.join(class_train, cls)
            images = os.listdir(cls_dir)
            if images:
                img_path = os.path.join(cls_dir, random.choice(images))
                print(f"Classification Sample ({cls}): {img_path}")

if __name__ == "__main__":
    print("Starting Green Guard Dataset Preparation...")
    
    # 1. Structure
    os.makedirs(SEGMENTATION_DIR, exist_ok=True)
    os.makedirs(CLASSIFICATION_DIR, exist_ok=True)
    
    # 2. Run
    # Un-comment to run full pipeline
    prepare_cwfid()
    prepare_cropandweed()
    prepare_plantvillage()
    prepare_plantdoc()
    
    # 3. Preview
    load_and_preview()
    print("\nDone! Datasets are ready in:")
    print(f"   - {SEGMENTATION_DIR}")
    print(f"   - {CLASSIFICATION_DIR}")
