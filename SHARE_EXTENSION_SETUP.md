# Share Extension Setup Guide

This guide explains how to set up the Share Extension for receiving shared content from other iOS apps.

## Steps to Add Share Extension

1. **Open Xcode Project**
   - Open `Enclosure.xcodeproj` in Xcode

2. **Add Share Extension Target**
   - Go to File → New → Target
   - Select "Share Extension" under iOS → Application Extension
   - Name it "EnclosureShareExtension"
   - Language: Swift
   - Click "Finish"

3. **Configure Share Extension Info.plist**
   - Open `EnclosureShareExtension/Info.plist`
   - Add the following to support all file types:
   ```xml
   <key>NSExtension</key>
   <dict>
       <key>NSExtensionAttributes</key>
       <dict>
           <key>NSExtensionActivationRule</key>
           <dict>
               <key>NSExtensionActivationSupportsImageWithMaxCount</key>
               <integer>50</integer>
               <key>NSExtensionActivationSupportsMovieWithMaxCount</key>
               <integer>50</integer>
               <key>NSExtensionActivationSupportsFileWithMaxCount</key>
               <integer>50</integer>
               <key>NSExtensionActivationSupportsText</key>
               <true/>
               <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
               <integer>1</integer>
           </dict>
       </dict>
       <key>NSExtensionPointIdentifier</key>
       <string>com.apple.share-services</string>
       <key>NSExtensionPrincipalClass</key>
       <string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
   </dict>
   ```

4. **Replace ShareViewController.swift**
   - Replace the default ShareViewController with the code from `EnclosureShareExtension/ShareViewController.swift` (to be created)

5. **Add Files to Extension Target**
   - Add `SharedContentHandler.swift` to the Share Extension target
   - Add `ShareExternalDataScreen.swift` and `ShareExternalDataContactScreen.swift` if needed
   - Add any required models and utilities

6. **Configure App Groups (Optional)**
   - Enable App Groups capability for both main app and extension
   - Use same group identifier (e.g., `group.com.enclosure`)

## Testing

1. Build and run the app
2. Share content from Photos, Files, or other apps
3. Select "Enclosure" from the share sheet
4. The Share Extension should open and process the shared content
