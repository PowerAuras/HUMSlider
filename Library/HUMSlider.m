//
//  HUMSlider.m
//  HUMSliderSample
//
//  Created by Ellen Shapiro on 12/26/14.
//  Copyright (c) 2014 Just Hum, LLC. All rights reserved.
//

#import "HUMSlider.h"

// Animation Durations
static NSTimeInterval const HUMTickAlphaDuration = 0.20;
static NSTimeInterval const HUMTickMovementDuration = 0.5;
static NSTimeInterval const HUMSecondTickDuration = 0.35;
static NSTimeInterval const HUMTickAnimationDelay = 0.025;

// Positions
static CGFloat const HUMTickOutToInDifferential = 8;
static CGFloat const HUMImagePadding = 8;

// Sizes
static CGFloat const HUMTickHeight = 6;
static CGFloat const HUMTickWidth = 1;

@interface HUMSlider ()
{
    BOOL _thumbOn;
}
@property (nonatomic) NSArray *allTickBottomConstraints;
@property (nonatomic) NSArray *leftTickRightConstraints;
@property (nonatomic) NSArray *rightTickLeftConstraints;

@property (nonatomic) UIImage *leftTemplate;
@property (nonatomic) UIImage *rightTemplate;

@property (nonatomic) UIImageView *leftSaturatedImageView;
@property (nonatomic) UIColor *leftSaturatedColor;
@property (nonatomic) UIImageView *leftDesaturatedImageView;
@property (nonatomic) UIColor *leftDesaturatedColor;
@property (nonatomic) UIImageView *rightSaturatedImageView;
@property (nonatomic) UIColor *rightSaturatedColor;
@property (nonatomic) UIImageView *rightDesaturatedImageView;
@property (nonatomic) UIColor *rightDesaturatedColor;

@property (nonatomic) NSUInteger largeSpaceCount;
@property (nonatomic) NSUInteger smallSpaceCount;
@property (nonatomic) NSUInteger sectionCount;
@property (nonatomic) NSArray *tickViews;
@end

@implementation HUMSlider

#pragma mark - Init

- (void)commonInit
{
    // Set default values.
    self.sectionCount = 9;
    self.tickAlphaAnimationDuration = HUMTickAlphaDuration;
    self.tickMovementAnimationDuration = HUMTickMovementDuration;
    self.secondTickMovementAndimationDuration = HUMSecondTickDuration;
    self.nextTickAnimationDelay = HUMTickAnimationDelay;
    
    //These will set the side colors.
    self.saturatedColor = [UIColor redColor];
    self.desaturatedColor = [UIColor lightGrayColor];
    
    self.tickColor = [UIColor darkGrayColor];
    
    // Add self as target.
    [self addTarget:self
             action:@selector(sliderAdjusted)
   forControlEvents:UIControlEventValueChanged];
}

- (instancetype)init
{
    if (self = [super init]) {
        [self commonInit];
    }
    
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        [self commonInit];
    }
    
    return self;
}

#pragma mark - Ticks

- (void)nukeOldTicks
{
    for (UIView *tick in self.tickViews) {
        [tick removeFromSuperview];
    }
    
    self.tickViews = nil;
    self.leftTickRightConstraints = nil;
    self.allTickBottomConstraints = nil;
    
    [self layoutIfNeeded];
}

- (void)setupTicks
{
    NSMutableArray *tickBuilder = [NSMutableArray array];
    for (NSInteger i = 0; i < self.sectionCount; i++) {
        UIView *tick = [[UIView alloc] init];
        tick.backgroundColor = self.tickColor;
        //4 5
        //
        if (i < self.largeSpaceCount * 2 - 1 ) {
            if (i%2 != 0) {
                tick.hidden = YES;
            }
        }
        tick.alpha = 0;
        
        tick.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:tick];
        [self sendSubviewToBack:tick];
        [tickBuilder addObject:tick];
    }
    
    self.tickViews = tickBuilder;
    [self setupTicksAutolayout];
}

