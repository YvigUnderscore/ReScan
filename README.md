# ReScan

![ReScan Logo](https://img.shields.io/badge/ReScan-Capture-00B2FF?style=for-the-badge&logo=apple)
![Platform](https://img.shields.io/badge/iOS-17.0+-white?logo=apple)
![License](https://img.shields.io/badge/License-CC%20BY--NC%204.0-lightgrey.svg)

**ReScan** is an advanced iOS application designed for high-fidelity 3D scanning and photogrammetry. It seamlessly captures synchronized LiDAR depth data, confidence maps, camera tracking (odometry), and high-resolution RGB video. It natively exports data in the **Stray Scanner format**, making it instantly compatible with popular SfM (Structure from Motion) and Gaussian Splatting pipelines like COLMAP/GLOMAP. 

## **Check our SfM using SOTA technologies like Hloc, Glomap, Lightglue, etc** -> https://github.com/YvigUnderscore/ReMap.

---

## ✨ Features

- **Professional Camera Controls**: 
  - Manual Exposure (Shutter Speed, ISO, EV Compensation) 
  - Manual Focus.
  - Custom Capture FPS (1 to 60 FPS) via frame subsampling for efficient photogrammetry (Datas are recorded at 60 FPS and then subsampled during the recording process)
- **High-End Video Formats**: 
  - **Apple Log (ProRes 422 HQ)** recording for maximum color grading flexibility (requires iPhone 15 Pro or newer)
  - HDR HEVC & Standard HEVC for efficient storage
- **LiDAR Integration**: Captures highly accurate 16-bit depth maps (in millimeters) and 8-bit confidence maps.
- **Odometry & Tracking**: Natively exports ARKit camera poses (`odometry.csv`) and intrinsics (`camera_matrix.csv`).
- **Real-Time Visualization**: View RGB, Depth, Confidence, and live AR Mesh overlays while capturing.
- **On-Device Mesh Export**: Reconstructs and saves the ARKit scene mesh as an `.obj` file alongside your capture.

---

## 🚀 Installation

ReScan uses advanced ARKit and AVFoundation capabilities, so it must be sideloaded onto your iOS device.

To make things **extremely easy and turnkey**, we provide automated installation scripts to set up AltStore and sideload the app on Windows and Linux. 
(Linux Autoinstaller might be broken, please follow manual installation & sideload using SideStore & iloader https://github.com/nab138/iloader)

### Prerequisites
- An iOS device with a **LiDAR scanner** (iPhone 12 Pro or newer, iPad Pro 2020 or newer).
- iOS/iPadOS **17.0** or later.
- The `ReScan.ipa` file (download from Releases or build yourself).

---

### Best method: Turnkey Installation (Windows & Linux)
Please look for SideStore, it is much easier that my previous attempt --> https://github.com/SideStore/SideStore

---

### Method 2: Build via Xcode (Mac / Developers)
If you are on a Mac, you can easily deploy it using Xcode (Free Developer Account):
1. **Clone the repository**: `git clone https://github.com/YvigUnderscore/ReScan.git`
2. Generate `ReScan.xcodeproj`. (`brew install xcodegen` then `xcodegen generate`) thanks @NgVThangBz for the tip !
3. **Open**: `ReScan.xcodeproj`.
4. **Configure Signing**: In the Project settings -> Target `ReScan` -> Signing & Capabilities, select your Personal Team and change the Bundle Identifier.
5. **Deploy**: Connect your iPhone, hit **Cmd + R** to run.
6. **Trust the Developer**: On your device, go to **Settings > General > VPN & Device Management**, tap your Apple ID and select "Trust".

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

This structure is directly consumable by tools like ReMap or even `stray_to_colmap.py` for immediate reconstruction without complex preprocessing.

---

## ⚙️ Usage Tips for Photogrammetry

- **FPS**: 30 or 60 FPS is often overkill and creates massive datasets. Go to Settings and lower the **Capture FPS** to 2 or 5 FPS for standard scanning.
- **Color Space**: If using an iPhone 15 Pro+, enable **Apple Log (ProRes)** in settings. This flat color profile retains maximum dynamic range and avoids highlight clipping, which is crucial for high-quality Gaussian Splatting and NeRFs.
- **Exposure**: Use **Lock** exposure mode once you have a good exposure to prevent brightness shifting between frames, which can confuse feature matching algorithms.
- **Moving Speed**: Move slowly and smoothly. ARKit tracks at 30/60fps internally for stability, but motion blur from fast movement will degrade the RGB frames.

---

## 📄 License

**1. Output Data (Your Captures):**
You own 100% of the data you capture (videos, point clouds, meshes, depth maps, etc.). You are absolutely free to use, modify, distribute, and **commercialize** any output data generated by ReScan without any restrictions or royalties.

**2. The Software (Source Code):**
The ReScan application source code itself is licensed under the **Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)** License.

You are free to:
- **Share** — copy and redistribute the code in any medium or format.
- **Adapt** — remix, transform, and build upon the code.

Under the following terms:
- **NonCommercial** — You may not use the source code or the application for commercial purposes (e.g., integrating it into a paid product or SaaS).
- **Commercial Usage** — If you wish to use the ReScan source code in a commercial capacity, you must obtain prior written consent from the author.

See the [LICENSE](LICENSE) file for the full text and explicit data exemption clause.
