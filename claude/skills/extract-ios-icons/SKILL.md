---
name: extract-ios-icons
description: Extract app icons (alternate and primary) from an iOS IPA file as PNG and macOS .icns files. Use when the user wants to extract icons from an IPA, get custom app icons from an iOS app, convert iOS icons to macOS icns format, or apply iOS icons to a macOS app. If no IPA is provided, guides the user through obtaining one via Apple Configurator 2 with an automated cache watcher.
---

# Extract iOS App Icons from IPA

Extracts all app icons (primary + alternates) from an iOS `.ipa` file, outputting both 1024x1024 PNGs and macOS `.icns` files.

## Prerequisites

- macOS with Xcode command line tools installed (for `clang`, `sips`, `iconutil`)
- An `.ipa` file (see "Obtaining an IPA" below if user doesn't have one)

## Step 1: Obtain the IPA (if not provided)

If the user doesn't have an IPA file, guide them through Apple Configurator 2:

1. Install **Apple Configurator 2** from the Mac App Store (free)
2. Connect iPhone via USB
3. **Before starting the download**, launch a background watcher that copies the IPA before the cache is cleaned:

```bash
# The cache directory — IPA files appear here temporarily during app transfer
CACHE_DIR="$HOME/Library/Group Containers/K36BKF7T3D.group.com.apple.configurator/Library/Caches/Assets/TemporaryItems/MobileApps"
mkdir -p "$CACHE_DIR"

# Watcher loop — polls every 0.5s, copies first .ipa found to Desktop
while true; do
  ipa=$(find "$CACHE_DIR" -name "*.ipa" 2>/dev/null | head -1)
  if [ -n "$ipa" ]; then
    cp "$ipa" ~/Desktop/app.ipa
    echo "SUCCESS: Copied IPA to ~/Desktop/app.ipa"
    break
  fi
  sleep 0.5
done
```

4. In Apple Configurator 2: right-click device → **Add** → **Apps** → search for the app
5. The watcher will capture the IPA before the cache is purged

**Important**: Run the watcher as a background task so it doesn't block. The cache is cleaned immediately after transfer completes.

## Step 2: Extract the IPA

```bash
mkdir -p /tmp/ios-app-extract
unzip -o <path-to-ipa> -d /tmp/ios-app-extract
```

The app bundle is at `Payload/<AppName>.app/`.

## Step 3: Identify icon names from Info.plist

```bash
plutil -p /tmp/ios-app-extract/Payload/*.app/Info.plist | grep -A 50 -i "icon"
```

Look for `CFBundleAlternateIcons` entries — each key is an alternate icon name. The primary icon is under `CFBundlePrimaryIcon > CFBundleIconName`.

## Step 4: Inspect Assets.car

```bash
assetutil --info /tmp/ios-app-extract/Payload/*.app/Assets.car > /tmp/assets-info.json
```

Filter for icon entries to confirm names and sizes (look for 1024x1024 entries).

## Step 5: Extract icons from Assets.car

iOS icons live inside `Assets.car` (compiled asset catalog). Standard tools can't extract individual images. Use this Objective-C program that calls the private `CoreUI` framework:

Write this to `/tmp/extract_car_icons.m`:

```objc
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <objc/runtime.h>

@interface CUICatalog : NSObject
- (instancetype)initWithURL:(NSURL *)url error:(NSError **)error;
- (NSArray<NSString *> *)allImageNames;
- (NSArray *)imagesWithName:(NSString *)name;
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc < 3) {
            NSLog(@"Usage: extract_car_icons <Assets.car path> <output directory> [icon1 icon2 ...]");
            NSLog(@"If no icon names given, extracts ALL images.");
            return 1;
        }

        NSString *carPath = [NSString stringWithUTF8String:argv[1]];
        NSString *outputDir = [NSString stringWithUTF8String:argv[2]];

        // Collect specific icon names if provided
        NSMutableSet *requestedNames = nil;
        if (argc > 3) {
            requestedNames = [NSMutableSet set];
            for (int i = 3; i < argc; i++) {
                [requestedNames addObject:[NSString stringWithUTF8String:argv[i]]];
            }
        }

        NSFileManager *fm = [NSFileManager defaultManager];
        [fm createDirectoryAtPath:outputDir withIntermediateDirectories:YES attributes:nil error:nil];

        NSError *error = nil;
        CUICatalog *catalog = [[CUICatalog alloc] initWithURL:[NSURL fileURLWithPath:carPath] error:&error];
        if (!catalog) {
            NSLog(@"Failed to open catalog: %@", error);
            return 1;
        }

        NSArray *allNames = [catalog allImageNames];
        NSLog(@"Total assets in catalog: %lu", (unsigned long)allNames.count);

        int extracted = 0;
        for (NSString *name in allNames) {
            if (requestedNames && ![requestedNames containsObject:name]) continue;

            @try {
                NSArray *images = [catalog imagesWithName:name];
                CGImageRef bestImage = NULL;
                NSUInteger bestSize = 0;

                for (id img in images) {
                    CGImageRef cgImage = NULL;
                    SEL imgSel = NSSelectorFromString(@"image");
                    if ([img respondsToSelector:imgSel]) {
                        cgImage = (__bridge CGImageRef)[img performSelector:imgSel];
                    }
                    if (!cgImage) {
                        SEL unslicedSel = NSSelectorFromString(@"unslicedImage");
                        if ([img respondsToSelector:unslicedSel]) {
                            cgImage = (__bridge CGImageRef)[img performSelector:unslicedSel];
                        }
                    }
                    if (cgImage) {
                        NSUInteger w = CGImageGetWidth(cgImage);
                        if (w > bestSize) {
                            bestSize = w;
                            bestImage = cgImage;
                        }
                    }
                }

                if (bestImage && bestSize >= 120) {
                    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:bestImage];
                    NSData *pngData = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
                    if (pngData) {
                        NSString *outPath = [NSString stringWithFormat:@"%@/%@.png", outputDir, name];
                        [pngData writeToFile:outPath atomically:YES];
                        NSLog(@"Extracted: %@ (%lux%lu)", name, (unsigned long)bestSize, (unsigned long)CGImageGetHeight(bestImage));
                        extracted++;
                    }
                }
            } @catch (NSException *e) {
                NSLog(@"Error extracting %@: %@", name, e);
            }
        }

        NSLog(@"Done! Extracted %d icons to %@", extracted, outputDir);
    }
    return 0;
}
```

Compile and run:

```bash
clang -framework Foundation -framework AppKit -framework CoreUI \
  -F /System/Library/PrivateFrameworks \
  -o /tmp/extract_car_icons /tmp/extract_car_icons.m

# Extract specific icons (pass names from Info.plist):
/tmp/extract_car_icons /tmp/ios-app-extract/Payload/*.app/Assets.car /tmp/extracted-icons icon-name-1 icon-name-2

# Or extract ALL images:
/tmp/extract_car_icons /tmp/ios-app-extract/Payload/*.app/Assets.car /tmp/extracted-icons
```

### Key gotcha: CUICatalog API

- `initWithURL:error:` is an **instance** method (use `alloc` + `init`), NOT a class method
- `imagesWithName:` returns an array of renditions at different sizes/scales — iterate and pick the largest
- Get the CGImage via the `image` property, falling back to `unslicedImage` selector
- The `enumerateNamedLookupImagesUsingBlock:` selector does NOT exist on modern macOS — use `imagesWithName:` instead

## Step 6: Apply macOS icon shape mask

iOS icons are full-bleed squares. macOS icons need the proper squircle shape per Apple HIG:
- **824×824** icon shape centered on **1024×1024** canvas (100px gutter on each side)
- **185.4px** corner radius using **continuous-curvature** bezier curves (not circular arcs)
- **Drop shadow**: 28px blur, 12px Y-offset downward, black at 50% opacity

The shape uses Apple's exact continuous rounded rectangle bezier path (reverse-engineered by [Liam Rosenfeld](https://liamrosenfeld.com/posts/apple_icon_quest/) with zero pixel error vs Apple's implementation).

