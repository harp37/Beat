//
//  ContinousFountainParser.h
//  Beat
//
//  Created by Hendrik Noeller on 01.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "Line.h"
#import "OutlineScene.h"
#import "BeatDocumentSettings.h"
#import "BeatExportSettings.h"
#import "BeatScreenplay.h"

@class OutlineScene;

@protocol ContinuousFountainParserDelegate <NSObject>
@property (nonatomic) bool printSceneNumbers;
@property (atomic, readonly) BeatDocumentSettings *documentSettings;
@property (nonatomic, readonly) Line* characterInputForLine;
@property (nonatomic, readonly) NSRange selectedRange;

- (NSInteger)sceneNumberingStartsFrom;
- (void)reformatLinesAtIndices:(NSMutableIndexSet*)indices;
- (void)applyFormatChanges;

@end

// Plugin compatibility
@protocol ContinuousFountainParserExports <JSExport>
@property (readonly) NSMutableArray<Line*>* lines;
@property (nonatomic, readonly) NSMutableArray <OutlineScene*>* outline;
@property (nonatomic, readonly) NSMutableArray *scenes;
@property (nonatomic, readonly) NSMutableArray <NSDictionary<NSString*, NSArray<NSString*>*>*> *titlePage;
@property (nonatomic, readonly) NSMutableSet *storylines;
@property (nonatomic, readonly) NSMutableDictionary *storybeats;
@property (nonatomic, readonly) bool hasTitlePage;
- (NSString*)rawText;
- (NSString*)screenplayForSaving;
- (void)parseText:(NSString*)text;
- (Line*)lineAtIndex:(NSInteger)index;
- (NSUInteger)indexOfLine:(Line*)line;
- (Line*)lineAtPosition:(NSInteger)position;
- (NSArray*)linesInRange:(NSRange)range;
- (NSDictionary*)scriptForPrinting;
- (BeatScreenplay*)forPrinting;
- (NSInteger)numberOfScenes;
- (OutlineScene*)sceneAtIndex:(NSInteger)index;
- (OutlineScene*)sceneAtPosition:(NSInteger)index;
- (NSArray*)scenesInRange:(NSRange)range;
- (OutlineScene*)sceneWithNumber:(NSString*)sceneNumber;
- (NSString*)titlePageAsString;
- (NSArray<Line*>*)titlePageLines;
- (NSArray<NSDictionary<NSString*,NSArray<Line*>*>*>*)parseTitlePage;

- (Line*)previousLine:(Line*)line;
- (Line*)nextLine:(Line*)line;

- (Line*)nextOutlineItemOfType:(LineType)type from:(NSInteger)position;
- (Line*)nextOutlineItemOfType:(LineType)type from:(NSInteger)position depth:(NSInteger)depth;
- (Line*)previousOutlineItemOfType:(LineType)type from:(NSInteger)position;
- (Line*)previousOutlineItemOfType:(LineType)type from:(NSInteger)position depth:(NSInteger)depth;

@end

@protocol OutlineChangesExports <JSExport>
@property (readonly, nonatomic) NSMutableSet<OutlineScene*>* added;
@property (readonly, nonatomic) NSMutableSet<OutlineScene*>* removed;
@property (readonly, nonatomic) NSMutableSet<OutlineScene*>* updated;
@property (readonly, nonatomic) bool needsFullUpdate;
- (bool)hasChanges;
@end

@interface OutlineChanges:NSObject <NSCopying, OutlineChangesExports>
@property (nonatomic) NSMutableSet<OutlineScene*>* added;
@property (nonatomic) NSMutableSet<OutlineScene*>* removed;
@property (nonatomic) NSMutableSet<OutlineScene*>* updated;
@property (nonatomic) bool needsFullUpdate;
- (bool)hasChanges;
@end

@interface ContinuousFountainParser : NSObject <ContinuousFountainParserExports, LineDelegate>
@property (nonatomic, weak) id 	<ContinuousFountainParserDelegate> delegate; /// Parser delegate. Basically it's the document.

