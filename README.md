#  DetectPlant: AI-Based Plant & Disease Detection

DetectPlant is a production-ready mobile application built using Flutter that leverages custom TensorFlow Lite models to identify plant species and detect leaf diseases. Designed for farmers, home gardeners, and nursery managers, it offers an offline-first experience with professional PDF reporting and multi-language support.

---

##  Key Features

- **Dual-Model AI Engine**: 
  - **Plant Identification**: Recognizes 47 common plant species.
  - **Disease Detection**: Classifies 15 different plant disease categories.
- ** Smart Camera & Gallery**: Instant capture or gallery upload for analysis.
- **Multi-Language Support**: Fully localized in 10 languages:
  -  English, Spanish, Hindi, French, Arabic, Bengali, Russian, Portuguese, Indonesian, German.
- ** Wikipedia Integration**: Automatically fetches detailed plant care and disease treatment information.
- ** Professional PDF Reports**: Generate authenticated reports with images, AI insights, risk levels, and precautions.
- ** Scan History**: Keeps a persistent local log of all scans using SQLite.
- ** Offline First**: High-performance TFLite inference works entirely without an internet connection.

---

## Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) (Material 3)
- **Deep Learning**: [TensorFlow Lite](https://www.tensorflow.org/lite)
- **State Management**: [Riverpod](https://riverpod.dev/)
- **Database**: [SQLite (sqflite)](https://pub.dev/packages/sqflite)
- **Localization**: [Easy Localization](https://pub.dev/packages/easy_localization)
- **APIs**: Wikipedia REST API
- **Reporting**: [PDF](https://pub.dev/packages/pdf) & [Printing](https://pub.dev/packages/printing)

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Stable Channel)
- Android Studio / VS Code
- Android device or Emulator

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Vishwaraj-636/DetectPlant.git
   cd DetectPlant
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Configure Assets**:
   Ensure the TFLite models and labels are in the correct directory:
   - `assets/model/plant_model_quantized.tflite`
   - `assets/model/disease_model_quantized.tflite`
   - `assets/labels/plant_labels.txt`
   - `assets/labels/disease_labels.txt`

4. **Run the app**:
   ```bash
   flutter run
   ```

---

## Project Structure

```text
lib/
├── core/
│   ├── services/       # TFLite, SQLite, Wikipedia, and PDF logic
├── features/
│   ├── dashboard/      # Main entry point UI
│   ├── scanner/        # Camera and Inference UI
│   ├── history/        # Local scan records
│   ├── reports/        # PDF management
│   └── complaints/     # User feedback
└── main.dart           # App initialization
```

---

## AI Model Details

The application uses **EfficientNetB0** based TFLite models.
- **Preprocessing**: Pass raw 0-255 float pixel values (Normalization is handled internally by the model).
- **Input Shape**: `[1, 224, 224, 3]` (Standard EfficientNet format).

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## License

Distributed under the MIT License. See `LICENSE` for more information.

---

*Developed by SwayamPani*
