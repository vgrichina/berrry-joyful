# App Store Assets Guide

Complete guide for creating all visual assets needed for Mac App Store submission.

---

## 1. App Icon (REQUIRED - CRITICAL)

The app icon is the most important visual asset. It appears in:
- Finder
- Dock
- App Store listings
- Launchpad
- System Settings

### Icon Requirements

#### Sizes Needed for macOS App Icon Set

Create an `AppIcon.appiconset` with these sizes:

| Size | Scale | File Name | Dimensions |
|------|-------|-----------|------------|
| 16pt | @1x | icon_16x16.png | 16x16 |
| 16pt | @2x | icon_16x16@2x.png | 32x32 |
| 32pt | @1x | icon_32x32.png | 32x32 |
| 32pt | @2x | icon_32x32@2x.png | 64x64 |
| 128pt | @1x | icon_128x128.png | 128x128 |
| 128pt | @2x | icon_128x128@2x.png | 256x256 |
| 256pt | @1x | icon_256x256.png | 256x256 |
| 256pt | @2x | icon_256x256@2x.png | 512x512 |
| 512pt | @1x | icon_512x512.png | 512x512 |
| 512pt | @2x | icon_512x512@2x.png | 1024x1024 |

**Master Size**: Start with 1024x1024px and scale down.

### Design Guidelines

#### Concept Ideas for berrry-joyful

**Option 1: Joy-Con Inspired**
- Stylized Joy-Con controller silhouette
- Bright colors (red/blue like Nintendo Switch)
- Minimalist, recognizable design
- Berrry Computer aesthetic integration

**Option 2: Input Fusion**
- Combined mouse + keyboard + controller icon
- Unified control metaphor
- Modern, tech-forward look

**Option 3: Mac + Joy-Con**
- macOS-style icon with Joy-Con elements
- Professional yet playful
- Appeals to Mac users specifically

#### Design Principles

1. **Simplicity**: Must be recognizable at 16x16px
2. **No Text**: Avoid text in icon (hard to read at small sizes)
3. **Distinct Shape**: Unique silhouette that stands out
4. **Color**: Use 2-3 vibrant colors max
5. **No Transparency**: Fill the entire icon space
6. **Rounded Corners**: macOS automatically applies rounded corners
7. **Consistent Style**: Match Berrry Computer branding

### Technical Specifications

- **Format**: PNG (no transparency) or PDF (vector)
- **Color Space**: sRGB or Display P3
- **Compression**: PNG-24 recommended
- **Background**: Should not be transparent
- **Grid System**: Use icon grid template for alignment

### Tools for Creating Icons

**Recommended**:
- **SF Symbols** (free, by Apple) - for macOS-style icons
- **Sketch** - industry standard for Mac icon design
- **Figma** (free tier available) - web-based design tool
- **Pixelmator Pro** - affordable Mac graphics app
- **Adobe Illustrator** - professional vector graphics

**Icon Generators**:
- **Image2Icon** (Mac app) - converts images to .icns
- **Icon Slate** (Mac app) - icon set generator
- Online: **MakeAppIcon.com** - generates all sizes from 1024x1024

### Creating the Icon Set

#### Method 1: Using Xcode Asset Catalog (Recommended)

1. Create folder: `Sources/Assets.xcassets/AppIcon.appiconset/`
2. Add all PNG files following naming convention
3. Create `Contents.json`:

```json
{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

4. Update `project.yml`:
```yaml
sources:
  - Sources
  - path: Sources/Assets.xcassets
    type: folder
