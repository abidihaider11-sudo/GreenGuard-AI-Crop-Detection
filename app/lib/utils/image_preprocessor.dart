import 'dart:math';
import 'package:image/image.dart' as img;

class ImagePreprocessor {
  /// Converts RGB to HSV. Returns [H, S, V] where H is 0-360, S is 0.0-1.0, V is 0.0-1.0
  static List<double> rgbToHsv(int r, int g, int b) {
    double rNorm = r / 255.0;
    double gNorm = g / 255.0;
    double bNorm = b / 255.0;

    double cMax = [rNorm, gNorm, bNorm].reduce(max);
    double cMin = [rNorm, gNorm, bNorm].reduce(min);
    double delta = cMax - cMin;

    double h = 0.0;
    if (delta == 0) {
      h = 0.0;
    } else if (cMax == rNorm) {
      h = 60 * (((gNorm - bNorm) / delta) % 6);
    } else if (cMax == gNorm) {
      h = 60 * (((bNorm - rNorm) / delta) + 2);
    } else if (cMax == bNorm) {
      h = 60 * (((rNorm - gNorm) / delta) + 4);
    }

    if (h < 0) h += 360;

    double s = cMax == 0 ? 0 : delta / cMax;
    double v = cMax;

    return [h, s, v];
  }

  /// Preprocesses an image by isolating the largest green region and cropping.
  static img.Image preprocessImage(img.Image originalImage) {
    // 1. To prevent extremely slow Connected Components, we compute the bounding box on a downscaled version
    int downscaleMax = 300; // max width/height for fast mask computation
    img.Image maskImage;
    double scale = 1.0;

    if (originalImage.width > downscaleMax || originalImage.height > downscaleMax) {
      if (originalImage.width > originalImage.height) {
         maskImage = img.copyResize(originalImage, width: downscaleMax);
         scale = originalImage.width / downscaleMax;
      } else {
         maskImage = img.copyResize(originalImage, height: downscaleMax);
         scale = originalImage.height / downscaleMax;
      }
    } else {
      maskImage = img.copyCrop(originalImage, x: 0, y: 0, width: originalImage.width, height: originalImage.height);
    }

    // 2. HSV Masking to identify green regions on the maskImage
    List<List<bool>> isGreenMask = List.generate(maskImage.height, (y) => List.filled(maskImage.width, false));

    for (int y = 0; y < maskImage.height; y++) {
      for (int x = 0; x < maskImage.width; x++) {
        final pixel = maskImage.getPixel(x, y);
        List<double> hsv = rgbToHsv(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt());
        
        // Green HSV bounds
        if (hsv[0] >= 30 && hsv[0] <= 90 && hsv[1] >= 0.15 && hsv[2] >= 0.15) {
          isGreenMask[y][x] = true;
        }
      }
    }

    // 3. Find Largest Connected Component
    List<List<bool>> visited = List.generate(maskImage.height, (y) => List.filled(maskImage.width, false));
    int maxCCSize = 0;
    int bestMinX = 0, bestMinY = 0, bestMaxX = maskImage.width - 1, bestMaxY = maskImage.height - 1;
    bool foundAny = false;

    // Fast coordinate queue for BFS
    List<int> queue = List.filled(maskImage.width * maskImage.height, 0);

    for (int y = 0; y < maskImage.height; y++) {
      for (int x = 0; x < maskImage.width; x++) {
        if (isGreenMask[y][x] && !visited[y][x]) {
          int startIdx = 0;
          int endIdx = 0;

          queue[endIdx++] = y * maskImage.width + x;
          visited[y][x] = true;

          int ccSize = 0;
          int ccMinX = x, ccMinY = y, ccMaxX = x, ccMaxY = y;

          while (startIdx < endIdx) {
            int pos = queue[startIdx++];
            int cy = pos ~/ maskImage.width;
            int cx = pos % maskImage.width;

            ccSize++;
            if (cx < ccMinX) ccMinX = cx;
            if (cx > ccMaxX) ccMaxX = cx;
            if (cy < ccMinY) ccMinY = cy;
            if (cy > ccMaxY) ccMaxY = cy;

            if (cy > 0 && !visited[cy - 1][cx] && isGreenMask[cy - 1][cx]) {
              visited[cy - 1][cx] = true;
              queue[endIdx++] = (cy - 1) * maskImage.width + cx;
            }
            if (cy < maskImage.height - 1 && !visited[cy + 1][cx] && isGreenMask[cy + 1][cx]) {
              visited[cy + 1][cx] = true;
              queue[endIdx++] = (cy + 1) * maskImage.width + cx;
            }
            if (cx > 0 && !visited[cy][cx - 1] && isGreenMask[cy][cx - 1]) {
              visited[cy][cx - 1] = true;
              queue[endIdx++] = cy * maskImage.width + (cx - 1);
            }
            if (cx < maskImage.width - 1 && !visited[cy][cx + 1] && isGreenMask[cy][cx + 1]) {
              visited[cy][cx + 1] = true;
              queue[endIdx++] = cy * maskImage.width + (cx + 1);
            }
          }

          if (ccSize > maxCCSize) {
            maxCCSize = ccSize;
            bestMinX = ccMinX;
            bestMinY = ccMinY;
            bestMaxX = ccMaxX;
            bestMaxY = ccMaxY;
            foundAny = true;
          }
        }
      }
    }

    // 4. Scale Bounding Box back to original dimension and Crop
    int finalMinX = 0;
    int finalMinY = 0;
    int finalMaxX = originalImage.width - 1;
    int finalMaxY = originalImage.height - 1;

    if (foundAny) {
      int marginX = ((bestMaxX - bestMinX) * 0.1).toInt();
      int marginY = ((bestMaxY - bestMinY) * 0.1).toInt();

      bestMinX = max(0, bestMinX - marginX);
      bestMinY = max(0, bestMinY - marginY);
      bestMaxX = min(maskImage.width - 1, bestMaxX + marginX);
      bestMaxY = min(maskImage.height - 1, bestMaxY + marginY);

      finalMinX = (bestMinX * scale).toInt();
      finalMinY = (bestMinY * scale).toInt();
      finalMaxX = (bestMaxX * scale).toInt();
      finalMaxY = (bestMaxY * scale).toInt();
      
      finalMinX = max(0, finalMinX);
      finalMinY = max(0, finalMinY);
      finalMaxX = min(originalImage.width - 1, finalMaxX);
      finalMaxY = min(originalImage.height - 1, finalMaxY);
    }

    int cropWidth = finalMaxX - finalMinX + 1;
    int cropHeight = finalMaxY - finalMinY + 1;

    if (cropWidth <= 0 || cropHeight <= 0) {
       finalMinX = 0;
       finalMinY = 0;
       cropWidth = originalImage.width;
       cropHeight = originalImage.height;
    }

    img.Image croppedImage = img.copyCrop(originalImage, x: finalMinX, y: finalMinY, width: cropWidth, height: cropHeight);


    return croppedImage;
  }
}
