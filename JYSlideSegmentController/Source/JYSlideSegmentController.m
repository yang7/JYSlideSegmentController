//
//  JYSlideSegmentController.m
//  JYSlideSegmentController
//
//  Created by Alvin on 14-3-16.
//  Copyright (c) 2014年 Alvin. All rights reserved.
//

#import "JYSlideSegmentController.h"

NSString * const JYSegmentBarItemID = @"JYSegmentBarItem";
NSString * const JYSlideViewItemID = @"JYSlideViewItemID";

@interface JYSegmentBarItem : UICollectionViewCell

@property (nonatomic, strong) UILabel *titleLabel;

@end


@implementation JYSegmentBarItem

- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    [self.contentView addSubview:self.titleLabel];
    [self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.titleLabel
                                                                 attribute:NSLayoutAttributeCenterX
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:self.contentView
                                                                 attribute:NSLayoutAttributeCenterX
                                                                multiplier:1
                                                                  constant:0]];
    [self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.titleLabel
                                                                 attribute:NSLayoutAttributeCenterY
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:self.contentView
                                                                 attribute:NSLayoutAttributeCenterY
                                                                multiplier:1
                                                                  constant:0]];
  }
  return self;
}

- (UILabel *)titleLabel
{
  if (!_titleLabel) {
    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  }
  return _titleLabel;
}

@end

@implementation JYSlideView

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer == self.panGestureRecognizer) {
    if ([self.slideDelegate
            respondsToSelector:
                @selector(slideViewPanGestureRecognizerShouldBegin:)]) {
      return [self.slideDelegate
          slideViewPanGestureRecognizerShouldBegin:gestureRecognizer];
    }
  }
  return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:
        (UIGestureRecognizer *)otherGestureRecognizer
{
  if (gestureRecognizer == self.panGestureRecognizer) {
    if ([self.slideDelegate
            respondsToSelector:
                @selector(slideViewPanGestureRecognizer:
                    shouldRecognizeSimultaneouslyWithGestureRecognizer:)]) {
      return [self.slideDelegate slideViewPanGestureRecognizer:gestureRecognizer
            shouldRecognizeSimultaneouslyWithGestureRecognizer:
                otherGestureRecognizer];
    }
  }
  return YES;
}

@end

@interface JYSlideSegmentController ()
<UICollectionViewDataSource, UICollectionViewDelegate, UIScrollViewDelegate>

@property (nonatomic, strong, readwrite) UICollectionView *segmentBar;
@property (nonatomic, strong, readwrite) JYSlideView *slideView;

@property (nonatomic, strong) UIView *indicator;
@property (nonatomic, strong) UIView *separator;

@property (nonatomic, strong) UICollectionViewFlowLayout *segmentBarLayout;
@property (nonatomic, strong) UICollectionViewFlowLayout *slideViewLayout;

@property (nonatomic, assign) CGPoint lastContentOffset;
@property (nonatomic, assign) NSInteger previousIndex;

- (void)reset;

@end

@implementation JYSlideSegmentController
@synthesize separatorColor = _separatorColor;

- (instancetype)initWithViewControllers:(NSArray *)viewControllers
{
  return [self initWithViewControllers:viewControllers startIndex:0];
}

- (instancetype)initWithViewControllers:(NSArray *)viewControllers
                             startIndex:(NSInteger)startIndex
{
  NSParameterAssert(startIndex < viewControllers.count);
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _viewControllers = [viewControllers copy];
    _startIndex = startIndex;
    _indicatorType = JYIndicatorWidthTypeInset;
    _lastContentOffset = CGPointZero;
    _previousIndex = NSNotFound;
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  [self configSubviews];
  [self configObservers];
  [self setSelectedIndex:self.startIndex];
}

- (void)dealloc
{
  [self removeObserver:self forKeyPath:@"slideView.contentOffset"];
  [self removeObserver:self forKeyPath:@"segmentBar.contentOffset"];
}

