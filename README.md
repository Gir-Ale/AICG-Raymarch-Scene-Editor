## Raymarch Scene Editor

**Demo:** **https://gir-ale.github.io/AICG-Raymarch-Scene-Editor/**

The Raymarch Scene Editor is a web application that allows users to build complex 3D structures using geometric shapes.  
You can create objects, edit their position, size, rotation, and color, and combine them dynamically with other shapes.

---

## Features

### **Real-time 3D Scene Editor**
- Choose from multiple 3D shapes to build with.  
- Full control over position, scale, rotation, and color.  
- Dynamic combination and blending between shapes.

### **Built-in Shader Editor**
- Direct access to the shader code.  
- Ability to edit the WGSL shader and recompile the scene instantly.

### **Full camera controls**
- Hold left click and move the mouse up-down, left-right to change the position on the orbit of the selected object.
- Use the scroll wheel to change the distance of the camera on the orbit.

---

## Tech Stack

The interface and controls are built using **HTML** and **JavaScript**.  
Rendering is powered by **WebGPU**, and shaders are written in **WGSL**.

---

## Local Development

To host the app locally:

1. Clone the project from GitHub.  
2. **If you are on Windows (Chrome):** run the `test.bat` file.  
3. **Otherwise:**  
   - Open a terminal in the project directory.  
   - Run:  
     python -m http.server
   - Then go to:  
     **http://localhost:8000/index.html** to access the web app.

---

<img width="670" height="600" alt="Capture d'écran 2025-11-19 174203" src="https://github.com/user-attachments/assets/c597ae45-066b-4832-9c30-8eb188752cd0" />
<img width="512" height="655" alt="Capture d&#39;écran 2025-11-28 140600" src="https://github.com/user-attachments/assets/62076e18-2d6e-4f97-ab97-a25246158985" />
