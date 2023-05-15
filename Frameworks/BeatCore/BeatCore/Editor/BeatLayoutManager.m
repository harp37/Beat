//
//  BeatLayoutManager.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.2.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatLayoutManager.h"
#import <BeatCore/BeatCore.h>
#import <BeatThemes/BeatThemes.h>
#import <BeatCore/BeatCore-Swift.h>
#import <BeatCore/BeatMeasure.h>

//#import "BeatTextView.h"
//#import "BeatMeasure.h"
//#import "Beat-Swift.h"
#import "BeatRevisions.h"

@interface BeatLayoutManager()
@property (nonatomic) NSMutableParagraphStyle* _Nullable markerStyle;
@property (nonatomic) NSMutableParagraphStyle* _Nullable sceneNumberStyle;
@end

#if TARGET_OS_IOS
#define BXPoint CGPoint
#define BXRectFill UIRectFill
#define BXBezierPath UIBezierPath
#else
#define BXPoint NSPoint
#define BXRectFill NSRectFill
#define BXBezierPath NSBezierPath
#endif

#if TARGET_OS_IOS
    #define rectNumberValue(s) [NSValue valueWithCGRect:rect]
    #define getRectValue CGRectValue
#else
    #define rectNumberValue(s) [NSValue valueWithRect:rect]
    #define getRectValue rectValue
#endif

@implementation BeatLayoutManager

@dynamic delegate;

- (instancetype)initWithDelegate:(id<BeatEditorDelegate>)editorDelegate
{
	self = [super init];
	if (self) {
		_editorDelegate = editorDelegate;
	}
	return self;
}