Write this to `/tmp/apply_macos_mask.m`:

```objc
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>

// Apple's continuous rounded rectangle bezier path
// Constants from https://liamrosenfeld.com/posts/apple_icon_quest/
// Matches UIBezierPath(roundedRect:cornerRadius:) exactly
static CGPathRef createContinuousRoundedRect(CGRect rect, CGFloat cornerRadius) {
    #define TL(xm, ym) CGPointMake(rect.origin.x + (xm) * cornerRadius, rect.origin.y + (ym) * cornerRadius)
    #define TR(xm, ym) CGPointMake(rect.origin.x + rect.size.width - (xm) * cornerRadius, rect.origin.y + (ym) * cornerRadius)
    #define BR(xm, ym) CGPointMake(rect.origin.x + rect.size.width - (xm) * cornerRadius, rect.origin.y + rect.size.height - (ym) * cornerRadius)
    #define BL(xm, ym) CGPointMake(rect.origin.x + (xm) * cornerRadius, rect.origin.y + rect.size.height - (ym) * cornerRadius)

    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, TL(1.528665, 0.0).x, TL(1.528665, 0.0).y);
    CGPathAddLineToPoint(path, NULL, TR(1.528665, 0.0).x, TR(1.528665, 0.0).y);
    CGPathAddCurveToPoint(path, NULL,
        TR(1.08849296, 0.0).x, TR(1.08849296, 0.0).y,
        TR(0.86840694, 0.0).x, TR(0.86840694, 0.0).y,
        TR(0.63149379, 0.07491139).x, TR(0.63149379, 0.07491139).y);
    CGPathAddLineToPoint(path, NULL, TR(0.63149379, 0.07491139).x, TR(0.63149379, 0.07491139).y);
    CGPathAddCurveToPoint(path, NULL,
        TR(0.37282383, 0.16905956).x, TR(0.37282383, 0.16905956).y,
        TR(0.16905956, 0.37282383).x, TR(0.16905956, 0.37282383).y,
        TR(0.07491139, 0.63149379).x, TR(0.07491139, 0.63149379).y);
    CGPathAddCurveToPoint(path, NULL,
        TR(0.0, 0.86840694).x, TR(0.0, 0.86840694).y,
        TR(0.0, 1.08849296).x, TR(0.0, 1.08849296).y,
        TR(0.0, 1.52866498).x, TR(0.0, 1.52866498).y);
    CGPathAddLineToPoint(path, NULL, BR(0.0, 1.528665).x, BR(0.0, 1.528665).y);
    CGPathAddCurveToPoint(path, NULL,
        BR(0.0, 1.08849296).x, BR(0.0, 1.08849296).y,
        BR(0.0, 0.86840694).x, BR(0.0, 0.86840694).y,
        BR(0.07491139, 0.63149379).x, BR(0.07491139, 0.63149379).y);
    CGPathAddLineToPoint(path, NULL, BR(0.07491139, 0.63149379).x, BR(0.07491139, 0.63149379).y);
    CGPathAddCurveToPoint(path, NULL,
        BR(0.16905956, 0.37282383).x, BR(0.16905956, 0.37282383).y,
        BR(0.37282383, 0.16905956).x, BR(0.37282383, 0.16905956).y,
        BR(0.63149379, 0.07491139).x, BR(0.63149379, 0.07491139).y);
    CGPathAddCurveToPoint(path, NULL,
        BR(0.86840694, 0.0).x, BR(0.86840694, 0.0).y,
        BR(1.08849296, 0.0).x, BR(1.08849296, 0.0).y,
        BR(1.52866498, 0.0).x, BR(1.52866498, 0.0).y);
    CGPathAddLineToPoint(path, NULL, BL(1.528665, 0.0).x, BL(1.528665, 0.0).y);
    CGPathAddCurveToPoint(path, NULL,
        BL(1.08849296, 0.0).x, BL(1.08849296, 0.0).y,
        BL(0.86840694, 0.0).x, BL(0.86840694, 0.0).y,
        BL(0.63149379, 0.07491139).x, BL(0.63149379, 0.07491139).y);
    CGPathAddLineToPoint(path, NULL, BL(0.63149379, 0.07491139).x, BL(0.63149379, 0.07491139).y);
    CGPathAddCurveToPoint(path, NULL,
        BL(0.37282383, 0.16905956).x, BL(0.37282383, 0.16905956).y,
        BL(0.16905956, 0.37282383).x, BL(0.16905956, 0.37282383).y,
        BL(0.07491139, 0.63149379).x, BL(0.07491139, 0.63149379).y);
    CGPathAddCurveToPoint(path, NULL,
        BL(0.0, 0.86840694).x, BL(0.0, 0.86840694).y,
        BL(0.0, 1.08849296).x, BL(0.0, 1.08849296).y,
        BL(0.0, 1.52866498).x, BL(0.0, 1.52866498).y);
    CGPathAddLineToPoint(path, NULL, TL(0.0, 1.528665).x, TL(0.0, 1.528665).y);
    CGPathAddCurveToPoint(path, NULL,
        TL(0.0, 1.08849296).x, TL(0.0, 1.08849296).y,
        TL(0.0, 0.86840694).x, TL(0.0, 0.86840694).y,
        TL(0.07491139, 0.63149379).x, TL(0.07491139, 0.63149379).y);
    CGPathAddLineToPoint(path, NULL, TL(0.07491139, 0.63149379).x, TL(0.07491139, 0.63149379).y);
    CGPathAddCurveToPoint(path, NULL,
        TL(0.16905956, 0.37282383).x, TL(0.16905956, 0.37282383).y,
        TL(0.37282383, 0.16905956).x, TL(0.37282383, 0.16905956).y,
        TL(0.63149379, 0.07491139).x, TL(0.63149379, 0.07491139).y);
    CGPathAddCurveToPoint(path, NULL,
        TL(0.86840694, 0.0).x, TL(0.86840694, 0.0).y,
        TL(1.08849296, 0.0).x, TL(1.08849296, 0.0).y,
        TL(1.52866498, 0.0).x, TL(1.52866498, 0.0).y);
    CGPathCloseSubpath(path);

    #undef TL
    #undef TR
    #undef BR
    #undef BL
    return path;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc < 3) {
            NSLog(@"Usage: apply_macos_mask <input_dir> <output_dir>");
            return 1;
        }
        NSString *inputDir = [NSString stringWithUTF8String:argv[1]];
        NSString *outputDir = [NSString stringWithUTF8String:argv[2]];
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm createDirectoryAtPath:outputDir withIntermediateDirectories:YES attributes:nil error:nil];

        // Apple HIG macOS icon grid specs
        CGFloat canvasSize = 1024.0, shapeSize = 824.0;
        CGFloat gutter = (canvasSize - shapeSize) / 2.0; // 100px
        CGFloat cornerRad = 185.4;
        CGFloat shadowBlur = 28.0, shadowOffsetY = 12.0, shadowAlpha = 0.50;

        CGRect shapeRect = CGRectMake(gutter, gutter, shapeSize, shapeSize);
        CGPathRef iconPath = createContinuousRoundedRect(shapeRect, cornerRad);
        NSArray *files = [fm contentsOfDirectoryAtPath:inputDir error:nil];

        for (NSString *file in files) {
            if (![file hasSuffix:@".png"]) continue;
            NSString *inputPath = [inputDir stringByAppendingPathComponent:file];
            NSString *outputPath = [outputDir stringByAppendingPathComponent:file];

            CGDataProviderRef provider = CGDataProviderCreateWithFilename([inputPath UTF8String]);
            if (!provider) continue;
            CGImageRef srcImage = CGImageCreateWithPNGDataProvider(provider, NULL, true, kCGRenderingIntentDefault);
            CGDataProviderRelease(provider);
            if (!srcImage) continue;

            CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
            CGContextRef ctx = CGBitmapContextCreate(NULL, (size_t)canvasSize, (size_t)canvasSize,
                8, 0, cs, kCGImageAlphaPremultipliedLast);
            CGColorSpaceRelease(cs);
            CGContextClearRect(ctx, CGRectMake(0, 0, canvasSize, canvasSize));

            // Draw drop shadow
            CGContextSaveGState(ctx);
            CGFloat sc[] = {0,0,0, shadowAlpha};
            CGColorSpaceRef scs = CGColorSpaceCreateDeviceRGB();
            CGColorRef shadowColor = CGColorCreate(scs, sc);
            CGColorSpaceRelease(scs);
            CGContextSetShadowWithColor(ctx, CGSizeMake(0, -shadowOffsetY), shadowBlur, shadowColor);
            CGColorRelease(shadowColor);
            CGContextAddPath(ctx, iconPath);
            CGContextSetRGBFillColor(ctx, 1, 1, 1, 1);
            CGContextFillPath(ctx);
            CGContextRestoreGState(ctx);

            // Clip to shape and draw icon artwork
            CGContextSaveGState(ctx);
            CGContextAddPath(ctx, iconPath);
            CGContextClip(ctx);
            CGContextDrawImage(ctx, shapeRect, srcImage);
            CGContextRestoreGState(ctx);
            CGImageRelease(srcImage);

            // Write output
            CGImageRef out = CGBitmapContextCreateImage(ctx);
            CFURLRef outURL = CFURLCreateWithFileSystemPath(NULL,
                (__bridge CFStringRef)outputPath, kCFURLPOSIXPathStyle, false);
            CGImageDestinationRef dest = CGImageDestinationCreateWithURL(outURL, kUTTypePNG, 1, NULL);
            CGImageDestinationAddImage(dest, out, NULL);
            CGImageDestinationFinalize(dest);
            CFRelease(dest); CFRelease(outURL);
            CGImageRelease(out); CGContextRelease(ctx);
            NSLog(@"Masked: %@", file);
        }
        CGPathRelease(iconPath);
    }
    return 0;
}
```