#pragma mark - Setup
- (void)configSubviews
{
  [self.view addSubview:self.segmentBar];
  [self.view addSubview:self.slideView];
  [self.view addSubview:self.separator];
  [self.view addSubview:self.indicator];
  [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.segmentBar
                                                        attribute:NSLayoutAttributeLeft
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:self.view
                                                        attribute:NSLayoutAttributeLeft
                                                       multiplier:1
                                                         constant:0]];
  [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.segmentBar
                                                        attribute:NSLayoutAttributeRight
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:self.view
                                                        attribute:NSLayoutAttributeRight
                                                       multiplier:1
                                                         constant:0]];
  [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.segmentBar
                                                        attribute:NSLayoutAttributeTop
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:self.view
                                                        attribute:NSLayoutAttributeTop
                                                       multiplier:1
                                                         constant:0]];
  [self.segmentBar addConstraint:[NSLayoutConstraint constraintWithItem:self.segmentBar
                                                              attribute:NSLayoutAttributeHeight
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:nil
                                                              attribute:NSLayoutAttributeNotAnAttribute
                                                             multiplier:1
                                                               constant:self.segmentHeight]];
  
  [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.slideView
                                                        attribute:NSLayoutAttributeLeft
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:self.view
                                                        attribute:NSLayoutAttributeLeft
                                                       multiplier:1
                                                         constant:0]];
  [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.slideView
                                                        attribute:NSLayoutAttributeRight
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:self.view
                                                        attribute:NSLayoutAttributeRight
                                                       multiplier:1
                                                         constant:0]];
  [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.slideView
                                                        attribute:NSLayoutAttributeBottom
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:self.view
                                                        attribute:NSLayoutAttributeBottom
                                                       multiplier:1
                                                         constant:0]];
  [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.segmentBar
                                                        attribute:NSLayoutAttributeBottom
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:self.slideView
                                                        attribute:NSLayoutAttributeTop
                                                       multiplier:1
                                                         constant:0]];
  
  [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.separator
                                                        attribute:NSLayoutAttributeLeft
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:self.segmentBar
                                                        attribute:NSLayoutAttributeLeft
                                                       multiplier:1
                                                         constant:0]];
  [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.separator
                                                        attribute:NSLayoutAttributeRight
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:self.segmentBar
                                                        attribute:NSLayoutAttributeRight
                                                       multiplier:1
                                                         constant:0]];
  [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.separator
                                                        attribute:NSLayoutAttributeBottom
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:self.segmentBar
                                                        attribute:NSLayoutAttributeBottom
                                                       multiplier:1
                                                         constant:0]];
  [self.separator addConstraint:[NSLayoutConstraint constraintWithItem:self.separator
                                                             attribute:NSLayoutAttributeHeight
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:nil
                                                             attribute:NSLayoutAttributeNotAnAttribute
                                                            multiplier:1
                                                              constant:self.separatorHeight]];
  
  [self.segmentBar registerClass:[JYSegmentBarItem class] forCellWithReuseIdentifier:JYSegmentBarItemID];
  [self.slideView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:JYSlideViewItemID];
  [self.separator setBackgroundColor:self.separatorColor];
  
  self.automaticallyAdjustsScrollViewInsets = NO;
  self.edgesForExtendedLayout = UIRectEdgeNone;
  [self.slideView layoutIfNeeded];
  [self.segmentBar layoutIfNeeded];
}

- (void)configObservers
{
  [self addObserver:self forKeyPath:@"slideView.contentOffset" options:NSKeyValueObservingOptionNew context:nil];
  [self addObserver:self forKeyPath:@"segmentBar.contentOffset" options:NSKeyValueObservingOptionNew context:nil];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
  CGPoint contentOffset = self.slideView.contentOffset;
  CGFloat direction = self.lastContentOffset.x - contentOffset.x > 0 ? -1.0 : 1.0;
  CGFloat slideViewWidth = self.slideView.frame.size.width;
  NSInteger selectedIndex = self.selectedIndex;
  CGFloat progress = direction * (contentOffset.x - selectedIndex * slideViewWidth) / slideViewWidth;
  CGFloat x = selectedIndex * self.segmentWidth - self.segmentBar.contentOffset.x;
  CGFloat y = CGRectGetMaxY(self.segmentBar.frame) - self.indicatorHeight - self.indicatorInsets.bottom;
  CGFloat w = self.indicatorType == JYIndicatorWidthTypeFixed
                ? self.indicatorWidth
                : self.segmentWidth - self.indicatorInsets.left - self.indicatorInsets.right;
  if (0 < progress && progress < 0.5) {
    // stretch to right
    x += progress * self.segmentWidth;
    w += progress * self.segmentWidth;
  } else if(progress >= 0.5 && progress < 1) {
    // shrink to right
    CGFloat percentage = contentOffset.x / MAX(self.slideView.contentSize.width, self.view.bounds.size.width);
    x = percentage * self.segmentBar.contentSize.width - self.segmentBar.contentOffset.x;
    w += (1 - progress) * self.segmentWidth;
  } else if (-0.5 < progress && progress < 0) {
    // shrink to left
    x -= progress * self.segmentWidth;
    w -= progress * self.segmentWidth;
  } else if (-1.0 < progress && progress <= -0.5) {
    // stretch to left
    CGFloat percentage = contentOffset.x / MAX(self.slideView.contentSize.width, self.view.bounds.size.width);
    x = percentage * self.segmentBar.contentSize.width - self.segmentBar.contentOffset.x;
    w += (1 + progress) * self.segmentWidth;
  }
  
  // add padding
  x += (self.segmentWidth - w) / 2;
  
  CGRect indicatorFrame = CGRectMake(x, y, w, self.indicatorHeight);
  self.indicator.frame = indicatorFrame;
  
  if ([keyPath isEqualToString:@"slideView.contentOffset"]) {
    // recoard last content offset to adjust direction
    self.lastContentOffset = contentOffset;
  }
}