#pragma mark Autolayout

- (void)setupTicksAutolayout
{
    NSMutableArray *bottoms = [NSMutableArray array];
    NSMutableArray *lefts = [NSMutableArray array];
    NSMutableArray *rights = [NSMutableArray array];
    
    UIView *middleTick = self.tickViews[self.middleTickIndex];
    [self pinTickWidthAndHeight:middleTick];//奇数的最中间的tick的宽高
    NSLayoutConstraint *midBottom = [self pinTickBottom:middleTick];//奇数的最中间的tick的底部距离self底部的距离为tickOutPosition
    [bottoms addObject:midBottom];
    
    // Pin the middle tick to the middle of the slider.
    [self addConstraint:[NSLayoutConstraint constraintWithItem:middleTick
                                                     attribute:NSLayoutAttributeCenterX
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:self
                                                     attribute:NSLayoutAttributeCenterX
                                                    multiplier:1
                                                      constant:0]];
    /*
     sectionCount为5 即5个tick
     0 1 2 3 4
     middleTickIndex = 2
     
     i = 0; i < 2; i ++
     {
     紧挨着middle的左右两个tick
     previousLowest = 2
     previousHightest = 2
     
     次挨着middle的左右两个tick
     nextToLeft = 1
     nextToRight = 3
     
     设置次挨着的左右两个tick的宽高后，设置bottom并且按照tick的顺序添加到bottoms数组中
     }
     */
    for (NSInteger i = 0; i < self.middleTickIndex; i++) {
        NSInteger previousLowest = self.middleTickIndex - i;
        NSInteger previousHighest = self.middleTickIndex + i;
        
        NSInteger nextLowest = self.middleTickIndex - (i + 1);
        NSInteger nextHighest = self.middleTickIndex + (i + 1);
        
        UIView *nextToLeft = self.tickViews[nextLowest];
        UIView *nextToRight = self.tickViews[nextHighest];
        
        UIView *previousToLeft = self.tickViews[previousLowest];
        UIView *previousToRight = self.tickViews[previousHighest];
        
        // Pin widths, heights, and bottoms.
        [self pinTickWidthAndHeight:nextToLeft];
        NSLayoutConstraint *leftBottom = [self pinTickBottom:nextToLeft];
        [bottoms insertObject:leftBottom atIndex:0];
        
        [self pinTickWidthAndHeight:nextToRight];
        NSLayoutConstraint *rightBottom = [self pinTickBottom:nextToRight];
        [bottoms addObject:rightBottom];
        
        // Pin the right of the next leftwards tick to the previous leftwards tick
        //1的右边与2的左边相差-(self.segmentWidth - HUMTickWidth)
        NSLayoutConstraint *left = [NSLayoutConstraint constraintWithItem:nextToLeft
                                                                attribute:NSLayoutAttributeRight
                                                                relatedBy:NSLayoutRelationEqual
                                                                   toItem:previousToLeft
                                                                attribute:NSLayoutAttributeLeft
                                                               multiplier:1
                                                                 constant:-(self.segmentWidth - HUMTickWidth)];
        [self addConstraint:left];
        [lefts addObject:left];
        
        // Pin the left of the next rightwards tick to the previous rightwards tick.
        NSLayoutConstraint *right = [NSLayoutConstraint constraintWithItem:nextToRight
                                                                 attribute:NSLayoutAttributeLeft
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:previousToRight
                                                                 attribute:NSLayoutAttributeRight
                                                                multiplier:1
                                                                  constant:(self.segmentWidth - HUMTickWidth)];
        [self addConstraint:right];
        [rights addObject:right];
        
    }
    
    self.allTickBottomConstraints = bottoms;
    self.leftTickRightConstraints = lefts;
    self.rightTickLeftConstraints = rights;
    
    [self layoutIfNeeded];
}