Compile and run:

```bash
clang -framework Foundation -framework AppKit -framework CoreGraphics \
  -framework ImageIO -framework CoreServices \
  -o /tmp/apply_macos_mask /tmp/apply_macos_mask.m

/tmp/apply_macos_mask /tmp/extracted-icons /tmp/masked-icons
```

### Key specs (Apple HIG)

- **DO NOT** use a simple superellipse or `CGPathCreateWithRoundedRect` — these produce the wrong curve
- The shape uses Apple's **continuous-curvature** bezier path with 7 specific constants
- The 100px gutter is required — the icon art must NOT fill the full 1024 canvas
- The drop shadow is part of the icon spec and helps it match native macOS icons

## Step 7: Convert masked PNGs to .icns

```bash
for png in /tmp/masked-icons/*.png; do
    name=$(basename "$png" .png)
    iconset="/tmp/iconsets/${name}.iconset"
    mkdir -p "$iconset"
    sips -z 16 16     "$png" --out "$iconset/icon_16x16.png"      >/dev/null 2>&1
    sips -z 32 32     "$png" --out "$iconset/icon_16x16@2x.png"   >/dev/null 2>&1
    sips -z 32 32     "$png" --out "$iconset/icon_32x32.png"      >/dev/null 2>&1
    sips -z 64 64     "$png" --out "$iconset/icon_32x32@2x.png"   >/dev/null 2>&1
    sips -z 128 128   "$png" --out "$iconset/icon_128x128.png"    >/dev/null 2>&1
    sips -z 256 256   "$png" --out "$iconset/icon_128x128@2x.png" >/dev/null 2>&1
    sips -z 256 256   "$png" --out "$iconset/icon_256x256.png"    >/dev/null 2>&1
    sips -z 512 512   "$png" --out "$iconset/icon_256x256@2x.png" >/dev/null 2>&1
    sips -z 512 512   "$png" --out "$iconset/icon_512x512.png"    >/dev/null 2>&1
    sips -z 1024 1024 "$png" --out "$iconset/icon_512x512@2x.png" >/dev/null 2>&1
    iconutil --convert icns "$iconset" -o "$OUTPUT_DIR/${name}.icns"
    rm -rf "$iconset"
done
```

## Step 8: Apply icon to a macOS app

**Finder method (recommended — preserves code signing):**
1. Right-click the `.app` in `/Applications` → **Get Info**
2. Drag the `.icns` file onto the icon in the top-left corner of the info window
3. If Dock doesn't update: `killall Dock`

**To revert:** Get Info → click the icon → press Delete.

## Output structure

```
~/Desktop/app-icons/
├── png/          # macOS-masked 1024x1024 PNGs (squircle + shadow)
│   ├── icon-name-1.png
│   └── icon-name-2.png
└── icns/         # macOS .icns (all sizes 16-1024)
    ├── icon-name-1.icns
    └── icon-name-2.icns
```