@property (atomic) NSMutableArray *lines; //Stores every line as an element. Multiple lines of stuff
@property (nonatomic) NSMutableIndexSet *changedIndices; //Stores every line that needs to be formatted according to the type
@property (nonatomic) NSMutableArray <OutlineScene*>* outline;
@property (nonatomic) NSMutableArray *titlePage;
@property (nonatomic) NSMutableSet *storylines;
@property (nonatomic) NSMutableDictionary <NSString*, NSMutableArray<Storybeat*>*>*storybeats;
@property (nonatomic) bool hasTitlePage;

// For STATIC parsing without a document
@property (nonatomic) BeatDocumentSettings *staticDocumentSettings;
@property (nonatomic) bool staticParser;

@property (nonatomic) NSDictionary<NSUUID*, Line*>* uuidsToLines;

+ (NSArray*)preprocessForPrintingWithLines:(NSArray*)lines printNotes:(bool)printNotes settings:(BeatDocumentSettings*)documentSettings;
+ (NSArray*)titlePageForString:(NSString*)string;

// Initialization for both CONTINUOUS and STATIC parsing
- (ContinuousFountainParser*)initWithString:(NSString*)string delegate:(id<ContinuousFountainParserDelegate>)delegate;
- (ContinuousFountainParser*)initWithString:(NSString*)string;
- (ContinuousFountainParser*)initStaticParsingWithString:(NSString*)string settings:(BeatDocumentSettings*)settings;
- (ContinuousFountainParser*)initWithString:(NSString*)string delegate:(id<ContinuousFountainParserDelegate>)delegate nonContinuous:(bool)nonContinuous;

//Parsing methods
- (void)parseText:(NSString*)text;
- (void)parseChangeInRange:(NSRange)range withString:(NSString*)string;
- (void)resetParsing;
- (void)createOutline;
- (NSArray*)outlineTree;
- (NSArray*)scenes;
- (void)ensurePositions;
- (NSArray*)linesForScene:(OutlineScene*)scene;
- (Line*)previousLine:(Line*)line;
- (Line*)nextLine:(Line*)line;
- (void)correctParsesForLines:(NSArray*)lines;

// Thread safety convenience methods
- (NSArray*)safeLines;
- (NSArray*)safeOutline;

// Preprocess for printing & saving
- (NSString*)screenplayForSaving;
- (NSArray*)preprocessForPrinting;
- (NSArray*)preprocessForPrintingPrintNotes:(bool)printNotes;

- (void)ensureDialogueParsingFor:(Line*)line;

//Convenience Methods for Other Stuff
- (NSUInteger)indexOfLine:(Line*)line;
- (Line*)lineAtPosition:(NSInteger)position;
- (NSUInteger)lineIndexAtPosition:(NSUInteger)position;
- (NSUInteger)outlineIndexAtLineIndex:(NSUInteger)index;
- (OutlineScene*)sceneAtIndex:(NSInteger)index;
- (NSArray*)scenesInRange:(NSRange)range;
- (NSArray*)linesInRange:(NSRange)range;
- (NSArray*)scenesInSection:(OutlineScene*)topSection;
- (OutlineScene*)sceneWithNumber:(NSString*)sceneNumber;

- (BeatScreenplay*)forPrinting;
- (NSInteger)numberOfScenes;
- (LineType)lineTypeAt:(NSInteger)index;

- (NSArray<Line*>*)blockForRange:(NSRange)range;
- (NSArray<Line*>*)blockFor:(Line*)line;
- (NSArray<NSArray<Line*>*>*)dualDialogueFor:(Line*)line isDualDialogue:(bool*)isDualDialogue;

- (NSArray*)lineIdentifiers:(NSArray<Line*>*)lines;
- (void)setIdentifiers:(NSArray*)uuids;

//Convenience Methods for Outlineview data
//- (BOOL)getAndResetChangeInOutline;
- (id)changesInOutline;
- (Line*)closestPrintableLineFor:(Line*)line;

- (NSString*)description;
@end