- (void)pinTickWidthAndHeight:(UIView *)currentTick
{
    // Pin width of tick
    [self addConstraint:[NSLayoutConstraint constraintWithItem:currentTick
                                                     attribute:NSLayoutAttributeWidth
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:nil
                                                     attribute:0
                                                    multiplier:1
                                                      constant:HUMTickWidth]];
    // Pin height of tick
    [self addConstraint:[NSLayoutConstraint constraintWithItem:currentTick
                                                     attribute:NSLayoutAttributeHeight
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:nil
                                                     attribute:0
                                                    multiplier:1
                                                      constant:HUMTickHeight]];
}

- (NSLayoutConstraint *)pinTickBottom:(UIView *)currentTick
{
    // Pin bottom of tick to top of track.
    NSLayoutConstraint *bottom = [NSLayoutConstraint constraintWithItem:currentTick
                                                              attribute:NSLayoutAttributeBottom
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:self
                                                              attribute:NSLayoutAttributeBottom
                                                             multiplier:1
                                                               constant:[self tickOutPosition]];
    [self addConstraint:bottom];
    return bottom;
}

#pragma mark - Images

- (void)setupSaturatedAndDesaturatedImageViews
{
    // Left
    self.leftDesaturatedImageView = [[UIImageView alloc] init];
    self.leftDesaturatedImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.leftDesaturatedImageView];
    
    self.leftSaturatedImageView = [[UIImageView alloc] init];
    self.leftSaturatedImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.leftSaturatedImageView.alpha = 0.0f;
    [self addSubview:self.leftSaturatedImageView];
    
    // Right
    self.rightDesaturatedImageView = [[UIImageView alloc] init];
    self.rightDesaturatedImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.rightDesaturatedImageView];
    
    self.rightSaturatedImageView = [[UIImageView alloc] init];
    self.rightSaturatedImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.rightSaturatedImageView.alpha = 0;
    [self addSubview:self.rightSaturatedImageView];
    
    // Pin desaturated image views.
    [self pinView:self.leftDesaturatedImageView toSuperViewAttribute:NSLayoutAttributeLeft];
    [self pinView:self.leftDesaturatedImageView toSuperViewAttribute:NSLayoutAttributeCenterY constant:HUMTickOutToInDifferential];
    [self pinView:self.rightDesaturatedImageView toSuperViewAttribute:NSLayoutAttributeRight];
    [self pinView:self.rightDesaturatedImageView toSuperViewAttribute:NSLayoutAttributeCenterY constant:HUMTickOutToInDifferential];
    
    // Pin saturated image views to desaturated image views.
    [self pinView1Center:self.leftSaturatedImageView toView2Center:self.leftDesaturatedImageView];
    [self pinView1Center:self.rightSaturatedImageView toView2Center:self.rightDesaturatedImageView];
    
    // Reset colors
    self.saturatedColor = self.saturatedColor;
    self.desaturatedColor = self.desaturatedColor;
}

- (void)sliderAdjusted
{
    CGFloat halfValue = (self.minimumValue + self.maximumValue) / 2.0f;
    
    if (self.value > halfValue) {
        self.rightSaturatedImageView.alpha = (self.value - halfValue) / halfValue;
        self.leftSaturatedImageView.alpha = 0;
    } else {
        self.leftSaturatedImageView.alpha = (halfValue - self.value) / halfValue;
        self.rightSaturatedImageView.alpha = 0;
    }
}

