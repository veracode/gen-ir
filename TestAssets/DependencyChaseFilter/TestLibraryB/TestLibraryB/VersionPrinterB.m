//
//  VersionPrinter.m
//  TestLibraryB
//
//  Created by David Dresser on 10/21/25.
//

#import "VersionPrinterB.h"
#import "TestLibraryB.h"

@implementation VersionPrinterB
+ (void)printVersionInfoB {
    NSLog(@"Version Number: %f", TestLibraryBVersionNumber);
    NSLog(@"Version String: %s", TestLibraryBVersionString);
}
@end
