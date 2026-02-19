# How to Add a New Font to iOS Project

## Step 1: Add Font File
1. Place your font file (`.ttf` or `.otf`) in:
   ```
   Enclosure/Fonts/
   ```

## Step 2: Register in Info.plist
1. Open `Enclosure/Info.plist`
2. Find the `UIAppFonts` array
3. Add your font filename (e.g., `Inter-ExtraBold.ttf`)

Example:
```xml
<key>UIAppFonts</key>
<array>
    <string>Inter-Bold.ttf</string>
    <string>Inter-ExtraBold.ttf</string>  <!-- Add your new font here -->
    ...
</array>
```

## Step 3: Find the Font Name
After adding the font, you need to find its PostScript name. You can:
1. Use a font viewer app
2. Or I can help you find it programmatically

## Step 4: Use in Code
```swift
.font(.custom("FontPostScriptName", size: 40))
```

## Recommended: Download Inter-ExtraBold or Inter-Black
To match Android's Inter weight 700, you can download:
- Inter-ExtraBold (weight 800)
- Inter-Black (weight 900)

From: https://fonts.google.com/specimen/Inter

