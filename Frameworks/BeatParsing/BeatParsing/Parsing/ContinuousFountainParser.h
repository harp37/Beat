//
//  ContinousFountainParser.h
//  Beat
//
//  Created by Hendrik Noeller on 01.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <BeatParsing/Line.h>
#import <BeatParsing/OutlineScene.h>
#import <BeatParsing/BeatDocumentSettings.h>
#import <BeatParsing/BeatExportSettings.h>
#import <BeatParsing/BeatScreenplay.h>
#import <BeatParsing/OutlineChanges.h>

@class OutlineScene;

@protocol ContinuousFountainParserDelegate <NSObject>
/// Document settings object
@property (nonatomic, readonly) BeatDocumentSettings *documentSettings;
/// This is a confusing property name, but it defines the line on which a character cue is being entered after a tab press
@property (nonatomic, readonly) Line* characterInputForLine;
/// Current selected range (ask for this only in main thead)
@property (nonatomic, readonly) NSRange selectedRange;
/// A list of disabled line types (`LineType` is an integer enum, so an index set is the fastest way to implement this)
@property (nonatomic, readonly) NSIndexSet* disabledTypes;

/// Forces reformatting at given line indices
- (void)reformatLinesAtIndices:(NSMutableIndexSet*)indices;
/// Forces any changes in parser to be reformatted in editor
- (void)applyFormatChanges;
/// Notify that the outline was changed
- (void)outlineDidUpdateWithChanges:(OutlineChanges*)changes;
/// Notify that a line was deleted
- (void)lineWasRemoved:(Line*)line;
@end

// Plugin compatibility
@protocol ContinuousFountainParserExports <JSExport>
@property (readonly) NSMutableArray<Line*>* lines;
@property (nonatomic, readonly) NSMutableArray <OutlineScene*>* outline;
@property (nonatomic, readonly) NSMutableArray *scenes;
@property (nonatomic, readonly) NSMutableArray<NSMutableDictionary<NSString*,NSArray<Line*>*>*>* titlePage;
@property (nonatomic, readonly) NSMutableDictionary *storybeats;
@property (nonatomic, readonly) bool hasTitlePage;

@property (nonatomic, readonly) OutlineChanges* outlineChanges;
@property (nonatomic, readonly) NSMutableSet *changedOutlineElements;

- (NSString*)rawText;
- (NSString*)screenplayForSaving;
- (void)parseText:(NSString*)text;
- (Line*)lineAtIndex:(NSInteger)index;
- (NSUInteger)indexOfLine:(Line*)line;
- (Line*)lineAtPosition:(NSInteger)position;
- (NSArray*)linesInRange:(NSRange)range;
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

- (Line *)lineWithUUID:(NSString *)uuid;

- (NSArray*)safeLines;

@property (nonatomic, weak) Line* boneyardAct;

@end

@interface ContinuousFountainParser : NSObject <ContinuousFountainParserExports, LineDelegate>
/// Parser delegate. Basically it's the document.
@property (nonatomic, weak) id 	<ContinuousFountainParserDelegate> delegate;
/// Every line as object
@property (atomic) NSMutableArray<Line*>* lines;
/// Contains every line that needs to be formatted once changes have been parsed.
@property (nonatomic) NSMutableIndexSet* changedIndices;
/// Document outline structure (scenes and sections)
@property (nonatomic) NSMutableArray<OutlineScene*>* outline;
/// Title page elements as a complicated array
@property (nonatomic) NSMutableArray<NSMutableDictionary<NSString*,NSArray<Line*>*>*>* titlePage;
@property (nonatomic) NSMutableDictionary <NSString*, NSMutableArray<Storybeat*>*>*storybeats;
/// Calculated property, checks if title page lines are present
@property (nonatomic) bool hasTitlePage;
/// Set `true` when a first-time parse is in process
@property (nonatomic) bool firstTime;


/// For STATIC parsing without a document
@property (nonatomic) BeatDocumentSettings *staticDocumentSettings;
/// Set `true` when the parser is not continuous
@property (nonatomic) bool staticParser;

@property (nonatomic) OutlineChanges* outlineChanges;
@property (nonatomic) NSMutableSet *changedOutlineElements;

/// Returns the assigned document settings 
- (BeatDocumentSettings*)documentSettings;

//@property (nonatomic) NSDictionary<NSUUID*, Line*>* uuidsToLines;
@property (nonatomic) NSMapTable<NSUUID*, Line*>* uuidsToLines;

+ (NSArray*)titlePageForString:(NSString*)string;