- (UIImage *)transparentImageOfSize:(CGSize)size
{
    if (CGSizeEqualToSize(size, CGSizeZero)) {
        return nil;
    }
    
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

#pragma mark - Superclass Overrides

- (CGSize)intrinsicContentSize
{
    CGFloat maxPoppedHeight = CGRectGetHeight([self thumbRectForBounds:self.bounds trackRect:[self trackRectForBounds:self.bounds] value:self.value]) + HUMTickHeight;
    
    CGFloat largestHeight = MAX(CGRectGetMaxY(self.rightSaturatedImageView.frame),
                                MAX(CGRectGetMaxY(self.leftSaturatedImageView.frame), maxPoppedHeight));
    return CGSizeMake(CGRectGetWidth(self.frame), largestHeight);
}

- (CGRect)minimumValueImageRectForBounds:(CGRect)bounds
{
    return self.leftDesaturatedImageView.frame;
}

- (CGRect)maximumValueImageRectForBounds:(CGRect)bounds
{
    return self.rightDesaturatedImageView.frame;
}

- (CGRect)trackRectForBounds:(CGRect)bounds
{
    CGRect superRect = [super trackRectForBounds:bounds];
    superRect.origin.y += HUMTickHeight;
    
    // Adjust the track rect so images are always a consistent padding.
    
    if (self.leftDesaturatedImageView) {
        CGFloat leftImageViewToTrackOrigin = CGRectGetMinX(superRect) - CGRectGetMaxX(self.leftDesaturatedImageView.frame);
        
        if (leftImageViewToTrackOrigin != HUMImagePadding) {
            CGFloat leftAdjust = leftImageViewToTrackOrigin - HUMImagePadding;
            superRect.origin.x -= leftAdjust;
            superRect.size.width += leftAdjust;
        }
    }
    
    if (self.rightDesaturatedImageView) {
        CGFloat endOfTrack = CGRectGetMaxX(superRect);
        CGFloat startOfRight = CGRectGetMinX(self.rightDesaturatedImageView.frame);
        CGFloat trackEndToRightImageView = startOfRight - endOfTrack;
        
        if (trackEndToRightImageView != HUMImagePadding) {
            CGFloat rightAdjust = trackEndToRightImageView - HUMImagePadding;
            superRect.size.width += rightAdjust;
        }
    }
    
    return superRect;
}

#pragma mark - Convenience

- (void)pinView:(UIView *)view toSuperViewAttribute:(NSLayoutAttribute)attribute
{
    [self pinView:view toSuperViewAttribute:attribute constant:0];
}

- (void)pinView:(UIView *)view toSuperViewAttribute:(NSLayoutAttribute)attribute constant:(CGFloat)constant
{
    [view.superview addConstraint:[NSLayoutConstraint constraintWithItem:view
                                                               attribute:attribute
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:view.superview
                                                               attribute:attribute
                                                              multiplier:1
                                                                constant:constant]];
}

- (void)pinView1Center:(UIView *)view1 toView2Center:(UIView *)view2
{
    [self addConstraint:[NSLayoutConstraint constraintWithItem:view1
                                                     attribute:NSLayoutAttributeCenterY
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:view2
                                                     attribute:NSLayoutAttributeCenterY
                                                    multiplier:1
                                                      constant:0]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:view1
                                                     attribute:NSLayoutAttributeCenterX
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:view2
                                                     attribute:NSLayoutAttributeCenterX
                                                    multiplier:1
                                                      constant:0]];
    
}

#pragma mark - General layout

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self updateLeftTickConstraintsIfNeeded];
}

- (void)updateLeftTickConstraintsIfNeeded
{
    NSLayoutConstraint *firstLeft = self.leftTickRightConstraints.firstObject;
    
    if (firstLeft.constant != (self.segmentWidth - HUMTickWidth)) {
        for (NSInteger i = 0; i < self.middleTickIndex; i++) {
            NSLayoutConstraint *leftConstraint = self.rightTickLeftConstraints[i];
            NSLayoutConstraint *rightConstraint = self.leftTickRightConstraints[i];
            leftConstraint.constant = (self.segmentWidth - HUMTickWidth);
            rightConstraint.constant = -(self.segmentWidth - HUMTickWidth);
        }
        
        [self layoutIfNeeded];
    } // else good to go.
}

#pragma mark - Overridden Setters

