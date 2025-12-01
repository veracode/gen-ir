//
//  VersionPrinterC.m
//  TestLibraryC
//
//  Created by David Dresser on 10/21/25.
//

#import <Foundation/Foundation.h>
#import "VersionPrinterC.h"
#import "TestLibraryC.h"

@implementation VersionPrinterC
+ (void)printVersionInfoC {
    NSLog(@"Version Number TestLibraryC: %f", TestLibraryCVersionNumber);
    NSLog(@"Version String TestLibraryC: %s", TestLibraryCVersionString);
}
@end