- (void)drawGlyphsForGlyphRange:(NSRange)glyphsToShow atPoint:(BXPoint)origin
{
	if (_markerStyle == nil) {
		_markerStyle = NSMutableParagraphStyle.new;
		_markerStyle.minimumLineHeight = self.editorDelegate.editorLineHeight;
	}

	[super drawGlyphsForGlyphRange:glyphsToShow atPoint:origin];
    
    CGSize inset = [self offsetSize];
	NSRange charRange = [self characterRangeForGlyphRange:glyphsToShow actualGlyphRange:nil];


    /*
     // This is an idea for unifying the attribute enumeration.
     // Performance gain is minimal or non-existent, but if we
     // combine some caching with this, it could be very quick.
     
     static NSMutableSet* representedLines;
     static NSRange previousCharRange;
     static NSRange previousSelectedRange;
     
     if (NSEqualRanges(charRange, previousCharRange) && NSEqualRanges(previousSelectedRange, self.editorDelegate.selectedRange) && representedLines.count > 0) {
         // We can use cached results
     }

     if (representedLines == nil) representedLines = NSMutableSet.new;
     [representedLines removeAllObjects];
     
     NSTextContainer* textContainer = self.textContainers.firstObject;
     BXTextView* textView = self.editorDelegate.getTextView;
     
     NSArray<NSString*>* shownRevisions = BeatRevisions.revisionColors;
     NSMutableDictionary<NSString*, NSMutableSet<NSValue*>*> *revisions = NSMutableDictionary.new;
     for (NSString *string in BeatRevisions.revisionColors) revisions[string] = NSMutableSet.new;
     
    [BeatMeasure start:@"New"];
    [self.textStorage enumerateAttributesInRange:charRange options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
        NSRange glyphRange = [self glyphRangeForCharacterRange:range actualCharacterRange:nil];
        
        // Store revision marker positions (we'll draw these later, after we've enumerated the whole range)
        BeatRevisionItem* item = attrs[BeatRevisions.attributeKey];
        if (item != nil && (item.type == RevisionAddition || item.type == RevisionCharacterRemoved) && [shownRevisions containsObject:item.colorName]) {

            CGRect boundingRect = [self boundingRectForGlyphRange:glyphRange inTextContainer:textContainer];
            CGRect rect = CGRectMake(inset.width + _editorDelegate.documentWidth - 22,
                                     inset.height + boundingRect.origin.y,
                                     22,
                                     boundingRect.size.height + 1.0);
            
            // Add the marker to dictionary:
            // dict["colorName"][] -> rect
            [revisions[item.colorName] addObject:rectNumberValue(rect)];
        }
        
        // Check that we haven't handled this line yet for line-specific graphics
        // (scene number, marker, etc)
        if (attrs[@"representedLine"] != nil && ![representedLines containsObject:attrs[@"representedLine"]]) {
            Line* line = attrs[@"representedLine"];
            
            // Do nothing if this line is not a marker or a heading
            if (line.markerRange.length == 0 && line.type != heading && line.beats.count == 0) return;
            
            [representedLines addObject:line];
            
            // Get range for the first character. For headings and markers we won't need anything else.
            NSRange r = NSMakeRange(line.position, 1);
            if (self.editorDelegate.hideFountainMarkup) {
                // If the editor hides Fountain markup, there's a chance that the line is hidden (if using a formatting character, ie. ".INT. SOMETHING"
                if (line.length > 1) r.location += 1;
                else r = line.range;
            }
            
            NSRange lineRange = [self glyphRangeForCharacterRange:r actualCharacterRange:nil];
            CGRect boundingRect = [self boundingRectForGlyphRange:lineRange inTextContainer:textContainer];

            // Actual rect position
            CGRect rect = CGRectMake(inset.width + boundingRect.origin.x, inset.height + boundingRect.origin.y, boundingRect.size.width, boundingRect.size.height);
            
            // Draw scene numbers
            if (line.type == heading) {
                [self drawSceneNumberForLine:line rect:rect inset:inset];
            }
            
            // Draw markers
            if (line.markerRange.length > 0) {
                [self drawMarkerForLine:line rect:rect inset:inset];
            }
                    
            if (line.beats.count > 0) {
                [self drawBeat:rect inset:inset];
            }
        }
    }];
    
    for (NSString* color in shownRevisions) {
        NSMutableSet *rects = revisions[color];
        NSString *marker = BeatRevisions.revisionMarkers[color];
        BXColor *bgColor = ThemeManager.sharedManager.backgroundColor.effectiveColor;
        
        [rects enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
            CGRect rect = [(NSValue*)obj getRectValue];
            
            NSMutableString *markerStr = NSMutableString.new;
            NSUInteger lineCount = round(rect.size.height / self.editorDelegate.editorLineHeight);
            
            // Create markers by line count
            for (NSUInteger i=0; i<lineCount; i++) {
                [markerStr appendFormat:@"%@\n", marker];
            }

            // Draw a background rect under the marker to block out earlier markers
            [bgColor setFill];
            BXRectFill(rect);
            
            // Draw string
            [markerStr drawAtPoint:rect.origin withAttributes:@{
                NSFontAttributeName: self.editorDelegate.courier,
                NSForegroundColorAttributeName: ThemeManager.sharedManager.textColor.effectiveColor,
                NSParagraphStyleAttributeName: _markerStyle
            }];
        }];
    }
    [BeatMeasure end:@"New"];
    */
        
    // Enumerate lines in drawn range
    [self.textStorage enumerateAttribute:@"representedLine" inRange:charRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
        Line* line = (Line*)value;
        if (line == nil) return;
        
        // Do nothing if this line is not a marker or a heading
        if (line.markerRange.length == 0 && line.type != heading && line.beats.count == 0) return;
        
        // Get range for the first character. For headings and markers we won't need anything else.
        NSRange r = NSMakeRange(line.position, 1);
        if (self.editorDelegate.hideFountainMarkup) {
            // If the editor hides Fountain markup, there's a chance that the line is hidden (if using a formatting character, ie. ".INT. SOMETHING"
            if (line.length > 1) r.location += 1;
            else r = line.range;
        }
        
        NSRange lineRange = [self glyphRangeForCharacterRange:r actualCharacterRange:nil];
        CGRect boundingRect = [self boundingRectForGlyphRange:lineRange inTextContainer:self.textContainers.firstObject];

        // Actual rect position
        CGRect rect = CGRectMake(inset.width + boundingRect.origin.x, inset.height + boundingRect.origin.y, boundingRect.size.width, boundingRect.size.height);
        
        // Draw scene numbers
        if (line.type == heading) {
            [self drawSceneNumberForLine:line rect:rect inset:inset];
        }
        
        // Draw markers
        if (line.markerRange.length > 0) {
            [self drawMarkerForLine:line rect:rect inset:inset];
        }
                
        if (line.beats.count > 0) {
            [self drawBeat:rect inset:inset];
        }
    }];
    
	[self drawRevisionMarkers:glyphsToShow];
}