#pragma mark - Property
- (JYSlideView *)slideView
{
  if (!_slideView) {
    _slideView = [[JYSlideView alloc] initWithFrame:CGRectZero collectionViewLayout:self.slideViewLayout];
    _slideView.scrollEnabled = _viewControllers.count > 1 ? YES : NO;
    _slideView.scrollsToTop = NO;
    [_slideView setShowsHorizontalScrollIndicator:NO];
    [_slideView setShowsVerticalScrollIndicator:NO];
    [_slideView setPagingEnabled:YES];
    [_slideView setBounces:NO];
    [_slideView setDelegate:self];
    [_slideView setDataSource:self];
    [_slideView setTranslatesAutoresizingMaskIntoConstraints:NO];
    _slideView.backgroundColor = [UIColor whiteColor];
  }
  return _slideView;
}

- (UICollectionView *)segmentBar
{
  if (!_segmentBar) {
    _segmentBar = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:self.segmentBarLayout];
    _segmentBar.backgroundColor = [UIColor whiteColor];
    _segmentBar.delegate = self;
    _segmentBar.dataSource = self;
    _segmentBar.showsHorizontalScrollIndicator = NO;
    _segmentBar.showsVerticalScrollIndicator = NO;
    _segmentBar.scrollsToTop = NO;
    _segmentBar.translatesAutoresizingMaskIntoConstraints = NO;
  }
  return _segmentBar;
}

- (UIView *)indicator
{
  if (!_indicator) {
    _indicator = [[UIView alloc] initWithFrame:CGRectZero];
    _indicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    _indicator.backgroundColor = self.indicatorColor ? : [UIColor yellowColor];
  }
  return _indicator;
}

- (UIView *)separator
{
  if (!_separator) {
    _separator = [[UIView alloc] initWithFrame:CGRectZero];
    [_separator setTranslatesAutoresizingMaskIntoConstraints:NO];
  }
  return _separator;
}

- (CGFloat)indicatorHeight
{
  if (!_indicatorHeight) {
    _indicatorHeight = 3;
  }
  return _indicatorHeight;
}

- (CGFloat)segmentHeight
{
  if (!_segmentHeight) {
    _segmentHeight = 40;
  }
  return _segmentHeight;
}

- (CGFloat)separatorHeight
{
    if (!_separatorHeight) {
        _separatorHeight = 1.0 / [UIScreen mainScreen].scale;
    }
    return _separatorHeight;
}

- (CGFloat)segmentWidth
{
  if (!_segmentWidth) {
    _segmentWidth = self.view.frame.size.width / self.viewControllers.count;
  }
  return _segmentWidth;
}

- (void)setIndicatorColor:(UIColor *)indicatorColor
{
  _indicatorColor = indicatorColor;
  _indicator.backgroundColor = _indicatorColor;
}

- (UIColor *)separatorColor
{
  if (!_separatorColor) {
    _separatorColor = [UIColor lightGrayColor];
  }
  return _separatorColor;
}

- (void)setSeparatorColor:(UIColor *)separatorColor
{
  _separatorColor = separatorColor;
  _separator.backgroundColor = _separatorColor;
}

- (UICollectionViewFlowLayout *)segmentBarLayout
{
  if (!_segmentBarLayout) {
    _segmentBarLayout = [[UICollectionViewFlowLayout alloc] init];
    _segmentBarLayout.sectionInset = _segmentInsets;
    _segmentBarLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    _segmentBarLayout.minimumLineSpacing = 0;
    _segmentBarLayout.minimumInteritemSpacing = 0;
  }
  return _segmentBarLayout;
}

- (UICollectionViewFlowLayout *)slideViewLayout
{
  if (!_slideViewLayout) {
    _slideViewLayout = [[UICollectionViewFlowLayout alloc] init];
    _slideViewLayout.sectionInset = UIEdgeInsetsZero;
    _slideViewLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    _slideViewLayout.minimumLineSpacing = 0;
    _slideViewLayout.minimumInteritemSpacing = 0;
  }
  return _slideViewLayout;
}

