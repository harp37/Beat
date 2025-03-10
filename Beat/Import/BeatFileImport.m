//
//  BeatFileImport.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 20.9.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//
/**
 
 This is a generic import-module for Beat. Classes for different import options
 don't (yet) register themselves, so they have to be added as IBActions into
 this class.
 
 Each import module should adhere to `BeatImportModule` protocol.
 
 Currently the modules are a bit different, but in the future we'll have a single way to handle everything. Init the module, provide `url`, `options: {}` and a completion block which will be executed once the process has ended. It will return the **import module** itself or `nil`. Each module will have a property called `.fountain` which contains the imported document, if the process was successful.
 
 Modules should be OS-agnostic. Some are not, including Celtx import.
 
 Import now supports:
 - Highland
 - FadeIn (though this is mostly untested)
 - CeltX
 - FDX
 - PDF
 - Trelby
 
 */

#import "BeatFileImport.h"
#import <BeatFileExport/BeatFileExport.h>
#import <BeatFileExport/BeatFileExport-Swift.h>

@interface BeatFileImport ()
@property (nonatomic) NSMutableArray* checkboxes;
@property (nonatomic) NSView* accessoryView;
@end

@implementation BeatFileImport

- (void)openDialogForFormat:(NSString*)extension completion:(void(^)(NSURL*))callback {
	[self openDialogForFormats:@[extension] completion:callback];
}
- (void)openDialogForFormats:(NSArray*)extensions completion:(void(^)(NSURL*))callback {
	NSOpenPanel *openDialog = NSOpenPanel.openPanel;
	openDialog.accessoryView = _accessoryView;
	openDialog.accessoryViewDisclosed = YES;
	
	[openDialog setAllowedFileTypes:extensions];
	
	[openDialog beginWithCompletionHandler:^(NSModalResponse result) {
		if (result == NSModalResponseOK && openDialog.URL) {
			callback(openDialog.URL);
		}
	}];
}

- (void)addCheckbox:(NSButton*)checkbox {
	if (_checkboxes == nil) _checkboxes = NSMutableArray.new;
	[_checkboxes addObject:checkbox];
	
	if (self.accessoryView == nil) {
		self.accessoryView = [NSView.alloc initWithFrame:NSMakeRect(0, 0, 600, 100)];
	}
	
	// Adjust the frame of the checkbox
	
	NSSize size = [checkbox fittingSize];
	NSRect checkboxFrame = checkbox.frame;
	checkboxFrame.origin.x = 20.0;
	checkboxFrame.origin.y = 20.0 * self.accessoryView.subviews.count + 20.0;
	checkboxFrame.size.width = size.width;
	checkboxFrame.size.height = size.height;
	checkbox.frame = checkboxFrame;

	[self.accessoryView addSubview:checkbox];
	
	CGFloat height = 0.0;
	for (NSView* view in self.accessoryView.subviews) {
		height += view.frame.size.height;
	}
	height += 40.0;

	NSRect frame = self.accessoryView.frame;
	frame.size.height = height;
	self.accessoryView.frame = frame;
	

}

- (void)fdx {
	// The XML reader works asynchronously, so we'll put a completion handler inside the completion handler
	__block NSButton* importNotes = NSButton.new;
	[importNotes setButtonType:NSSwitchButton];
	[importNotes setTitle:@"Import Final Draft notes (WARNING: Can cause formatting issues in some cases)"];

	[self addCheckbox:importNotes];
	[self openDialogForFormat:@"fdx" completion:^(NSURL * url) {
	__block FDXImport *fdxImport;
	
		bool notes = (importNotes.state == NSOnState);
		fdxImport = [FDXImport.alloc initWithURL:url importNotes:notes completion:^(NSString* content) {
			dispatch_async(dispatch_get_main_queue(), ^(void) {
				[self openFileWithContents:content];
			});
		}];
	}];
}

- (void)fadeIn {
	[self openDialogForFormat:@"fadein" completion:^(NSURL * url) {
		FadeInImport *import = [FadeInImport.alloc initWithURL:url options:nil completion:nil];
		NSString* fountain = import.fountain;
		if (fountain) [self openFileWithContents:fountain];
	}];
}

- (void)highland {
	[self openDialogForFormat:@"highland" completion:^(NSURL * url) {
		HighlandImport *import = [HighlandImport.alloc initWithURL:url options:nil completion:nil];
		NSString* fountain = import.fountain;
		if (fountain) [self openFileWithContents:fountain];
	}];
}

- (void)celtx {
	[self openDialogForFormats:@[@"celtx", @"cxscript"] completion:^(NSURL * url) {
		CeltxImport *import = [CeltxImport.alloc initWithURL:url];
		NSString* fountain = import.fountain;
		if (fountain) [self openFileWithContents:fountain];
	}];
}

- (void)trelby {
	[self openDialogForFormat:@"trelby" completion:^(NSURL * url) {
		(void)[TrelbyImport.alloc initWithURL:url options:nil completion:^(NSString* fountain) {
			[self openFileWithContents:fountain];
		}];
	}];
}

- (void)pdf {
	[self openDialogForFormat:@"pdf" completion:^(NSURL * url) {
		NSAlert* alert = NSAlert.new;
		alert.informativeText = PDFImport.infoMessage;
		alert.messageText = PDFImport.infoTitle;
		[alert runModal];
		
		(void)[PDFImport.alloc initWithURL:url options:nil completion:^(NSString* fountain) {
			[self openFileWithContents:fountain];
		}];
	}];
}

- (void)openFileWithContents:(NSString*)string {
	NSURL *tempURL = [self URLForTemporaryFileWithPrefix:@"fountain"];
	NSError *error;
	
	[string writeToURL:tempURL atomically:NO encoding:NSUTF8StringEncoding error:&error];
	
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		[[NSDocumentController sharedDocumentController] duplicateDocumentWithContentsOfURL:tempURL copying:YES displayName:@"Untitled" error:nil];
	});
}

- (NSURL *)URLForTemporaryFileWithPrefix:(NSString *)prefix
{
	NSURL  *  result;
	CFUUIDRef   uuid;
	CFStringRef uuidStr;

	uuid = CFUUIDCreate(NULL);
	assert(uuid != NULL);

	uuidStr = CFUUIDCreateString(NULL, uuid);
	assert(uuidStr != NULL);
	result = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.%@", prefix, uuidStr, prefix]]];
	
	assert(result != nil);

	CFRelease(uuidStr);
	CFRelease(uuid);

	return result;
}

@end
/*
 
 seisottiin puutarhassa ja katsottiin tähtiä
 enkä ollut nähnyt linnunrataa
 niin kirkkaana
 aikoihin
 
 tunnen itseni pieneksi
 sinua se pelottaa
 mutta olen tässä
 tällä planeetalla
 näinä atomeina
 sinun kanssasi
 tässä puutarhassa
 tänä yönä.
 
 */