- (void)drawBeat:(CGRect)rect inset:(CGSize)inset {
    BXBezierPath* path = BXBezierPath.bezierPath;
    
    CGFloat m = 16.0;
    CGFloat x = (inset.width + _editorDelegate.documentWidth) - 45.0;

    CGFloat y = rect.origin.y + 2.0;
    CGFloat h = rect.size.height - 2.0;

    [path moveToPoint:CGPointMake(x, y + h / 2)];
#if TARGET_OS_IOS
    [path addLineToPoint:CGPointMake(x + m * .25, y + h / 2)];
    [path addLineToPoint:CGPointMake(x + m * .45, y + 1.0)];
    [path addLineToPoint:CGPointMake(x + m * .55, y + h - 1.0)];
    [path addLineToPoint:CGPointMake(x + m * .75, y + h / 2)];
    [path addLineToPoint:CGPointMake(x + m * 1.0, y + h / 2)];
    
    path.lineJoinStyle = kCGLineJoinRound;
    path.lineCapStyle = kCGLineCapRound;
#else
    [path lineToPoint:CGPointMake(x + m * .25, y + h / 2)];
    [path lineToPoint:CGPointMake(x + m * .45, y + 1.0)];
    [path lineToPoint:CGPointMake(x + m * .55, y + h - 1.0)];
    [path lineToPoint:CGPointMake(x + m * .75, y + h / 2)];
    [path lineToPoint:CGPointMake(x + m * 1.0, y + h / 2)];
    
    path.lineJoinStyle = NSLineJoinStyleRound;
    path.lineCapStyle = NSLineCapStyleRound;
#endif

    path.lineWidth = 2.0;
    
    [BeatColors.colors[@"cyan"] setStroke];
    [path stroke];
    //NSRectFill(NSMakeRect(x, y, m, h));
}

- (void)drawSceneNumberForLine:(Line*)line rect:(CGRect)rect inset:(CGSize)inset {
    // Scene number drawing is off, return
    if (!self.editorDelegate.showSceneNumberLabels) return;
    
    // Create the style if needed
    if (_sceneNumberStyle == nil) {
        _sceneNumberStyle = NSMutableParagraphStyle.new;
        _sceneNumberStyle.minimumLineHeight = self.editorDelegate.editorLineHeight;
    }
    
    // Create rect for the marker position
    rect.size.width = 7.5 * line.sceneNumber.length;
    rect.size.height = rect.size.height + 1.0;
    
    rect = CGRectMake(inset.width,
                             rect.origin.y,
                             7.5 * line.sceneNumber.length,
                             rect.size.height + 1.0);
    
    BXColor* color;
    if (line.color.length > 0) color = [BeatColors color:line.color];
    if (color == nil) color = ThemeManager.sharedManager.textColor.effectiveColor;
    
    NSString *sceneNumber = line.sceneNumber;

    [sceneNumber drawAtPoint:rect.origin withAttributes:@{
        NSFontAttributeName: self.editorDelegate.courier,
        NSForegroundColorAttributeName: color,
        NSParagraphStyleAttributeName: self.sceneNumberStyle
    }];
}

