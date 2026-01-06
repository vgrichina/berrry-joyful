#!/bin/bash

# Generate berrry-joyful app icon
# This script creates a berry + Joy-Con themed icon using ImageMagick or sips

# Check if we need to create the SVG template
if [ ! -f "icon_placeholder.svg" ]; then
    echo "Creating SVG template..."
    cat > icon_placeholder.svg << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg width="1024" height="1024" xmlns="http://www.w3.org/2000/svg">
  <!-- Berry gradient background -->
  <defs>
    <radialGradient id="berryGrad" cx="50%" cy="50%" r="50%">
      <stop offset="0%" style="stop-color:#E91E63;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#880E4F;stop-opacity:1" />
    </radialGradient>
  </defs>

  <!-- Main berry circle -->
  <circle cx="512" cy="512" r="480" fill="url(#berryGrad)"/>

  <!-- Joy-Con L (simplified blue representation) -->
  <rect x="200" y="300" width="180" height="424" rx="40" fill="#0A9EDC" opacity="0.9"/>
  <circle cx="290" cy="420" r="35" fill="#1E1E1E" opacity="0.5"/>

  <!-- Joy-Con R (simplified red representation) -->
  <rect x="644" y="300" width="180" height="424" rx="40" fill="#FF3E3E" opacity="0.9"/>
  <circle cx="734" cy="600" r="35" fill="#1E1E1E" opacity="0.5"/>

  <!-- Highlight for depth -->
  <ellipse cx="512" cy="300" rx="300" ry="150" fill="white" opacity="0.15"/>
</svg>
EOF
fi

# Convert SVG to PNG
echo "Converting SVG to PNG..."
if command -v qlmanage &> /dev/null; then
    # Use Quick Look to convert (macOS built-in)
    qlmanage -t -s 1024 -o . icon_placeholder.svg 2>/dev/null
    mv icon_placeholder.svg.png icon_1024.png 2>/dev/null || {
        echo "Quick Look conversion failed"
        exit 1
    }
else
    echo "Error: qlmanage not found. Cannot convert SVG."
    exit 1
fi

# Create iconset directory
mkdir -p AppIcon.iconset

# Generate all required sizes
sips -z 16 16     icon_1024.png --out AppIcon.iconset/icon_16x16.png
sips -z 32 32     icon_1024.png --out AppIcon.iconset/icon_16x16@2x.png
sips -z 32 32     icon_1024.png --out AppIcon.iconset/icon_32x32.png
sips -z 64 64     icon_1024.png --out AppIcon.iconset/icon_32x32@2x.png
sips -z 128 128   icon_1024.png --out AppIcon.iconset/icon_128x128.png
sips -z 256 256   icon_1024.png --out AppIcon.iconset/icon_128x128@2x.png
sips -z 256 256   icon_1024.png --out AppIcon.iconset/icon_256x256.png
sips -z 512 512   icon_1024.png --out AppIcon.iconset/icon_256x256@2x.png
sips -z 512 512   icon_1024.png --out AppIcon.iconset/icon_512x512.png
sips -z 1024 1024 icon_1024.png --out AppIcon.iconset/icon_512x512@2x.png

# Create .icns file directly in Sources directory
iconutil -c icns AppIcon.iconset -o ../Sources/berrry-joyful.icns

echo "✓ Icon created: ../Sources/berrry-joyful.icns"
echo ""
echo "Icon is ready for build. Run xcodegen and rebuild the app."