- (void)setSelectedIndex:(NSInteger)selectedIndex
{
  [self scrollToViewWithIndex:selectedIndex animated:NO];
}

- (NSInteger)selectedIndex
{
  return floor(self.slideView.contentOffset.x / MAX(self.slideView.bounds.size.width, self.view.bounds.size.width));
}

- (void)setViewControllers:(NSArray *)viewControllers
{
  // Need remove previous viewControllers
  for (UIViewController *vc in _viewControllers) {
      [vc willMoveToParentViewController:nil];
      [vc.view removeFromSuperview];
      [vc removeFromParentViewController];
      [vc didMoveToParentViewController:nil];
  }
  _viewControllers = [viewControllers copy];
  [self reset];
}

- (UIViewController *)selectedViewController
{
  if (self.selectedIndex < self.viewControllers.count) {
    return self.viewControllers[self.selectedIndex];
  }
  return nil;
}

#pragma mark - UICollectionViewDataSource
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  if ([_dataSource respondsToSelector:@selector(numberOfSectionsInslideSegment:)]) {
    return [_dataSource numberOfSectionsInslideSegment:collectionView];
  }
  return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  if ([_dataSource respondsToSelector:@selector(slideSegment:numberOfItemsInSection:)]) {
    return [_dataSource slideSegment:collectionView numberOfItemsInSection:section];
  }
  return self.viewControllers.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  if (collectionView == self.segmentBar) {
    if ([_dataSource respondsToSelector:@selector(slideSegment:cellForItemAtIndexPath:)]) {
      return [_dataSource slideSegment:collectionView cellForItemAtIndexPath:indexPath];
    }
    
    JYSegmentBarItem *segmentBarItem = [collectionView dequeueReusableCellWithReuseIdentifier:JYSegmentBarItemID
                                                                                 forIndexPath:indexPath];
    UIViewController *vc = self.viewControllers[indexPath.row];
    segmentBarItem.titleLabel.text = vc.title;
    return segmentBarItem;
  }
  // slide
  UICollectionViewCell *slideViewItemCell = [collectionView dequeueReusableCellWithReuseIdentifier:JYSlideViewItemID
                                                                                      forIndexPath:indexPath];
  return slideViewItemCell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  if (collectionView == self.segmentBar) {
    if ([_dataSource respondsToSelector:@selector(slideSegment:layout:sizeForItemAtIndexPath:)]) {
      return [_dataSource slideSegment:collectionView layout:collectionViewLayout sizeForItemAtIndexPath:indexPath];
    }
    return CGSizeMake(self.segmentWidth, self.segmentHeight);
  }
  // sub vc frame
  return self.slideView.bounds.size;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
  if (collectionView == self.slideView) {
    return;
  }
  if (indexPath.row < 0 || indexPath.row >= self.viewControllers.count) {
    return;
  }
  if ([_delegate respondsToSelector:@selector(slideSegment:didSelectItemAtIndexPath:)]) {
    [_delegate slideSegment:collectionView didSelectItemAtIndexPath:indexPath];
  }
  [self scrollToViewWithIndex:indexPath.row animated:YES];
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
  if (collectionView == self.slideView) {
    return NO;
  }
  if (indexPath.row < 0 || indexPath.row >= self.viewControllers.count) {
    return NO;
  }

  BOOL flag = YES;
  UIViewController *vc = self.viewControllers[indexPath.row];
  if ([_delegate respondsToSelector:@selector(shouldSelectViewController:)]) {
    flag = [_delegate shouldSelectViewController:vc];
  }
  return flag;
}