- (void)drawDisclosureForRange:(NSRange)glyphRange charRange:(NSRange)charRange
{
    BXTextView* textView = self.editorDelegate.getTextView;
#if TARGET_OS_IOS
    CGSize inset = CGSizeMake(textView.textContainerInset.left, textView.textContainerInset.top);
#else
    CGSize inset = textView.textContainerInset;
#endif
    
	NSInteger i = [self.editorDelegate.parser lineIndexAtPosition:charRange.location];
	ContinuousFountainParser* parser = self.editorDelegate.parser;
	
	NSMutableArray<Line*>* lines = NSMutableArray.new;
	for (; i < parser.lines.count; i++) {
		Line* l = parser.lines[i];
		if (!NSLocationInRange(l.position, charRange)) break;
		
		if (l.type == section) [lines addObject:l];
	}
	
	for (Line* l in lines) {
		NSRange sectionGlyphRange = [self glyphRangeForCharacterRange:NSMakeRange(l.position, 1) actualCharacterRange:nil];
		CGRect r = [self boundingRectForGlyphRange:sectionGlyphRange inTextContainer:self.textContainers.firstObject];
		
		CGRect triangle = CGRectMake(inset.width, r.origin.y + inset.height + r.size.height - 15, 12, 12);
		[BXColor.redColor setFill];
        
		BXRectFill(triangle);
	}
}

- (void)drawMarkerForLine:(Line*)line rect:(CGRect)rect inset:(CGSize)inset {
    
    CGRect r = CGRectMake(inset.width, rect.origin.y, 12, rect.size.height);
    
    BXColor* color;
    if (line.marker.length > 0) color = [BeatColors color:line.marker];
    if (color == nil) color = BeatColors.colors[@"orange"];
    [color setFill];
    
    BXBezierPath* path = [self markerPath:r];
    [path fill];
}

- (BXBezierPath*)markerPath:(CGRect)rect {
    CGFloat left = rect.origin.x;
    CGFloat right = 40.0 + rect.origin.x;
    CGFloat y = rect.origin.y + 2.0;
    CGFloat h = rect.size.height - 2.0;
    
    BXBezierPath *path = BXBezierPath.bezierPath;
    [path moveToPoint:CGPointMake(right, y)];
    
#if TARGET_OS_IOS
    [path addLineToPoint:CGPointMake(left, y)];
    [path addLineToPoint:CGPointMake(left + 10.0, y + h / 2)];
    [path addLineToPoint:CGPointMake(left, y + h)];
    [path addLineToPoint:CGPointMake(right, y + h)];
#else
    [path lineToPoint:NSMakePoint(left, y)];
    [path lineToPoint:NSMakePoint(left + 10.0, y + h / 2)];
    [path lineToPoint:NSMakePoint(left, y + h)];
    [path lineToPoint:NSMakePoint(right, y + h)];
#endif
    
    [path closePath];
    return path;
}