// Initialization for both CONTINUOUS and STATIC parsing
- (ContinuousFountainParser*)initWithString:(NSString*)string delegate:(id<ContinuousFountainParserDelegate>)delegate;
- (ContinuousFountainParser*)initWithString:(NSString*)string;
- (ContinuousFountainParser*)initStaticParsingWithString:(NSString*)string settings:(BeatDocumentSettings*)settings;
- (ContinuousFountainParser*)initWithString:(NSString*)string delegate:(id<ContinuousFountainParserDelegate>)delegate nonContinuous:(bool)nonContinuous;

#pragma mark - Parsing methods
/// Parses the full text
- (void)parseText:(NSString*)text;
/// Parse a change in range with given replacement string.
- (void)parseChangeInRange:(NSRange)range withString:(NSString*)string;
/// Reparses the whole document.
- (void)resetParsing;
/// Returns parsed scenes, excluding structure elements
- (NSArray*)scenes;
/// Returns the lines for given scene
- (NSArray*)linesForScene:(OutlineScene*)scene;
/// Returns the line preceding given line
- (Line*)previousLine:(Line*)line;
/// Returns the line following given line
- (Line*)nextLine:(Line*)line;
/// Reparses the given lines
- (void)correctParsesForLines:(NSArray*)lines;

/// Returns thread-safe lines
- (NSArray*)safeLines;
/// Returns thread-safe outline
- (NSArray*)safeOutline;



#pragma mark - Preprocess for printing & saving

/// Returns the raw string for the screenplay. Preprocesses some lines.
- (NSString*)screenplayForSaving;
/// Can be used for handling issues with orphaned dialogue.
- (void)ensureDialogueParsingFor:(Line*)line;

#pragma mark - Boneyard

@property (nonatomic, weak) Line* boneyardAct;


#pragma mark - Convenience Methods

/// Returns the index of given line. Uses cached results, so it's much more performant than using `indexOfObject:]`.
- (NSUInteger)indexOfLine:(Line*)line;
/// Returns the index of given line in the given array of of lines. Always use this instead of `indexOfObject:` for performance reasons.
- (NSUInteger)indexOfLine:(Line*)line lines:(NSArray<Line*>*)lines;
/// Returns the index of given scene. Uses cached results, so it's more performant than using `indexOfObject:]`.
- (NSUInteger)indexOfScene:(OutlineScene*)scene;
/// Returns the line at given position
- (Line*)lineAtPosition:(NSInteger)position;
/// Returns the index of line at this position
- (NSUInteger)lineIndexAtPosition:(NSUInteger)position;
/// Returns the scene which contains the line at given index
- (OutlineScene*)sceneAtIndex:(NSInteger)index;
/// Returns the first outline element which contains at least a part of the given range.
- (OutlineScene*)outlineElementInRange:(NSRange)range;
/// Returns all scenes in the given range (including intersecting scenes)
- (NSArray*)scenesInRange:(NSRange)range;
/// Returns all lines in the given range (including intersecting lines)
- (NSArray*)linesInRange:(NSRange)range;
/// Returns all scenes in the given section.
- (NSArray*)scenesInSection:(OutlineScene*)topSection;
/// Returns the scene with given number (note that scene numbers are strings)
- (OutlineScene*)sceneWithNumber:(NSString*)sceneNumber;
/// Returns the number of scenes  in the file (excluding other structure elements)
- (NSInteger)numberOfScenes;

/// Returns a "screenplay block" (items which beling together, such as character cues and dialogue) for the given range.
- (NSArray<Line*>*)blockForRange:(NSRange)range;
/// Returns a "screenplay block" (items which beling together, such as character cues and dialogue) for the given line,
- (NSArray<Line*>*)blockFor:(Line*)line;
/// Returns the both dual dialogue blocks for given line. Pass a pointer to `isDualDialogue` to see if the line *actually* is part of a dual dialogue block.
- (NSArray<NSArray<Line*>*>*)dualDialogueFor:(Line*)line isDualDialogue:(bool*)isDualDialogue;
/// Calculates the range for given block
- (NSRange)rangeForBlock:(NSArray<Line*>*)block;

/// Returns `NSUUID` object for each line.
- (NSArray*)lineIdentifiers:(NSArray<NSUUID*>*)lines;
/// Set `NSUUID` identifiers for lines in corresponding indices.
- (void)setIdentifiers:(NSArray*)uuids;

/// Get the line with this UUID
- (Line*)lineWithUUID:(NSString*)uuid;

@end
