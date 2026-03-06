#!/usr/bin/env swift

// Helper script to find font PostScript names
// Run this in Xcode Playground or as a script

import CoreText

func printFontNames() {
    let fontURLs = [
        Bundle.main.url(forResource: "Inter-Bold", withExtension: "ttf"),
        Bundle.main.url(forResource: "Inter-ExtraBold", withExtension: "ttf"),
        Bundle.main.url(forResource: "Inter-Black", withExtension: "ttf"),
    ].compactMap { $0 }
    
    for fontURL in fontURLs {
        if let fontDataProvider = CGDataProvider(url: fontURL as CFURL),
           let font = CGFont(fontDataProvider) {
            if let postScriptName = font.postScriptName {
                print("Font file: \(fontURL.lastPathComponent)")
                print("PostScript name: \(postScriptName)")
                print("---")
            }
        }
    }
}

printFontNames()

