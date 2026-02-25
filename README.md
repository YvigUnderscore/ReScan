# ReScan

![ReScan Logo](https://img.shields.io/badge/ReScan-Capture-00B2FF?style=for-the-badge&logo=apple)
![Platform](https://img.shields.io/badge/iOS-17.0+-white?logo=apple)
![License](https://img.shields.io/badge/License-CC%20BY--NC%204.0-lightgrey.svg)

**ReScan** is an advanced iOS application designed for high-fidelity 3D scanning and photogrammetry. It seamlessly captures synchronized LiDAR depth data, confidence maps, camera tracking (odometry), and high-resolution RGB video. It natively exports data in the **Stray Scanner format**, making it instantly compatible with popular SfM (Structure from Motion) and Gaussian Splatting pipelines like COLMAP and DIET_SfM.

---

## ✨ Features

- **Professional Camera Controls**: 
  - Manual Exposure (Shutter Speed, ISO, EV Compensation) 
  - Manual Focus with Peaking overlay
  - Custom Capture FPS (1 to 60 FPS) via frame subsampling for efficient photogrammetry
- **High-End Video Formats**: 
  - **Apple Log (ProRes 422 HQ)** recording for maximum color grading flexibility (requires iPhone 15 Pro or newer)
  - HDR HEVC & Standard HEVC for efficient storage
- **LiDAR Integration**: Captures highly accurate 16-bit depth maps (in millimeters) and 8-bit confidence maps.
- **Odometry & Tracking**: Natively exports ARKit camera poses (`odometry.csv`) and intrinsics (`camera_matrix.csv`).
- **Real-Time Visualization**: View RGB, Depth, Confidence, and live AR Mesh overlays while capturing.
- **On-Device Mesh Export**: Reconstructs and saves the ARKit scene mesh as an `.obj` file alongside your capture.

---

## 🚀 Installation

Because ReScan uses advanced ARKit and AVFoundation capabilities, it must be sideloaded onto your iOS device using Xcode or a tool like AltStore.

### Prerequisites
- A Mac with **Xcode 15+** installed.
- An iOS device with a **LiDAR scanner** (iPhone 12 Pro or newer, iPad Pro 2020 or newer).
- iOS/iPadOS **17.0** or later.

### Build via Xcode (Free Developer Account)
1. **Clone the repository**:
   ```bash
   git clone https://github.com/YvigUnderscore/ReScan.git
   cd ReScan
   ```
2. **Open the project**: Open `ReScan.xcodeproj` (or run `xcodegen` if using the `project.yml` file to generate the project).
3. **Configure Signing**:
   - Go to the project settings by clicking the `ReScan` target.
   - Select the **Signing & Capabilities** tab.
   - Check "Automatically manage signing".
   - Select your Personal Team from the Team dropdown (you may need to sign in with your Apple ID in Xcode Settings > Accounts).
   - Change the **Bundle Identifier** to something unique (e.g., `com.yourname.ReScan`).
4. **Deploy**:
   - Connect your iPhone/iPad to your Mac via USB.
   - Select your device from the run destination menu at the top of Xcode.
   - Press **Cmd + R** (or the Play button) to build and run.
5. **Trust the Developer**:
   - On your device, go to **Settings > General > VPN & Device Management**.
   - Tap your Apple ID under "Developer App" and select "Trust".
   - The app should now launch!

*Note: With a free Apple Developer account, apps expire after 7 days and need to be re-deployed.*

---

## 📁 Output Format (Stray Scanner Compatible)

ReScan organizes each capture session into a standard Stray Scanner directory structure, located in the app's Documents folder (accessible via the iPhone's Files app under "On My iPhone" > ReScan).

```text
scan_20260225_153022/
│
├── rgb.mov                 # Or rgb.mp4 (RGB Video - ProRes/Apple Log or HEVC)
├── camera_matrix.csv       # 3x3 Camera Intrinsics
├── odometry.csv            # Camera translations and quaternions
├── mesh.obj                # Reconstructed ARKit scene mesh
│
├── depth/
│   ├── 000000.png          # 16-bit PNG (Depth in millimeters)
│   ├── 000001.png
│   └── ...
│
└── confidence/
    ├── 000000.png          # 8-bit PNG (0=Low, 127=Med, 255=High)
    ├── 000001.png
    └── ...
```

This structure is directly consumable by tools like `stray_to_colmap.py` for immediate reconstruction without complex preprocessing.

---

## ⚙️ Usage Tips for Photogrammetry

- **FPS**: 30 or 60 FPS is often overkill and creates massive datasets. Go to Settings and lower the **Capture FPS** to 2 or 5 FPS for standard scanning.
- **Color Space**: If using an iPhone 15 Pro+, enable **Apple Log (ProRes)** in settings. This flat color profile retains maximum dynamic range and avoids highlight clipping, which is crucial for high-quality Gaussian Splatting and NeRFs.
- **Exposure**: Use **Lock** exposure mode once you have a good exposure to prevent brightness shifting between frames, which can confuse feature matching algorithms.
- **Moving Speed**: Move slowly and smoothly. ARKit tracks at 30/60fps internally for stability, but motion blur from fast movement will degrade the RGB frames.

---

## 📄 License

This project is licensed under the **Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)** License.

You are free to:
- **Share** — copy and redistribute the material in any medium or format.
- **Adapt** — remix, transform, and build upon the material.

Under the following terms:
- **Attribution** — You must give appropriate credit, provide a link to the license, and indicate if changes were made.
- **NonCommercial** — You may not use the material for commercial purposes.

See the [LICENSE](LICENSE) file for more details.