- (void)drawSceneNumberForGlyphRange:(NSRange)glyphRange charRange:(NSRange)charRange
{
    BXTextView* textView = self.editorDelegate.getTextView;
    
    // iOS and macOS have different types of edge insets
#if TARGET_OS_IOS
    CGSize inset = CGSizeMake(textView.textContainerInset.left, textView.textContainerInset.top);
    inset.height += 3.0; // This is here to make up for weird iOS line sizing
#else
    CGSize inset = textView.textContainerInset;
#endif
    
	// Scene number drawing is off, return
	if (!self.editorDelegate.showSceneNumberLabels) return;
	
	// Create the style if needed
	if (_sceneNumberStyle == nil) {
		_sceneNumberStyle = NSMutableParagraphStyle.new;
		_sceneNumberStyle.minimumLineHeight = self.editorDelegate.editorLineHeight;
	}
		
	[self.textStorage enumerateAttribute:@"representedLine" inRange:charRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		Line* line = (Line*)value;
		if (line == nil || line.type != heading) return;
		
		NSRange headingRange = NSMakeRange(line.position, 1);
		if (self.editorDelegate.hideFountainMarkup) {
			if (line.length > 1) headingRange.location += 1;
			else headingRange = line.range;
		}
		
		NSRange lineRange = [self glyphRangeForCharacterRange:headingRange actualCharacterRange:nil];
		CGRect boundingRect = [self boundingRectForGlyphRange:lineRange inTextContainer:self.textContainers.firstObject];
		
		// Calculate rect for the marker position
		CGRect rect = CGRectMake(inset.width,
								 inset.height + boundingRect.origin.y,
								 7.5 * line.sceneNumber.length,
								 boundingRect.size.height + 1.0);
		
		BXColor* color;
		if (line.color.length > 0) color = [BeatColors color:line.color];
		if (color == nil) color = ThemeManager.sharedManager.textColor.effectiveColor;
		
		NSString *sceneNumber = line.sceneNumber;
		[sceneNumber drawAtPoint:rect.origin withAttributes:@{
			NSFontAttributeName: self.editorDelegate.courier,
			NSForegroundColorAttributeName: color,
			NSParagraphStyleAttributeName: self.sceneNumberStyle
		}];
	}];
}


-(void)drawRevisionMarkers:(NSRange)glyphRange
{
	/*
	 
	 This works in a peculiar way:
	 We'll store the NSRect of each marker range into a set using NSNumber, so there will
	 never be two overlapping rects. Those rects are put in a dictionary entry under the
	 revision color.
	 
	 After all glyphs have been iterated, we'll draw the marker strings and draw a rect
	 under them - and voilà: latest revision markers block out the earlier ones.
	 
	 It's a bit convoluted scheme, but works surprisingly well and efficiently.
	 
	 2022/12: Thanks, past me, for this completely useless documentation.
	 
	*/
	
    static NSArray<NSString*>* revisionColors;
    
    if (revisionColors == nil) revisionColors = BeatRevisions.revisionColors;
	NSArray<NSString*>* shownRevisions = revisionColors;
	
	NSTextStorage* textStorage = self.textStorage;
	NSTextContainer* textContainer = self.textContainers.firstObject;
    BXColor *bgColor = ThemeManager.sharedManager.backgroundColor.effectiveColor;
    
    CGSize offset = [self offsetSize];
	
	NSMutableDictionary<NSString*, NSMutableSet<NSValue*>*> *revisions = [NSMutableDictionary dictionaryWithCapacity:revisionColors.count];
	
	while (glyphRange.length > 0) {
		// Get character range for the range we're displaying
		NSRange charRange = [self characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL], attributeCharRange, attributeGlyphRange;
		
		// Get revision attributes at this range
		BeatRevisionItem *revision = [textStorage attribute:BeatRevisions.attributeKey
													atIndex:charRange.location longestEffectiveRange:&attributeCharRange
													inRange:charRange];
			
		// Get actual glyphs
		attributeGlyphRange = [self glyphRangeForCharacterRange:attributeCharRange actualCharacterRange:NULL];
		// Get intersection range between the glyphs being displayed and the actual attribute range
		attributeGlyphRange = NSIntersectionRange(attributeGlyphRange, glyphRange);
				
		// Check if there actually was a revision attribute
		if ((revision.type == RevisionAddition || revision.type == RevisionCharacterRemoved) &&
			revision != nil && revision.colorName != nil && [shownRevisions containsObject:revision.colorName.lowercaseString]) {
			// Get bounding rect for the range
			CGRect boundingRect = [self boundingRectForGlyphRange:attributeGlyphRange
												  inTextContainer:textContainer];
			
			// Calculate rect for the marker position
			CGRect rect = CGRectMake(offset.width + _editorDelegate.documentWidth - 22,
									 offset.height + boundingRect.origin.y,
									 22,
									 boundingRect.size.height + 1.0);
			
			// Add the marker to dictionary:
			// dict["colorName"][] -> rect
            if (revisions[revision.colorName] == nil) revisions[revision.colorName] = [NSMutableSet setWithCapacity:50];
			[revisions[revision.colorName] addObject:@(rect)];
		}
				
		glyphRange.length = NSMaxRange(glyphRange) - NSMaxRange(attributeGlyphRange);
		glyphRange.location = NSMaxRange(attributeGlyphRange);
	}
	
	for (NSString *color in BeatRevisions.revisionColors) {
		NSMutableSet *rects = revisions[color];
		NSString *marker = BeatRevisions.revisionMarkers[color];
		
        for (NSValue* value in rects) {
            CGRect rect = [value getRectValue];
            
            NSUInteger lineCount = round(rect.size.height / self.editorDelegate.editorLineHeight);
            NSString* markerStr = [self markerStringForMarker:marker lineCount:lineCount];

            // Draw a background rect under the marker to block out earlier markers
            [bgColor setFill];
            BXRectFill(rect);
            
            // Draw string
            [markerStr drawAtPoint:rect.origin withAttributes:@{
                NSFontAttributeName: self.editorDelegate.courier,
                NSForegroundColorAttributeName: ThemeManager.sharedManager.textColor.effectiveColor,
                NSParagraphStyleAttributeName: _markerStyle
            }];
        }
	}
}