- (void)collectionView:(UICollectionView *)collectionView
       willDisplayCell:(UICollectionViewCell *)cell
    forItemAtIndexPath:(NSIndexPath *)indexPath
{
  if (collectionView == self.segmentBar) {
    return;
  }
  
  UIViewController *toSelectController = self.viewControllers[indexPath.row];
  if (!toSelectController.parentViewController) {
    [self addChildViewController:toSelectController];
    [cell.contentView addSubview:toSelectController.view];
    [toSelectController.view setTranslatesAutoresizingMaskIntoConstraints:NO];
    [cell.contentView addConstraint:[NSLayoutConstraint constraintWithItem:toSelectController.view
                                                                 attribute:NSLayoutAttributeLeft
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:cell.contentView
                                                                 attribute:NSLayoutAttributeLeft
                                                                multiplier:1
                                                                  constant:0]];
    [cell.contentView addConstraint:[NSLayoutConstraint constraintWithItem:toSelectController.view
                                                                 attribute:NSLayoutAttributeRight
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:cell.contentView
                                                                 attribute:NSLayoutAttributeRight
                                                                multiplier:1
                                                                  constant:0]];
    [cell.contentView addConstraint:[NSLayoutConstraint constraintWithItem:toSelectController.view
                                                                 attribute:NSLayoutAttributeTop
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:cell.contentView
                                                                 attribute:NSLayoutAttributeTop
                                                                multiplier:1
                                                                  constant:0]];
    [cell.contentView addConstraint:[NSLayoutConstraint constraintWithItem:toSelectController.view
                                                                 attribute:NSLayoutAttributeBottom
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:cell.contentView
                                                                 attribute:NSLayoutAttributeBottom
                                                                multiplier:1
                                                                  constant:0]];
    [toSelectController didMoveToParentViewController:self];
  }
  
  if ([_delegate respondsToSelector:@selector(didSelectViewController:)]) {
    [_delegate didSelectViewController:self.selectedViewController];
  }
}

- (void)collectionView:(UICollectionView *)collectionView
  didEndDisplayingCell:(UICollectionViewCell *)cell
    forItemAtIndexPath:(NSIndexPath *)indexPath
{
  if (collectionView == self.segmentBar) {
    return;
  }
  if (indexPath.row >= self.viewControllers.count) {
    return;
  }
  UIViewController *previousViewController = self.viewControllers[indexPath.row];
  if (previousViewController && previousViewController.parentViewController) {
    [previousViewController willMoveToParentViewController:nil];
    [previousViewController.view removeFromSuperview];
    [previousViewController removeFromParentViewController];
  }
}

- (CGPoint)collectionView:(UICollectionView *)collectionView
targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset
{
  if (collectionView == self.slideView) {
    return self.previousIndex == NSNotFound ? proposedContentOffset : CGPointMake(self.previousIndex * self.slideView.bounds.size.width, 0);
  }
  return proposedContentOffset;
}

#pragma mark - UIScrollViewDelegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
  if (scrollView == self.slideView) {
    if ([_delegate respondsToSelector:@selector(slideViewDidScroll:)]) {
      [_delegate slideViewDidScroll:scrollView];
    }
  } else if (scrollView == self.segmentBar) {
    if ([_delegate respondsToSelector:@selector(slideSegmentDidScroll:)]) {
      [_delegate slideSegmentDidScroll:scrollView];
    }
  }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
  if (scrollView == self.slideView) {
    [self segmentBarScrollToIndex:self.selectedIndex animated:YES];
    if ([_delegate respondsToSelector:@selector(didFullyShowViewController:)]) {
      [_delegate didFullyShowViewController:self.selectedViewController];
    }
  }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
  if (scrollView == self.slideView) {
    [self segmentBarScrollToIndex:self.selectedIndex animated:YES];
    if ([_delegate respondsToSelector:@selector(didFullyShowViewController:)]) {
      [_delegate didFullyShowViewController:self.selectedViewController];
    }
  }
}

#pragma mark - Action
- (void)scrollToViewWithIndex:(NSInteger)index animated:(BOOL)animated
{
  if (self.selectedIndex == index) {
    return;
  }
  NSParameterAssert(index >= 0 && index < self.viewControllers.count);
  [self.slideView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]
                         atScrollPosition:UICollectionViewScrollPositionLeft
                                 animated:NO];
  [self segmentBarScrollToIndex:index animated:animated];
  
  if (!animated && [_delegate respondsToSelector:@selector(didFullyShowViewController:)]) {
    [_delegate didFullyShowViewController:self.selectedViewController];
  }
}

- (void)reset
{
  self.lastContentOffset = CGPointZero;
  self.previousIndex = NSNotFound;
  [self.segmentBar reloadData];
  [self.slideView reloadData];
  // reset to start index, if want to change index to 0, you should set startIndex before set viewControllers
  [self setSelectedIndex:self.startIndex];
}

- (void)segmentBarScrollToIndex:(NSInteger)index animated:(BOOL)animated
{
  [self.segmentBar
      selectItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0]
                   animated:animated
             scrollPosition:UICollectionViewScrollPositionCenteredHorizontally];
}

#pragma mark - UIContentContainer
- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
  [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
  // record index to support targetContentOffsetForProposedContentOffset
  // https://stackoverflow.com/questions/41639968/uicollectionview-contentoffset-after-device-rotation
  self.previousIndex = self.selectedIndex;
  [self.slideView.collectionViewLayout invalidateLayout];
  [self.segmentBar.collectionViewLayout invalidateLayout];
}

@end

