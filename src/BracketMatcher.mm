//
//  BracketMatcher.mm
//  XcodeBracketMatcher
//
//  Created by Ciarán Walsh on 02/04/2009.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "BracketMatcher.h"
#import "JRSwizzle.h"

static BracketMatcher* SharedInstance;

@interface NSObject (DevToolsInterfaceAdditions)
// XCTextStorageAdditions
- (id)language;

// XCSourceCodeTextView
- (BOOL)isInlineCompleting;
- (id)codeAssistant;

// PBXCodeAssistant
- (void)liveInlineRemoveCompletion;
@end

@implementation NSTextView (BracketMatching)
- (void)BracketMatching_keyDown:(NSEvent*)event
{
	BOOL didInsert = NO;

	if([[event characters] isEqualToString:@"]"])
	{
		NSString* language = [[self textStorage] language];
		if([language isEqualToString:@"xcode.lang.objcpp"] || [language isEqualToString:@"xcode.lang.objc"])
			didInsert = [[BracketMatcher sharedInstance] insertBracketForTextView:self];
	}

	if(!didInsert)
		[self BracketMatching_keyDown:event];
}
@end

@implementation BracketMatcher
+ (void)load
{
	if([NSClassFromString(@"XCSourceCodeTextView") jr_swizzleMethod:@selector(keyDown:) withMethod:@selector(BracketMatching_keyDown:) error:NULL])
		NSLog(@"BracketMatcher loaded");
}

+ (BracketMatcher*)sharedInstance
{
	return SharedInstance ?: [[self new] autorelease];
}

- (id)init
{
	if(SharedInstance)
		[self release];
	else
		self = SharedInstance = [[super init] retain];
	return SharedInstance;
}

- (NSString*)processLine:(NSString*)line insertionPoint:(NSUInteger)insertionPoint
{
	NSTask* task = [[NSTask new] autorelease];
	[task setLaunchPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"parser" ofType:@"rb"]];
	[task setEnvironment:[NSDictionary dictionaryWithObjectsAndKeys:line, @"TM_CURRENT_LINE", [NSString stringWithFormat:@"%d", insertionPoint], @"TM_LINE_INDEX", nil]];
	[task setStandardOutput:[NSPipe pipe]];
	[task launch];
	[task waitUntilExit];

	NSFileHandle* fileHandle = [[task standardOutput] fileHandleForReading];
	NSData* data             = [fileHandle readDataToEndOfFile];
	if([task terminationStatus] != 0)
		return nil;
	return [[[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding] autorelease];
}

NSUInteger TextViewLineIndex (NSTextView* textView)
{
	NSRange selectedRange = [[[textView selectedRanges] lastObject] rangeValue];
	NSUInteger res        = selectedRange.location;
	NSString* substring   = [[[textView textStorage] string] substringToIndex:selectedRange.location];
	NSUInteger newline    = [substring rangeOfString:@"\n" options:NSBackwardsSearch].location;
	if(newline != NSNotFound)
		res -= newline + 1;
	return res;
}

- (BOOL)insertBracketForTextView:(NSTextView*)textView
{
	if(![[textView selectedRanges] count])
		return NO;

	NSRange selectedRange = [[[textView selectedRanges] lastObject] rangeValue];
	if(selectedRange.length > 0)
		return NO;

	NSRange lineRange = [textView.textStorage.string lineRangeForRange:selectedRange];
	lineRange.length -= 1;
	NSString* lineText            = [textView.textStorage.string substringWithRange:lineRange];
	NSMutableString* resultString = [[self processLine:lineText insertionPoint:TextViewLineIndex(textView)] mutableCopy];

	if(!resultString || [resultString isEqualToString:lineText])
		return NO;

	NSRange caretOffset = [resultString rangeOfString:@"$$caret$$"];
	[resultString replaceCharactersInRange:caretOffset withString:@""];

	[textView.undoManager beginUndoGrouping];
	[[textView.undoManager prepareWithInvocationTarget:textView] setSelectedRange:selectedRange];
	[[textView.undoManager prepareWithInvocationTarget:textView] replaceCharactersInRange:NSMakeRange(lineRange.location, [resultString length]) withString:lineText];
	[textView.undoManager endUndoGrouping];

	[textView replaceCharactersInRange:lineRange withString:resultString];
	[textView setSelectedRange:NSMakeRange(lineRange.location + caretOffset.location, 0)];

	return YES;
}
@end