```

5. Run `xcodegen` to regenerate project

#### Method 2: Using .icns File

1. Generate `AppIcon.icns` using icon creation tool
2. Add to project in `Sources/` directory
3. Update `Info.plist`:
```xml
<key>CFBundleIconFile</key>
<string>AppIcon</string>
```

### Testing Your Icon

1. Build the app
2. Check icon in Finder
3. Verify icon in Dock when app is running
4. Test at different macOS display scales
5. View in both light and dark mode

---

## 2. App Store Screenshots (REQUIRED - Minimum 3)

Screenshots showcase your app's features in App Store Connect.

### Screenshot Requirements

**Dimensions**:
- **1280 x 800** (recommended minimum)
- **2560 x 1600** (Retina, recommended)
- **Aspect Ratio**: 16:10

**Format**:
- JPEG or PNG
- Maximum file size: 500 KB per image (compress if needed)

**Quantity**:
- Minimum: 3 screenshots
- Maximum: 10 screenshots

### What to Capture

#### Screenshot 1: Main Interface with Controller Connected
**Focus**: First impression of the app
- Show the main tabbed UI
- Controller status "Connected" with battery level
- Clean, organized layout
- Caption: "Modern tabbed interface with real-time controller status"

#### Screenshot 2: Mouse Control in Action
**Focus**: Primary feature demonstration
- Show mouse tab with sensitivity settings
- Demonstrate cursor movement or precision mode
- Include visual indicators of Joy-Con input
- Caption: "Precise mouse control with adjustable sensitivity"

#### Screenshot 3: Keyboard Configuration
**Focus**: Customization capabilities
- Keyboard tab showing button mappings
- Profile selection or custom layout
- Clear display of button assignments
- Caption: "Customizable keyboard layouts for different workflows"

#### Screenshot 4: Voice Input Feature (Optional)
**Focus**: Unique voice-to-text capability
- Voice tab with "Listening..." status
- Show transcription example
- Microphone indicator active
- Caption: "Voice-to-text input by holding ZL+ZR"

#### Screenshot 5: Debug Log View (Optional)
**Focus**: Developer-friendly features
- Debug log expanded showing events
- Demonstrates transparency and troubleshooting
- Caption: "Built-in debug log for monitoring controller events"

### Capturing Screenshots

#### Method 1: Built-in macOS Screenshot Tool

1. Run berrry-joyful in Release build
2. Connect Joy-Con controller
3. Navigate to desired view/tab
4. Press **Cmd+Shift+4** → **Space** → Click window
5. Screenshot saved to Desktop

#### Method 2: Xcode Simulator (if applicable)

Not applicable for berrry-joyful (requires actual Joy-Con hardware)

#### Method 3: Manual Capture and Resize

```bash
# Take screenshot
screencapture -w screenshot.png

