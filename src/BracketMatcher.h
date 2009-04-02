//
//  BracketMatcher.h
//  XcodeBracketMatcher
//
//  Created by Ciarán Walsh on 02/04/2009.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface BracketMatcher : NSObject
{

}
+ (BracketMatcher*)sharedInstance;
- (BOOL)insertBracketForTextView:(NSTextView*)textView;
@end
