//
//  CCoreTextLabel.m
//  TouchCode
//
//  Created by Jonathan Wight on 07/12/11.
//  Copyright 2011 toxicsoftware.com. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification, are
//  permitted provided that the following conditions are met:
//
//     1. Redistributions of source code must retain the above copyright notice, this list of
//        conditions and the following disclaimer.
//
//     2. Redistributions in binary form must reproduce the above copyright notice, this list
//        of conditions and the following disclaimer in the documentation and/or other materials
//        provided with the distribution.
//
//  THIS SOFTWARE IS PROVIDED BY TOXICSOFTWARE.COM ``AS IS'' AND ANY EXPRESS OR IMPLIED
//  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL TOXICSOFTWARE.COM OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
//  ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
//  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
//  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//  The views and conclusions contained in the software and documentation are those of the
//  authors and should not be interpreted as representing official policies, either expressed
//  or implied, of toxicsoftware.com.

#import "CCoreTextLabel.h"

#import <CoreText/CoreText.h>
#import <QuartzCore/QuartzCore.h>

#import "CMarkupValueTransformer.h"
#import "CCoreTextRenderer.h"
#import "UIFont_CoreTextExtensions.h"
#import "UIColor+Hex.h"

@interface CCoreTextLabel ()
@property (readwrite, nonatomic, retain) CCoreTextRenderer *renderer;
@property (readwrite, nonatomic, retain) UITapGestureRecognizer *tapRecognizer;

+ (NSAttributedString *)normalizeString:(NSAttributedString *)inString font:(UIFont *)inBaseFont textColor:(UIColor *)inTextColor alignment:(UITextAlignment)inTextAlignment lineBreakMode:(UILineBreakMode)inLineBreakMode;
- (void)tap:(UITapGestureRecognizer *)inGestureRecognizer;
@end

@implementation CCoreTextLabel

@synthesize text;
@synthesize insets;
@synthesize URLHandler;
@synthesize font;
@synthesize textColor;
@synthesize textAlignment;
@synthesize lineBreakMode;

@synthesize renderer;
@synthesize tapRecognizer;

+ (CGSize)sizeForString:(NSAttributedString *)inString font:(UIFont *)inBaseFont textColor:(UIColor *)inTextColor alignment:(UITextAlignment)inTextAlignment lineBreakMode:(UILineBreakMode)inLineBreakMode thatFits:(CGSize)inSize 
    {
    NSAttributedString *theNormalizedText = [self normalizeString:inString font:inBaseFont textColor:inTextColor alignment:inTextAlignment lineBreakMode:inLineBreakMode];
    CGSize theSize = [CCoreTextRenderer sizeForString:theNormalizedText thatFits:inSize];
    return(theSize);
    }

