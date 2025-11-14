//
//  VersionPrinter.m
//  TestLibraryA
//
//  Created by David Dresser on 10/21/25.
//

#import "VersionPrinter.h"
#import "TestLibraryA.h"

@implementation VersionPrinter
+ (void)printVersionInfo {
    NSLog(@"Version Number: %f", TestLibraryAVersionNumber);
    NSLog(@"Version String: %s", TestLibraryAVersionString);
    
    NSLog(@"Test LibraryB Version Info");
    [VersionPrinterB printVersionInfoB];
}
@end