- (void)setValue:(float)value
{
    [super setValue:value];
    [self sliderAdjusted];
}
-(void)setSectionCount:(NSUInteger)largeSpaceCount small:(NSUInteger)smallSpaceCount{
    NSAssert(smallSpaceCount % 2 == 0, @"Must use an even number of sections!");
    _largeSpaceCount = largeSpaceCount;
    _smallSpaceCount = smallSpaceCount;
    [self setSectionCount:_largeSpaceCount * 2 - 1 + _smallSpaceCount];
}
- (void)setSectionCount:(NSUInteger)sectionCount
{
    // Warn the developer that they need to use an odd number of sections.
    NSAssert(sectionCount % 2 != 0, @"Must use an odd number of sections!");
    
    _sectionCount = sectionCount;
    
    [self nukeOldTicks];
    [self setupTicks];
    
    [self animateAllTicksIn:YES];//动画出现
    [self popTickIfNeededFromTouch:nil];//根据点击位置pop
    
}

- (void)setMinimumValueImage:(UIImage *)minimumValueImage
{
    if (!self.leftDesaturatedImageView) {
        [self setupSaturatedAndDesaturatedImageViews];
    }
    
    [super setMinimumValueImage:[self transparentImageOfSize:minimumValueImage.size]];
    self.leftTemplate = [minimumValueImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.leftSaturatedImageView.image = self.leftTemplate;
    self.leftDesaturatedImageView.image = self.leftTemplate;
    
    // Bring to the front or they'll get covered by the minimum value image.
    [self bringSubviewToFront:self.leftDesaturatedImageView];
    [self bringSubviewToFront:self.leftSaturatedImageView];
}

- (void)setMaximumValueImage:(UIImage *)maximumValueImage
{
    if (!self.leftDesaturatedImageView) {
        [self setupSaturatedAndDesaturatedImageViews];
    }
    
    [super setMaximumValueImage:[self transparentImageOfSize:maximumValueImage.size]];
    self.rightTemplate = [maximumValueImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.rightSaturatedImageView.image = self.rightTemplate;
    self.rightDesaturatedImageView.image = self.rightTemplate;
    
    // Bring to the front or they'll get covered by the minimum value image.
    [self bringSubviewToFront:self.rightDesaturatedImageView];
    [self bringSubviewToFront:self.rightSaturatedImageView];
}

- (void)setSaturatedColor:(UIColor *)saturatedColor
{
    _saturatedColor = saturatedColor;
    [self setSaturatedColor:saturatedColor forSide:HUMSliderSideLeft];
    [self setSaturatedColor:saturatedColor forSide:HUMSliderSideRight];
}

- (void)setDesaturatedColor:(UIColor *)desaturatedColor
{
    _desaturatedColor = desaturatedColor;
    [self setDesaturatedColor:desaturatedColor forSide:HUMSliderSideLeft];
    [self setDesaturatedColor:desaturatedColor forSide:HUMSliderSideRight];
}

#pragma mark - Setters for colors on different sides.

- (void)setSaturatedColor:(UIColor *)saturatedColor forSide:(HUMSliderSide)side
{
    switch (side) {
        case HUMSliderSideLeft:
            self.leftSaturatedColor = saturatedColor;
            break;
        case HUMSliderSideRight:
            self.rightSaturatedColor = saturatedColor;
            break;
    }
    
    [self imageViewForSide:side saturated:YES].tintColor = saturatedColor;
}

- (UIColor *)saturatedColorForSide:(HUMSliderSide)side
{
    switch (side) {
        case HUMSliderSideLeft:
            return self.leftSaturatedColor;
            break;
        case HUMSliderSideRight:
            return self.rightSaturatedColor;
            break;
    }
}

- (void)setDesaturatedColor:(UIColor *)desaturatedColor forSide:(HUMSliderSide)side
{
    switch (side) {
        case HUMSliderSideLeft:
            self.leftDesaturatedColor = desaturatedColor;
            break;
        case HUMSliderSideRight:
            self.rightDesaturatedColor = desaturatedColor;
            break;
    }
    
    [self imageViewForSide:side saturated:NO].tintColor = desaturatedColor;
}

- (UIColor *)desaturatedColorForSide:(HUMSliderSide)side
{
    switch (side) {
        case HUMSliderSideLeft:
            return self.leftDesaturatedColor;
            break;
        case HUMSliderSideRight:
            return self.rightDesaturatedColor;
            break;
    }
}

- (UIImageView *)imageViewForSide:(HUMSliderSide)side saturated:(BOOL)saturated
{
    switch (side) {
        case HUMSliderSideLeft:
            if (saturated) {
                return self.leftSaturatedImageView;
            } else {
                return self.leftDesaturatedImageView;
            }
            break;
        case HUMSliderSideRight:
            if (saturated) {
                return self.rightSaturatedImageView;
            } else {
                return self.rightDesaturatedImageView;
            }
            break;
    }
}

- (void)setTickColor:(UIColor *)tickColor
{
    _tickColor = tickColor;
    if (self.tickViews) {
        for (UIView *tick in self.tickViews) {
            tick.backgroundColor = _tickColor;
        }
    }
}

#pragma mark - UIControl touch event tracking
#pragma mark Animate In
//UISlider与UIControl不太一样，只有触摸thumb时，才会调用continue...、end...
- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    // Update the width
    [self updateLeftTickConstraintsIfNeeded];
    [self animateAllTicksIn:YES];//动画出现
    [self popTickIfNeededFromTouch:touch];//根据点击位置pop
    
    return [super beginTrackingWithTouch:touch withEvent:event];
}

- (void)animateTickIfNeededAtIndex:(NSInteger)tickIndex forTouchX:(CGFloat)touchX
{
    //根据thumb的中心坐标touchX，设置每个tick的高度
    UIView *tick = self.tickViews[tickIndex];
    CGFloat startSegmentX = (tickIndex * self.segmentWidth) + self.trackXOrigin;
    CGFloat endSegmentX = startSegmentX + self.segmentWidth;
    
    CGFloat desiredOrigin;
    if (startSegmentX <= touchX && endSegmentX > touchX) {
        // Pop up.
        desiredOrigin = [self tickPoppedPosition];
    } else {
        // Bring down.
        desiredOrigin = [self tickInNotPoppedPositon];
    }
    
    if (CGRectGetMinY(tick.frame) != desiredOrigin) {
        [self animateTickAtIndex:tickIndex
                       toYOrigin:desiredOrigin
                    withDuration:self.tickMovementAnimationDuration
                           delay:0];
    } // else tick is already where it needs to be.
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    [self popTickIfNeededFromTouch:touch];
    return [super continueTrackingWithTouch:touch withEvent:event];
}

- (void)popTickIfNeededFromTouch:(UITouch *)touch
{
    // Figure out where the hell the thumb is.
    CGRect trackRect = [self trackRectForBounds:self.bounds];
    CGRect thumbRect = [self thumbRectForBounds:self.bounds
                                      trackRect:trackRect
                                          value:self.value];
    //在拖动thumb时，sliderLoc是thumb的中心坐标
    CGFloat sliderLoc = CGRectGetMidX(thumbRect);
    
    // Animate tick based on the thumb location
    for (NSInteger i = 0; i < self.tickViews.count; i++) {
        [self animateTickIfNeededAtIndex:i forTouchX:sliderLoc];
    }
}

#pragma mark Animate Out

- (void)cancelTrackingWithEvent:(UIEvent *)event
{
    [self returnPosition];
    
    [super cancelTrackingWithEvent:event];
    
    //只需要改animateBlock中duration，即可改变popUpviews的移动速度
    
    [self setValue:[self stepValueForCurrentValue] animated:NO];//duration depends on distance. does not send action
    [self.parasitic setValue:[self stepValueForCurrentValue] animated:YES];//AS的yes才会动画调整arrowOffset
    [self popTickIfNeededFromTouch:nil];

}

-(void)setStep:(NSUInteger)step{//0 1 ~ 13
    //step即非hidden的tick序号
    /*
     step = 3
     large = 4
     step  0   1   2   3   4   5
     index 0 1 2 3 4 5 6   7   8
     */
    NSUInteger tickIndex = NSNotFound;
    if (step <= self.largeSpaceCount - 1) {
        tickIndex = step * 2;
    }else{
        /*
         step = 5
         large = 4
         index = ?
         */
        tickIndex = (self.largeSpaceCount - 1) *2 + (step - self.largeSpaceCount + 1);
    }
    CGFloat tickCenter = [[self.tickViews objectAtIndex:tickIndex] center].x;
    CGFloat value = [self valueForX:tickCenter];
    [self setValue:value animated:NO];//duration depends on distance. does not send action
    [self.parasitic setValue:[self stepValueForCurrentValue] animated:YES];
    [self popTickIfNeededFromTouch:nil];
}
//求step
-(NSInteger)getStep{
    //value转x
    CGRect thumbRect = [self thumbRectForBounds:self.bounds trackRect:[self trackRectForBounds:self.bounds] value:self.value];
    CGFloat valueCenter = CGRectGetMidX(thumbRect);
    //x找到停靠x
    __block CGFloat nearest = NSIntegerMax;
    __block CGFloat stepX = 0;
    __block NSInteger stepIndex = 0;
    __block NSInteger nowStep = 0;
    [self.tickViews enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if (!((UIView *)obj).hidden) {
            
            
            CGFloat tickCenter = [obj center].x;
            CGFloat distance = fabs(valueCenter - tickCenter);
            if (distance < nearest) {
                nearest = distance;
                stepX = tickCenter;
                nowStep = stepIndex;
            }
            stepIndex++;//第stepIndex个不hidden的tick
        }
        
    }];
    return nowStep;
}
//根据value获得X，根据X获得最近的step的X，根据step的x找到对应的value，然后重新设置value
-(CGFloat)stepValueForCurrentValue{
    //value转x
    CGRect thumbRect = [self thumbRectForBounds:self.bounds trackRect:[self trackRectForBounds:self.bounds] value:self.value];
    CGFloat valueCenter = CGRectGetMidX(thumbRect);
    //x找到停靠x
    __block CGFloat nearest = NSIntegerMax;
    __block CGFloat stepX = 0;
    [self.tickViews enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (!((UIView *)obj).hidden) {
            CGFloat tickCenter = [obj center].x;
            CGFloat distance = fabs(valueCenter - tickCenter);
            if (distance < nearest) {
                nearest = distance;
                stepX = tickCenter;
            }
        }
        
    }];
    //停靠x找到value
    CGFloat stepValue = [self valueForX:stepX];
    return stepValue;
}
-(CGFloat)valueForX:(CGFloat)x{
    CGFloat xforMinValue = CGRectGetMidX([self thumbRectForBounds:self.bounds trackRect:[self trackRectForBounds:self.bounds] value:self.minimumValue]);
    
    CGFloat xforMaxValue = CGRectGetMidX([self thumbRectForBounds:self.bounds trackRect:[self trackRectForBounds:self.bounds] value:self.maximumValue]);
    
    return self.maximumValue * ((x - xforMinValue) / (xforMaxValue - xforMinValue));
}
- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    [self returnPosition];
    
    [super endTrackingWithTouch:touch withEvent:event];
    
    //只需要改animateBlock中duration，即可改变popUpviews的移动速度
    
    [self setValue:[self stepValueForCurrentValue] animated:NO];//duration depends on distance. does not send action
    [self.parasitic setValue:[self stepValueForCurrentValue] animated:YES];//AS的yes才会动画调整arrowOffset
    [self popTickIfNeededFromTouch:nil];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self returnPosition];
    
    [super touchesEnded:touches withEvent:event];
}