+ (NSAttributedString *)normalizeString:(NSAttributedString *)inString font:(UIFont *)inBaseFont textColor:(UIColor *)inTextColor alignment:(UITextAlignment)inTextAlignment lineBreakMode:(UILineBreakMode)inLineBreakMode
    {
    NSMutableAttributedString *theMutableText = [[CMarkupValueTransformer normalizedAttributedStringForAttributedString:inString baseFont:inBaseFont] mutableCopy];

    UIFont *theFont = inBaseFont ?: [UIFont systemFontOfSize:17.0];
    UIColor *theColor = inTextColor ?: [UIColor blackColor];
    [theMutableText enumerateAttributesInRange:(NSRange){ .length = theMutableText.length } options:0 usingBlock:^(NSDictionary *attrs, NSRange range, BOOL *stop) {
        if ([attrs objectForKey:(__bridge NSString *)kCTFontAttributeName] == NULL)
            {
            [theMutableText addAttribute:(__bridge NSString *)kCTFontAttributeName value:(__bridge id)theFont.CTFont range:range];
            }
        if ([attrs objectForKey:(__bridge NSString *)kCTForegroundColorAttributeName] == NULL)
            {
            [theMutableText addAttribute:(__bridge NSString *)kCTForegroundColorAttributeName value:(__bridge id)theColor.CGColor range:range];
            }
        // [DW]
        if ([attrs objectForKey:kMarkupTextColorAttributeName] != NULL)
        {
            NSString *theColorStr = [attrs objectForKey:kMarkupTextColorAttributeName];
            if(theColorStr)
                [theMutableText addAttribute:(__bridge NSString *)kCTForegroundColorAttributeName value:(__bridge id)[UIColor colorWithHexString:theColorStr].CGColor range:range];
        }
        }];
    
    CTTextAlignment theTextAlignment;
    switch (inTextAlignment)
        {
        case UITextAlignmentLeft:
            theTextAlignment = kCTLeftTextAlignment;
            break;
        case UITextAlignmentCenter:
            theTextAlignment = kCTCenterTextAlignment;
            break;
        case UITextAlignmentRight:
            theTextAlignment = kCTRightTextAlignment;
            break;
        }
    
    // UILineBreakMode maps 1:1 to CTLineBreakMode
    CTLineBreakMode theLineBreakMode = inLineBreakMode;

    CTParagraphStyleSetting theSettings[] = {
        { .spec = kCTParagraphStyleSpecifierAlignment, .valueSize = sizeof(theTextAlignment), .value = &theTextAlignment, },
        { .spec = kCTParagraphStyleSpecifierLineBreakMode, .valueSize = sizeof(theLineBreakMode), .value = &theLineBreakMode, },
        };
    CTParagraphStyleRef theParagraphStyle = CTParagraphStyleCreate( theSettings, 2 );
    NSDictionary *theAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
        (__bridge_transfer id)theParagraphStyle, (__bridge id)kCTParagraphStyleAttributeName,
        NULL];
    [theMutableText addAttributes:theAttributes range:(NSRange){ .length = [theMutableText length] }];

    return(theMutableText);
    }

- (id)initWithFrame:(CGRect)frame
    {
    if ((self = [super initWithFrame:frame]) != NULL)
        {
        self.contentMode = UIViewContentModeRedraw;

        font = [UIFont systemFontOfSize:17];
        textColor = [UIColor blackColor];
        textAlignment = UITextAlignmentLeft;
        lineBreakMode = UILineBreakModeTailTruncation;
        }
    return(self);
    }

- (id)initWithCoder:(NSCoder *)inCoder
    {
    if ((self = [super initWithCoder:inCoder]) != NULL)
        {
        self.contentMode = UIViewContentModeRedraw;

        font = [UIFont systemFontOfSize:17];
        textColor = [UIColor blackColor];
        textAlignment = UITextAlignmentLeft;
        lineBreakMode = UILineBreakModeTailTruncation;
        }
    return(self);
    }

#pragma mark -

- (void)setFrame:(CGRect)inFrame
    {
    [super setFrame:inFrame];

    self.renderer = NULL;
    [self setNeedsDisplay];
    }

#pragma mark -

- (void)setTextAlignment:(UITextAlignment)inTextAlignment
    {
    if (textAlignment != inTextAlignment)
        {
        textAlignment = inTextAlignment;
        
        self.renderer = NULL;
        [self setNeedsDisplay];
        }
    }
    
- (void)setLineBreakMode:(UILineBreakMode)inLineBreakMode
    {
    if (lineBreakMode != inLineBreakMode)
        {
        lineBreakMode = inLineBreakMode;
        
        self.renderer = NULL;
        [self setNeedsDisplay];
        }
    }

- (void)setText:(NSAttributedString *)inText
    {
    if (text != inText)
        {
        text = inText;
        
        self.renderer = NULL;
        [self setNeedsDisplay];
        }
    }

- (void)setInsets:(UIEdgeInsets)inInsets
    {
    insets = inInsets;

    self.renderer = NULL;
    [self setNeedsDisplay];
    }

- (void)setURLHandler:(void (^)(NSURL *))inURLHandler
    {
    if (URLHandler != inURLHandler)
        {
        URLHandler = [inURLHandler copy];
        //
        if (URLHandler != NULL)
            {
            self.tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
            [self addGestureRecognizer:self.tapRecognizer];
            }
        else
            {
            [self removeGestureRecognizer:self.tapRecognizer];
            self.tapRecognizer = NULL;
            }
        }
    }

