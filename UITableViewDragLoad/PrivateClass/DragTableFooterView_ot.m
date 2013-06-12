//
//  DragRefreshTableFooterView_ot.m
//  LoadMore
//
//  Created by openthread on 2/12/13.
//  Copyright (c) 2013 CannonInc. All rights reserved.
//

#import "DragTableFooterView_ot.h"
#import "DragTableDragState_ot.h"

#define TEXT_COLOR                          [UIColor colorWithRed:87.0/255.0 green:108.0/255.0 blue:137.0/255.0 alpha:1.0]
#define FLIP_ANIMATION_DURATION             (0.18f)

@implementation DragTableFooterView_ot
{
	DragTableDragState_ot _state;
    BOOL _isLoading;
    
	UILabel *_statusLabel;
	UIActivityIndicatorView *_activityView;
}
@synthesize isLoading = _isLoading;

#pragma mark - UIs
- (UILabel *)loadingStatusLabel
{
    return _statusLabel;
}

- (UIView *)loadingIndicator
{
    return _activityView;
}

#pragma mark - Events

- (CGFloat)footerVisbleHeightInScrollView:(UIScrollView *)scrollView
{
    return CGRectGetHeight(scrollView.frame) - (CGRectGetMinY(self.frame) - scrollView.contentOffset.y);
}

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        _isLoading = NO;
        
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		self.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:237.0/255.0 alpha:1.0];
        
		_statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 12.0f, self.frame.size.width, 20.0f)];
		_statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		_statusLabel.font = [UIFont boldSystemFontOfSize:13.0f];
		_statusLabel.textColor = TEXT_COLOR;
		_statusLabel.shadowColor = [UIColor colorWithWhite:0.9f alpha:1.0f];
		_statusLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
		_statusLabel.backgroundColor = [UIColor clearColor];
		_statusLabel.textAlignment = UITextAlignmentCenter;
		[self addSubview:_statusLabel];
		
        _activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		_activityView.frame = CGRectMake(25.0f, 10.0f, 20.0f, 20.0f);
		[self addSubview:_activityView];
		
		[self setState:DragTableDragStateNormal_ot];
    }
    return self;
}

- (void)setState:(DragTableDragState_ot)aState
{
	switch (aState)
    {
		case DragTableDragStatePulling_ot:
        {
			_statusLabel.text = NSLocalizedString(@"Release to load more...", @"Release to load more status");
        }
			break;
		case DragTableDragStateNormal_ot:
        {
			_statusLabel.text = NSLocalizedString(@"Pull up to load more...", @"Pull down to load more status");
			[_activityView stopAnimating];
        }
			break;
		case DragTableDragStateLoading_ot:
        {
			_statusLabel.text = NSLocalizedString(@"Loading...", @"Loading Status");
			[_activityView startAnimating];
        }
			break;
		default:
			break;
	}
	_state = aState;
}

- (void)dragTableDidScroll:(UIScrollView *)scrollView
{
    if (_state != DragTableDragStateLoading_ot && scrollView.isDragging)
    {
		BOOL _loading = _isLoading;
		if (_state == DragTableDragStatePulling_ot && [self footerVisbleHeightInScrollView:scrollView] < LOADMORE_TRIGGER_HEIGHT && !_loading)
        {
			[self setState:DragTableDragStateNormal_ot];
		}
        else if (_state == DragTableDragStateNormal_ot && [self footerVisbleHeightInScrollView:scrollView] > LOADMORE_TRIGGER_HEIGHT && !_loading)
        {
			[self setState:DragTableDragStatePulling_ot];
		}
	}
}

- (void)dragTableDidEndDragging:(UIScrollView *)scrollView
{
	BOOL _loading = _isLoading;
    CGFloat footerVisibleHeight = [self footerVisbleHeightInScrollView:scrollView];
	if (footerVisibleHeight >= LOADMORE_TRIGGER_HEIGHT && !_loading)
    {
		if ([_delegate respondsToSelector:@selector(dragTableFooterDidTriggerLoadMore:)])
        {
			[_delegate dragTableFooterDidTriggerLoadMore:self];
            _isLoading = YES;
		}
		[self setState:DragTableDragStateLoading_ot];
        
        CGFloat contentInsetHeightAdder = scrollView.frame.size.height - scrollView.contentSize.height;
        contentInsetHeightAdder = MAX(0, contentInsetHeightAdder);
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.2];
        [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
		scrollView.contentInset = UIEdgeInsetsMake(0.0f, 0.0f, LOADMORE_TRIGGER_HEIGHT + contentInsetHeightAdder, 0.0f);
		[UIView commitAnimations];
	}
}

- (void)triggerLoading:(UIScrollView *)scrollView
{
    [scrollView setContentOffset:CGPointMake(scrollView.contentOffset.x, LOADMORE_TRIGGER_HEIGHT)];
    [self dragTableDidEndDragging:scrollView];
}

//Prevent animation conflict when refresh triggerd. Pass `NO` to `shouldChangeContentInset` when refresh triggered.
- (void)endLoading:(UIScrollView *)scrollView shouldChangeContentInset:(BOOL)shouldChangeContentInset
{
    if (_isLoading)
    {
        if (shouldChangeContentInset)
        {
            NSString *edgeInsetString = NSStringFromUIEdgeInsets(UIEdgeInsetsZero);
            NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:
                                 scrollView, @"scrollView",
                                 edgeInsetString, @"edgeInset",
                                 nil];
            [self performSelector:@selector(setScrollViewContentInset:) withObject:dic afterDelay:0];
        }
        _isLoading = NO;
    }
	[self setState:DragTableDragStateNormal_ot];
}

//For set `contentInset` with delay usage.
//Prevent call [table reloadData] and `endLoading:shouldChangeContentInset:` at the same runloop.
//If [table reloadData] and [table setContentInset"] at the same runloop, `contentOffset` behaves strangely.
- (void)setScrollViewContentInset:(NSDictionary *)dic
{
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    UIScrollView *scrollView = dic[@"scrollView"];
    NSString *edgeInsetString = dic[@"edgeInset"];
    UIEdgeInsets edgeInset = UIEdgeInsetsFromString(edgeInsetString);
    [scrollView setContentInset:edgeInset];
    [UIView commitAnimations];
}

@end
