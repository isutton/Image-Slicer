//
//  main.m
//  Image Slicer
//
//  Created by Igor Sutton on 10/22/11.
//  Copyright (c) 2011 igorsutton.com. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

int main (int argc, const char * argv[])
{
    @autoreleasepool {
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

        if (![userDefaults objectForKey:@"TileSize"] || ![userDefaults objectForKey:@"ImagePath"]) {
            printf("Usage: %s -TileSize float -ImagePath string [-OutputPath string]\n", [[[NSProcessInfo processInfo] processName] UTF8String]);
            return 255;
        }
                
        CGFloat tileSize = [userDefaults floatForKey:@"TileSize"];
        NSString *imagePath = [userDefaults stringForKey:@"ImagePath"];
        NSString *outputPath = [userDefaults stringForKey:@"OutputPath"];
        
        if (outputPath) {
            outputPath = [NSString pathWithComponents:[NSArray arrayWithObjects:outputPath, [[[imagePath lastPathComponent] componentsSeparatedByString:@"."] objectAtIndex:0], nil]];
        }
        else {
            outputPath = [[imagePath componentsSeparatedByString:@"."] objectAtIndex:0];
        }

        BOOL isDirectory;
        if (![[NSFileManager defaultManager] fileExistsAtPath:imagePath isDirectory:&isDirectory] || isDirectory) {
            NSLog(@"Error: File '%@' either doesn't exist or is a directory.", imagePath);
            return 1;
        }
        
        NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc] initWithData:[NSData dataWithContentsOfFile:imagePath]];
        if (imageRep == nil) {
            NSLog(@"Error: Couldn't find an image representation for file '%@'", imagePath);
            return 2;
        }
        
        CGImageRef imageRef = [imageRep CGImage];
        if (imageRef == nil) {
            NSLog(@"Error: Couldn't get a CGImageRef from the image representation for file '%@'", imagePath);
            return 3;
        }
        
        // Calculate the number of columns and rows. We don't get picky about 
        // the remainders here, since we'll be using NSIntersectionRect() later
        // on to get 'em.
        int columnNr = floorf(imageRep.size.width / tileSize);
        int rowNr = floorf(imageRep.size.height / tileSize);
        
        // You guess.
        CGFloat x = 0, y = 0;
        
        for (int row = 0; row <= rowNr; row++) {
            for (int column = 0; column <= columnNr; column++) {
                
                // Build the output file path.
                NSString *tileImagePath = [NSString stringWithFormat:@"%@_%i_%i.png", outputPath, row, column];
                
                // Calculate the intersection rectangle of the big image and 
                // the tile (so we don't need to calculate the remainders 
                // ourselves).
                NSRect tileRect = NSIntersectionRect(NSMakeRect(0, 0, imageRep.size.width, imageRep.size.height), NSMakeRect(x, y, tileSize, tileSize));

                // Copy the rect we want from the original image into the tile image.
                CGImageRef tileImageRef = CGImageCreateWithImageInRect(imageRef, tileRect);
                
                // Create an Core Foundation URL from our tile image path.
                CFURLRef urlRef = (__bridge CFURLRef)[NSURL fileURLWithPath:tileImagePath];
                
                // Create a PNG image destination.
                CGImageDestinationRef tileImageDestinationRef = CGImageDestinationCreateWithURL(urlRef, kUTTypePNG, 1, NULL);
                
                // Add the tile image in the destination image.
                CGImageDestinationAddImage(tileImageDestinationRef, tileImageRef, NULL);
                
                // Finalize (write) image to destination.
                if (!CGImageDestinationFinalize(tileImageDestinationRef)) {
                    NSLog(@"Error: Failed to write image to '%@'", tileImagePath);
                }
                
                // Go to the next column's 'x' point.
                x += tileSize;
            }
            
            // Go to the next row's 'y' point and go back to the beginning of the row.
            y += tileSize, x = 0;
        }
    }
    return 0;
}