# Resize to App Store dimensions using sips
sips -z 1600 2560 screenshot.png
```

### Enhancing Screenshots

**Optional Enhancements**:
- Add subtle drop shadow for depth
- Include descriptive captions overlaid on image
- Show cursor position or Joy-Con button states
- Add color highlights to draw attention to features
- Use annotation tools (Annotate, Skitch, Pixelmator)

**Do NOT**:
- Add misleading information
- Show features not in the app
- Use screenshots from different apps
- Include copyrighted content

### Screenshot Composition Tips

1. **Clean Background**: Minimize distractions, solid desktop background
2. **Proper Lighting Mode**: Test both light and dark mode
3. **Readable Text**: Ensure all UI text is legible
4. **Representative**: Show actual app usage, not staged scenarios
5. **Progression**: Order screenshots to tell a story (onboarding → usage → advanced)

---

## 3. App Preview Video (OPTIONAL - Highly Recommended)

A short video demonstrating your app in action.

### Video Requirements

**Technical Specs**:
- Format: .mov, .m4v, .mp4
- Resolution: 1920x1080 or higher
- Duration: 15-30 seconds (max 30 seconds)
- Frame Rate: 24-30 fps
- Audio: Optional (can include music or voiceover)

### Video Content Ideas

**30-Second Demo Structure**:
1. **0-5s**: Show Joy-Con connecting to Mac
2. **5-15s**: Demonstrate mouse movement and clicking
3. **15-22s**: Show keyboard input and shortcuts
4. **22-28s**: Demonstrate voice input (ZL+ZR)
5. **28-30s**: Show app logo/name with tagline

### Recording the Video

#### Using QuickTime Player

1. Open QuickTime Player
2. File → New Screen Recording
3. Select recording area or full screen
4. Record app usage with Joy-Con
5. Edit down to 30 seconds
6. Export as 1080p .mov

#### Using ScreenFlow or Camtasia

Professional screencasting tools with editing capabilities.

#### Tips for Great App Preview Videos

- Use smooth, deliberate movements
- Show real usage, not sped up or staged
- Add subtle background music (royalty-free)
- Include brief text overlays explaining features
- End with app icon and name
- Keep it short and engaging

---

## 4. Marketing Assets (For Website/Social Media)

### App Store Badge

Download official "Download on the Mac App Store" badge:
- Visit: https://developer.apple.com/app-store/marketing/guidelines/
- Available in multiple languages
- Use correct size and spacing guidelines

### Social Media Graphics

**Twitter/X Card**: 1200x630px
**Facebook Share**: 1200x630px
**Instagram Post**: 1080x1080px
**LinkedIn Post**: 1200x627px

**Content Ideas**:
- App icon + tagline
- Feature highlights
- Screenshot showcases
- "Now available on Mac App Store" announcement

### Press Kit

Create a simple press kit including:
- High-resolution app icon (1024x1024)
- App screenshots (2560x1600)
- App description (short and long versions)
- Company logo (Berrry Computer)
- Contact information
- Link to privacy policy
- Link to GitHub repository

---

## 5. Asset Checklist

### Must Have (Required for Submission)
- [ ] App icon (all sizes: 16x16 to 1024x1024)
- [ ] At least 3 App Store screenshots (1280x800 or larger)
- [ ] App description text (written, ready to paste)
- [ ] Keywords (100 character limit)
- [ ] Privacy policy URL (hosted online)
- [ ] Support URL

### Should Have (Highly Recommended)
- [ ] 5-7 high-quality screenshots showing all major features
- [ ] App preview video (15-30 seconds)
- [ ] Promotional text (170 characters)
- [ ] "What's New" text for version 1.0
- [ ] App Store badge graphics for marketing

### Nice to Have
- [ ] Social media graphics
- [ ] Press kit
- [ ] Landing page with screenshots
- [ ] Demo video (longer than 30s for website)
- [ ] Animated GIFs for documentation

---

## 6. Tools Reference

### Icon Design
- SF Symbols (free, Apple)
- Figma (free tier)
- Sketch (paid)
- Pixelmator Pro (one-time purchase)
- Image2Icon (icon converter)

### Screenshot Capture
- macOS built-in (Cmd+Shift+4)
- CleanShot X (enhanced screenshots)
- Xnapper (screenshot beautifier)

### Video Recording
- QuickTime Player (free, built-in)
- ScreenFlow (paid)
- OBS Studio (free)

### Image Editing
- Preview (built-in)
- Pixelmator Pro
- Photoshop
- GIMP (free)

### Compression
- ImageOptim (free, Mac)
- TinyPNG (online)
- sips (command-line, built-in)

---

## 7. Asset Directory Structure

Recommended folder structure for all assets:

```
AppStoreAssets/
├── Icon/
│   ├── AppIcon.appiconset/
│   │   ├── icon_16x16.png
│   │   ├── icon_16x16@2x.png
│   │   ├── ...
│   │   └── Contents.json
│   ├── icon_1024.png (master)
│   └── icon_mockups/ (optional)
├── Screenshots/
│   ├── 01_main_interface.png (2560x1600)
│   ├── 02_mouse_control.png
│   ├── 03_keyboard_config.png
│   ├── 04_voice_input.png
│   └── 05_debug_log.png
├── Video/
│   ├── app_preview.mov (30s)
│   └── demo_video.mov (longer version)
├── Marketing/
│   ├── social/
│   │   ├── twitter_card.png
│   │   ├── facebook_share.png
│   │   └── instagram_post.png
│   ├── badges/
│   │   └── mac_app_store_badge.svg
│   └── press_kit/
│       ├── press_release.txt
│       └── assets/
└── README.md (this guide)
```

---

## Next Steps

1. **Design app icon** - Start with 1024x1024 master file
2. **Generate icon set** - Create all required sizes
3. **Capture screenshots** - Take 5-7 high-quality screenshots
4. **Record demo video** (optional but recommended)
5. **Compress assets** - Ensure screenshots are under 500 KB
6. **Organize in folder** - Use structure above
7. **Test icon in build** - Verify icon appears correctly
8. **Upload to App Store Connect** - Add screenshots and video

---

**Pro Tip**: Create all assets before starting the App Store Connect submission process. Having everything ready makes the submission process much faster and smoother.
