# WirelessConnect 📱⚡️

A lightning-fast, wireless screen mirroring and Android device management tool for macOS and Windows. Experience zero-latency screen mirroring with seamless wireless debugging.

<!-- Add your hero screenshot here -->
![WirelessConnect App](docs/images/hero_image.png)

## 🚀 Features
- **Ultra-Low Latency Mirroring**: Uses `scrcpy` under the hood with hardware acceleration (H.265) for 60fps real-time mirroring.
- **Wireless ADB Setup**: Connect to your Android device over Wi-Fi without dealing with terminal commands.
- **Instant Screenshots**: Capture device screens directly to your computer's clipboard with one click.
- **Cross-Platform**: Works flawlessly on both macOS and Windows.

---

## 📥 Installation Guide

### For macOS Users
1. **Install Prerequisites**: You need `adb` and `scrcpy` installed on your Mac. Open Terminal and run:
   ```bash
   brew install android-platform-tools scrcpy
   ```
2. **Download the App**: Go to the [Releases](../../releases) tab and download `WirelessConnect-macOS.zip`.
3. **Install**: Extract the `.zip` file and drag `wirelessconnect.app` into your **Applications** folder.
4. **Run**: Double click to open. *(If you see a security warning, right-click the app and select 'Open')*.

### For Windows Users
1. **Install Prerequisites**: 
   - Download the latest [Scrcpy for Windows (includes ADB)](https://github.com/Genymobile/scrcpy/releases).
   - Extract it and add the folder path to your Windows Environment Variables (`PATH`).
2. **Download the App**: Go to the [Releases](../../releases) tab and download `WirelessConnect-Windows.zip`.
3. **Install & Run**: Extract the folder and double-click `wirelessconnect.exe` to launch the app.

---

## 🛠️ How to Connect Your Phone (Wireless Debugging)

To connect your phone to the app for the first time, follow these steps:

**Step 1: Enable Wireless Debugging on Phone**
- Go to Phone **Settings** > **Developer Options**.
- Turn on **Wireless Debugging**.

<!-- Upload an image showing developer options on phone -->
![Enable Wireless Debugging](docs/images/step1_dev_options.png)

**Step 2: Pair Device**
- In Wireless Debugging settings, tap **"Pair device with pairing code"**.
- Open the **WirelessConnect** app on your computer, click **"+"** or **"Pair New Device"**.
- Enter the **IP Address**, **Port**, and the **6-digit Pairing Code** shown on your phone.

<!-- Upload an image showing the pairing screen in the app with an arrow pointing to the add button -->
![Pair Device](docs/images/step2_pairing.png)

**Step 3: Connect & Mirror**
- Once paired, your device will appear in the sidebar. 
- Click the **Connect** icon next to it.
- Click **"Open Live Screen"** to start the ultra-fast 60fps mirror!

<!-- Upload an image showing the connected state and the Open Live Screen button -->
![Live Screen](docs/images/step3_live_screen.png)

---

## 💡 Troubleshooting
- **Live Screen not opening?** Make sure `scrcpy` is correctly installed and accessible in your system's PATH.
- **Connection failed?** Ensure both your computer and phone are connected to the **same Wi-Fi network**.

## 📝 License
This project is open-source and available under the [MIT License](LICENSE).
# wirelessconnector