- (void)returnPosition
{
    //    [self animateAllTicksIn:NO];
}

#pragma mark - Tick Animation

- (void)animateAllTicksIn:(BOOL)inPosition
{
    CGFloat origin;
    CGFloat alpha;
    
    if (inPosition) { // Ticks are out, coming in
        alpha = 1;
        origin = [self tickInNotPoppedPositon];
    } else { // Ticks are in, coming out.
        alpha = 0;
        origin = [self tickOutPosition];
    }
    
    [UIView animateWithDuration:self.tickAlphaAnimationDuration
                     animations:^{
                         for (UIView *tick in self.tickViews) {
                             tick.alpha = alpha;
                         }
                     } completion:nil];
    
    for (NSInteger i = 0; i <= self.middleTickIndex; i++) {
        NSInteger nextHighest = self.middleTickIndex + i;
        NSInteger nextLowest = self.middleTickIndex - i;
        if (nextHighest == nextLowest) {
            // Middle tick
            [self animateTickAtIndex:nextHighest
                           toYOrigin:origin
                        withDuration:self.tickMovementAnimationDuration
                               delay:0];
        } else if (nextHighest - nextLowest == 2) {
            // Second tick
            [self animateTickAtIndex:nextHighest
                           toYOrigin:origin
                        withDuration:self.secondTickMovementAndimationDuration
                               delay:self.nextTickAnimationDelay * i];
            [self animateTickAtIndex:nextLowest
                           toYOrigin:origin
                        withDuration:self.secondTickMovementAndimationDuration
                               delay:self.nextTickAnimationDelay * i];
        } else {
            // Rest of ticks
            [self animateTickAtIndex:nextHighest
                           toYOrigin:origin
                        withDuration:self.tickMovementAnimationDuration
                               delay:self.nextTickAnimationDelay * i];
            [self animateTickAtIndex:nextLowest
                           toYOrigin:origin
                        withDuration:self.tickMovementAnimationDuration
                               delay:self.nextTickAnimationDelay * i];
        }
    }
}