/// This method returns a given number of lines for a specific marker. The resutls are cached.
-(NSString*)markerStringForMarker:(NSString*)marker lineCount:(NSInteger)lineCount {
    static NSCache<NSString*, NSMutableDictionary*>* markers;
    if (markers == nil) markers = NSCache.new;
    
    if ([markers objectForKey:marker] == nil) [markers setObject:NSMutableDictionary.new forKey:marker];
    NSMutableDictionary* markerValues = [markers objectForKey:marker];
    
    if (markerValues[@(lineCount)] == nil) {
        NSMutableString *markerStr = NSMutableString.new;
        
        // Create markers by line count
        for (NSUInteger i=0; i<lineCount; i++) {
            [markerStr appendFormat:@"%@\n", marker];
        }
        
        markerValues[@(lineCount)] = markerStr;
    }
    
    return markerValues[@(lineCount)];
}

-(void)drawBackgroundForGlyphRange:(NSRange)glyphsToShow atPoint:(BXPoint)origin
{
	static NSMutableDictionary* bgColors;
    if (bgColors == nil) bgColors = [NSMutableDictionary dictionaryWithCapacity:10];
    
    BXTextView* textView = self.editorDelegate.getTextView;
    CGSize inset = [self offsetSize];
    
    bool showTags = _editorDelegate.showTags;
    bool showRevisions = _editorDelegate.showRevisions;
    
    [self enumerateLineFragmentsForGlyphRange:glyphsToShow usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer * _Nonnull textContainer, NSRange glyphRange, BOOL * _Nonnull stop) {
        NSRange charRange = [self characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];
        
        [self.textStorage enumerateAttributesInRange:charRange options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
            if (range.location < 0 || NSMaxRange(range) < 0) return;
                        
            BeatRevisionItem* revision = attrs[BeatRevisions.attributeKey];
            BeatTag* tag = attrs[BeatTagging.attributeKey];
            BeatReviewItem *review = attrs[BeatReview.attributeKey];
                        
            // Remove line breaks from the range (begin enumeration from the end to catch them as soon as possible)
            NSRange rRange = range;
            for (NSInteger i = NSMaxRange(rRange) - 1; i >= rRange.location; i--) {
                if (i < 0) break;
                if ([self.textStorage.string characterAtIndex:i] == '\n') {
                    rRange.length = rRange.length - 1;
                    break;
                }
            }
            
            NSRange usedRange = [self glyphRangeForCharacterRange:rRange actualCharacterRange:nil];
            CGRect aRect = [self boundingRectForGlyphRange:usedRange inTextContainer:self.textContainers.firstObject];
            aRect.origin.x += inset.width;
            aRect.origin.y += inset.height;
            
            if (review != nil && !review.emptyReview) {
                if (bgColors[@"review"] == nil) {
                    BXColor *reviewColor = BeatReview.reviewColor;
                    bgColors[@"review"] = [reviewColor colorWithAlphaComponent:.5];
                }
                BXColor *color = bgColors[@"review"];
                [color setFill];

                
                NSRange fullGlyphRange = [self glyphRangeForCharacterRange:rRange actualCharacterRange:nil];
                CGRect fullRect = [self boundingRectForGlyphRange:fullGlyphRange inTextContainer:self.textContainers.firstObject];
                bool fullLine = (fullGlyphRange.length == glyphRange.length - 1);
                
                fullRect.origin.x += inset.width;
                fullRect.origin.y += inset.height;
                
                if (fullLine) {
                    CGFloat padding = textView.textContainer.lineFragmentPadding;
                    fullRect.origin.x = inset.width + padding;
                    fullRect.size.width = textView.textContainer.size.width - padding * 2;
                }
                
                BXRectFill(fullRect);
            }
            
            if (tag != nil && self.editorDelegate.showTags) {
                if (bgColors[tag.typeAsString] == nil) {
                    bgColors[tag.typeAsString] = [[BeatTagging colorFor:tag.type] colorWithAlphaComponent:0.5];
                }

                BXColor *tagColor = bgColors[tag.typeAsString];
                [tagColor setFill];
                
                BXRectFill(aRect);
            }
            
            // Draw revision backgrounds last, so the underlines go on top of other stuff.
            if (revision.type == RevisionAddition && self.editorDelegate.showRevisions && rRange.length > 0) {
                CGRect revisionRect = aRect;
                
                if (bgColors[revision.colorName] == nil) {
                    bgColors[revision.colorName] = [[BeatColors color:revision.colorName] colorWithAlphaComponent:.3];
                }
                [bgColors[revision.colorName] setFill];
                
                revisionRect.origin.y += revisionRect.size.height - 1.0;
                revisionRect.size.height = 2.0;
                
                BXRectFill(revisionRect);
            }
        }];
    }];
     
	[super drawBackgroundForGlyphRange:glyphsToShow atPoint:origin];
}