#pragma mark -

- (CCoreTextRenderer *)renderer
    {
    if (renderer == NULL)
        {
        NSAttributedString *theNormalizedText = [[self class] normalizeString:self.text font:self.font textColor:self.textColor alignment:self.textAlignment lineBreakMode:self.lineBreakMode];

        CGRect theBounds = self.bounds;
        theBounds = UIEdgeInsetsInsetRect(theBounds, self.insets);
        
        renderer = [[CCoreTextRenderer alloc] initWithText:theNormalizedText size:theBounds.size];

        #warning TODO make constants for backgroundColor and strikeColor
        [renderer addPrerendererBlock:^(CGContextRef inContext, CTRunRef inRun, CGRect inRect) {
            NSDictionary *theAttributes2 = (__bridge NSDictionary *)CTRunGetAttributes(inRun);
            CGColorRef theColor2 = (__bridge CGColorRef)[theAttributes2 objectForKey:@"backgroundColor"];
            CGContextSetFillColorWithColor(inContext, theColor2);
            CGContextFillRect(inContext, inRect);
            } forAttributeKey:@"backgroundColor"];

        [renderer addPrerendererBlock:^(CGContextRef inContext, CTRunRef inRun, CGRect inRect) {
            NSDictionary *theAttributes2 = (__bridge NSDictionary *)CTRunGetAttributes(inRun);
            CGColorRef theColor2 = (__bridge CGColorRef)[theAttributes2 objectForKey:@"strikeColor"];
            CGContextSetStrokeColorWithColor(inContext, theColor2);
            CGContextMoveToPoint(inContext, CGRectGetMinX(inRect), CGRectGetMidY(inRect));
            CGContextAddLineToPoint(inContext, CGRectGetMaxX(inRect), CGRectGetMidY(inRect));
            CGContextStrokePath(inContext);
            } forAttributeKey:@"strikeColor"];
        }
    return(renderer);
    }

#pragma mark -

- (CGSize)sizeThatFits:(CGSize)size
    {
    CGSize theSize = size;
    theSize.width -= self.insets.left + self.insets.right;
    theSize.height -= self.insets.top + self.insets.bottom;
    
    theSize = [self.renderer sizeThatFits:theSize];
    theSize.width += self.insets.left + self.insets.right;
    theSize.height += self.insets.top + self.insets.bottom;
    
    return(theSize);
    }

- (void)drawRect:(CGRect)rect
    {
    // ### Work out the inset bounds...
    CGRect theBounds = self.bounds;
    theBounds = UIEdgeInsetsInsetRect(theBounds, self.insets);

    // ### Get and set up the context...
    CGContextRef theContext = UIGraphicsGetCurrentContext();
    CGContextSaveGState(theContext);
    CGContextTranslateCTM(theContext, theBounds.origin.x, theBounds.origin.y);
    
    [self.renderer drawInContext:theContext];

    CGContextRestoreGState(theContext);    

// If you wanted to dump the rendered images to disk so you can make sure it is rendering correctly here's how you could do it...
//    #if 1
//    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, 0.0);
//    theContext = UIGraphicsGetCurrentContext();
//    [self.renderer drawInContext:theContext];
//    UIImage *theImage = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
//    [UIImagePNGRepresentation(theImage) writeToFile:[NSString stringWithFormat:@"/Users/schwa/Desktop/%d.png", [theImage hash]] atomically:NO];
//    #endif
    }

- (void)tap:(UITapGestureRecognizer *)inGestureRecognizer
    {
    CGPoint theLocation = [inGestureRecognizer locationInView:self];
    theLocation.x -= self.insets.left;
    theLocation.y -= self.insets.top;

    NSDictionary *theAttributes = [self.renderer attributesAtPoint:theLocation];
    NSURL *theLink = [theAttributes objectForKey:kMarkupLinkAttributeName];
    if (theLink != NULL)
        {
        if (self.URLHandler != NULL)
            {
            self.URLHandler(theLink);
            }
        }
    }
    
#pragma mark -

- (NSArray *)rectsForRange:(NSRange)inRange;
    {
    return([self.renderer rectsForRange:inRange]);
    }

@end
