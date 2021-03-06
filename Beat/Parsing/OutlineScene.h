//
//  OutlineScene.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.2.2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ContinousFountainParser.h"
#import "Line.h"
#import <JavaScriptCore/JavaScriptCore.h>

// For the imagined scripting module
@protocol OutlineSceneExports <JSExport>
@property NSString * sceneNumber;
@property NSString * color;
@property (nonatomic) Line * line;
@property (strong, nonatomic) NSString * string;
@property NSArray * storylines;
@property NSUInteger sceneStart;
@property NSUInteger sceneLength;
@property NSInteger sectionDepth;
@property bool omited;
- (NSString*)typeAsString;
- (NSInteger)timeLength;
@end

@interface OutlineScene : NSObject <OutlineSceneExports>
@property NSMutableArray * scenes;
@property (strong, nonatomic) NSString * string;
@property LineType type;
@property NSString * sceneNumber;
@property NSString * color;
@property NSArray * storylines;
@property NSUInteger sceneStart;
@property NSUInteger sceneLength;
@property NSInteger sectionDepth;

@property bool omited;
@property bool noOmitIn;
@property bool noOmitOut;

@property (nonatomic) Line * line; // Is this overkill regarding memory? Isn't this just a pointer?

- (NSString*)stringForDisplay;
- (NSRange)range;
- (NSInteger)timeLength;
- (NSString*)typeAsString;
@end