- (void)animateTickAtIndex:(NSInteger)index
                 toYOrigin:(CGFloat)yOrigin
              withDuration:(NSTimeInterval)duration
                     delay:(NSTimeInterval)delay
{
    
    
    NSLayoutConstraint *constraint = self.allTickBottomConstraints[index];
    constraint.constant = yOrigin;
    //同步ASValueTrackingSlider
    [UIView animateWithDuration:0.1 animations:^{
        [self layoutIfNeeded];
    }];
//    [UIView animateWithDuration:duration
//                          delay:delay
//         usingSpringWithDamping:0.6f
//          initialSpringVelocity:0.0f
//                        options:UIViewAnimationOptionCurveLinear
//                     animations:^{
//                         [self layoutIfNeeded];
//                     }
//                     completion:nil];
}

#pragma mark - Calculation helpers

- (CGFloat)trackXOrigin
{
    CGRect trackRect = [self trackRectForBounds:self.bounds];
    return CGRectGetMinX(trackRect);
}

- (CGFloat)trackYOrigin
{
    CGRect trackRect = [self trackRectForBounds:self.bounds];
    return CGRectGetMinY(trackRect);
}

- (CGFloat)segmentWidth
{
    CGRect trackRect = [self trackRectForBounds:self.bounds];
    return floorf(CGRectGetWidth(trackRect) / self.sectionCount);
}

- (NSInteger)middleTickIndex
{
    return floor(self.tickViews.count / 2);
}

- (CGFloat)thumbHeight
{
    CGRect thumbRect = [self thumbRectForBounds:self.bounds
                                      trackRect:[self trackRectForBounds:self.bounds]
                                          value:self.value];
    return CGRectGetHeight(thumbRect);
}

- (CGFloat)tickInToPoppedDifferential
{
    CGFloat halfThumb = [self thumbHeight] / 2.0f;
    CGFloat inToUp = halfThumb - HUMTickOutToInDifferential;
    
    return inToUp;
}

- (CGFloat)tickOutPosition
{
    return -(CGRectGetMaxY(self.bounds) - [self trackYOrigin]);
}

- (CGFloat)tickInNotPoppedPositon
{
    return [self tickOutPosition] - HUMTickOutToInDifferential + HUMTickHeight / 2;
}

- (CGFloat)tickPoppedPosition
{
    return [self tickInNotPoppedPositon] - [self tickInToPoppedDifferential] + self.pointAdjustmentForCustomThumb;
}

@end