-(NSArray*)rectsForGlyphRange:(NSRange)glyphsToShow
{
	NSMutableArray *rects = NSMutableArray.new;
	NSTextContainer *tc = self.textContainers.firstObject;
	
	[self enumerateLineFragmentsForGlyphRange:glyphsToShow usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer * _Nonnull textContainer, NSRange glyphRange, BOOL * _Nonnull stop) {
		CGRect lfRect = [self boundingRectForGlyphRange:NSIntersectionRange(glyphsToShow, glyphRange) inTextContainer:tc];
        [rects addObject:@(lfRect)];
	}];
	
	return rects;
}

- (NSUInteger)hashForAttributesInRange:(NSRange)range {
    NSTextStorage* textStorage = self.textStorage;
    BeatRevisionItem *revision = [textStorage attribute:BeatRevisions.attributeKey atIndex:range.location effectiveRange:NULL];
    NSString *colorName = revision.colorName ?: @"";
    NSUInteger hash = [colorName hash];

    return hash;
}

#pragma mark - Crossplatform helpers

-(void)saveGraphicsState {
#if !TARGET_OS_IOS
        [NSGraphicsContext saveGraphicsState];
#endif
}
-(void)restoreGraphicsState {
#if !TARGET_OS_IOS
        [NSGraphicsContext restoreGraphicsState];
#endif
}
-(CGSize)offsetSize {
#if TARGET_OS_IOS
    CGSize offset = CGSizeMake(_editorDelegate.getTextView.textContainerInset.left, _editorDelegate.getTextView.textContainerInset.top);
#else
    CGSize offset = _editorDelegate.getTextView.textContainerInset;
#endif
    return offset;
}

@end
