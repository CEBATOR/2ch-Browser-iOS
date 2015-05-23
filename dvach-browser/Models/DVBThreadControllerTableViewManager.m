//
//  DVBThreadControllerTableViewManager.m
//  dvach-browser
//
//  Created by Andrey Konstantinov on 14/05/15.
//  Copyright (c) 2015 8of. All rights reserved.
//

#import "DVBConstants.h"
#import "DVBPost.h"
#import "DVBThreadControllerTableViewManager.h"

#import "DVBPostTableViewCell.h"
#import "DVBTitleForPostTableViewCell.h"
#import "DVBMediaForPostTableViewCell.h"
#import "DVBActionsForPostTableViewCell.h"

// Default row heights
static CGFloat const ROW_DEFAULT_HEIGHT = 75.0f; // +5 because of bold font problem
static CGFloat const ROW_MEDIA_DEFAULT_HEIGHT = 75.0f;
static CGFloat const ROW_ACTIONS_DEFAULT_HEIGHT = 43.0f;
static CGFloat const ADDITIONAL_HEIGHT_FOR_IPAD = 40.0f;

// thumbnail width in post row
static CGFloat const THUMBNAIL_WIDTH = 65.f;
// thumbnail contstraints for calculating layout dimentions
static CGFloat const HORISONTAL_CONSTRAINT = 10.0f; // we have 3 of them

/**
 *  Correction height because of:
 *  constraint from text to top - 10
 *  border - 1 more
 */
static CGFloat const CORRECTION_HEIGHT_FOR_TEXT_VIEW_CALC = 11.0f;

@interface DVBThreadControllerTableViewManager ()

@property (nonatomic, strong) DVBThreadViewController *threadViewController;

@property (nonatomic, strong) DVBPostTableViewCell *prototypeCell;

@end

@implementation DVBThreadControllerTableViewManager

- (instancetype)init
{
    @throw [NSException exceptionWithName:@"Not enough info" reason:@"Use +[DVBThreadControllerTableViewManager initWithThreadViewController]" userInfo:nil];

    return nil;
}

- (instancetype)initWith:(DVBThreadViewController *)threadViewController
{
    self = [super init];

    if (self) {
        _threadViewController = threadViewController;

        // System do not spend resources on calculating row heights via heightForRowAtIndexPath.
        if (![self respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)]) {
            _threadViewController.tableView.estimatedRowHeight = ROW_DEFAULT_HEIGHT;
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                _threadViewController.tableView.estimatedRowHeight = ADDITIONAL_HEIGHT_FOR_IPAD;
            }
        }
    }

    return self;
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [_postsArray count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    DVBPost *post = _postsArray[section];

    // If post have more than one thumbnail
    if ([post.thumbPathesArray count] > 1) {
        return 4;
    }

    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
    DVBPost *post = _postsArray[indexPath.section];
    NSUInteger row = indexPath.row;

    if (row == 0) {
        cell = (DVBTitleForPostTableViewCell *) [tableView dequeueReusableCellWithIdentifier:POST_CELL_TITLE_IDENTIFIER
                                                                                forIndexPath:indexPath];
        [self configureTitleCell:cell
               forRowAtIndexPath:indexPath];
    }

    // If post have more than one thumbnail...
    else if (([post.thumbPathesArray count] > 1)&&(row == 1)) {
        cell = (DVBMediaForPostTableViewCell *) [tableView dequeueReusableCellWithIdentifier:POST_CELL_MEDIA_IDENTIFIER
                                                                                forIndexPath:indexPath];
        [self configureMediaCell:cell
               forRowAtIndexPath:indexPath];

    }
    else if (([post.thumbPathesArray count] > 1)&&(row == 3)) { // If post have more than one
        cell = (DVBActionsForPostTableViewCell *) [tableView dequeueReusableCellWithIdentifier:POST_CELL_ACTIONS_IDENTIFIER
                                                                                  forIndexPath:indexPath];
        [self configureActionsCell:cell
                 forRowAtIndexPath:indexPath];
    }
    else if (([post.thumbPathesArray count] < 2)&&(row == 2)) { // If post have only one
        cell = (DVBActionsForPostTableViewCell *) [tableView dequeueReusableCellWithIdentifier:POST_CELL_ACTIONS_IDENTIFIER
                                                                                  forIndexPath:indexPath];
        [self configureActionsCell:cell
                 forRowAtIndexPath:indexPath];
    }
    else {
        cell = (DVBPostTableViewCell *) [tableView dequeueReusableCellWithIdentifier:POST_CELL_IDENTIFIER
                                                                        forIndexPath:indexPath];
        [self configureCell:cell
          forRowAtIndexPath:indexPath];
    }

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSUInteger row = indexPath.row;
    DVBPost *post = _postsArray[indexPath.section];

    if (row == 0) { // title cell

        UIFont *fontFromSettings = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];

        if ([[NSUserDefaults standardUserDefaults] boolForKey:SETTING_ENABLE_LITTLE_BODY_FONT]) {
            fontFromSettings = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        }

        CGSize size = [post.num sizeWithAttributes:@{NSFontAttributeName:fontFromSettings}];

        CGFloat titleCellHeight = size.height + HORISONTAL_CONSTRAINT;

        return titleCellHeight;
    }
    else if (([post.thumbPathesArray count] > 1)&&(row == 1)) { // If post have more than one thumbnail and this is first row
        CGFloat realRowMediaHeight = ROW_MEDIA_DEFAULT_HEIGHT;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            realRowMediaHeight = realRowMediaHeight + ADDITIONAL_HEIGHT_FOR_IPAD;
        }
        return realRowMediaHeight;
    }
    else if (([post.thumbPathesArray count] > 1)&&(row == 3)) { // If post have more than one thumbnail and this is third row
        return ROW_ACTIONS_DEFAULT_HEIGHT;
    }
    else if (([post.thumbPathesArray count] < 2)&&(row == 2)) { // If post have only one thumbnail and this is second row
        return ROW_ACTIONS_DEFAULT_HEIGHT;
    }
    else {
        // Helper method to get the text at a given cell.
        NSAttributedString *text = [self getTextAtIndex:indexPath];

        // Getting the width/height needed by the dynamic text view.
        CGSize viewSize = _threadViewController.tableView.bounds.size;
        NSInteger viewWidth = viewSize.width;

        // Set default difference (if we hve image in the cell).
        CGFloat widthDifferenceBecauseOfImageAndConstraints = THUMBNAIL_WIDTH + HORISONTAL_CONSTRAINT * 3;

        // Determine if we really have image in the cell.
        DVBPost *postObj = _postsArray[indexPath.section];
        NSString *thumbPath = postObj.thumbPath;

        // If not - then set the difference just to two constraints.
        if ([thumbPath isEqualToString:@""]) {
            widthDifferenceBecauseOfImageAndConstraints = HORISONTAL_CONSTRAINT * 2;
        }

        // Decrease window width value by taking off elements and contraints values
        CGFloat textViewWidth = viewWidth - widthDifferenceBecauseOfImageAndConstraints;

        // Return the size of the current row.
        CGFloat heightToReturn = [self heightForText:text
                                   constrainedToSize:CGSizeMake(textViewWidth, CGFLOAT_MAX)];

        CGFloat heightForReturnWithCorrectionAndCeilf = ceilf(heightToReturn + CORRECTION_HEIGHT_FOR_TEXT_VIEW_CALC);

        CGFloat minimumTextRowHeightToCompareTo = ROW_DEFAULT_HEIGHT;

        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            minimumTextRowHeightToCompareTo = ROW_DEFAULT_HEIGHT + ADDITIONAL_HEIGHT_FOR_IPAD;
        }

        if (heightToReturn < minimumTextRowHeightToCompareTo) {

            if ([thumbPath isEqualToString:@""]) {
                return heightForReturnWithCorrectionAndCeilf;
            }

            return (minimumTextRowHeightToCompareTo + 6);
        }

        return heightForReturnWithCorrectionAndCeilf;
    }
    
    return 0;
}

#pragma mark - Cell configuration and calculation

- (void)configureCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([cell isKindOfClass:[DVBPostTableViewCell class]]) {
        DVBPostTableViewCell *confCell = (DVBPostTableViewCell *)cell;
        DVBPost *post = _postsArray[indexPath.section];

        NSString *thumbUrlString = post.thumbPath;
        NSString *fullUrlString = post.path;

        BOOL showVideoIcon = (post.mediaType == webm);

        confCell.threadViewController = _threadViewController;

        [confCell prepareCellWithCommentText:post.comment
                       andPostThumbUrlString:thumbUrlString
                        andPostFullUrlString:fullUrlString
                            andShowVideoIcon:showVideoIcon];
    }
}
- (void)configureTitleCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([cell isKindOfClass:[DVBTitleForPostTableViewCell class]]) {
        DVBTitleForPostTableViewCell *confCell = (DVBTitleForPostTableViewCell *)cell;

        DVBPost *post = _postsArray[indexPath.section];
        NSString *dateAgo = post.dateAgo;
        NSString *num = post.num;

        // we increase number by one because sections start count from 0 and post counts on 2ch commonly start with 1
        NSInteger postNumToShow = indexPath.section + 1;

        NSString *title = [[NSString alloc] initWithFormat:@"#%ld • %@ • %@", (long)postNumToShow, num, dateAgo];

        [confCell prepareCellWithTitle:title];
    }
}

- (void)configureMediaCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([cell isKindOfClass:[DVBMediaForPostTableViewCell class]]) {
        DVBMediaForPostTableViewCell *confCell = (DVBMediaForPostTableViewCell *)cell;
        DVBPost *post = _postsArray[indexPath.section];

        confCell.threadViewController = _threadViewController;
        [confCell prepareCellWithThumbPathesArray:post.thumbPathesArray
                                   andPathesArray:post.pathesArray];
    }
}

- (void)configureActionsCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([cell isKindOfClass:[DVBActionsForPostTableViewCell class]]) {
        DVBActionsForPostTableViewCell *confCell = (DVBActionsForPostTableViewCell *)cell;
        DVBPost *post = _postsArray[indexPath.section];

        NSUInteger indexForButton = indexPath.section;

        BOOL shouldDisableActionButton = NO;

        if (_answersToPost) {
            shouldDisableActionButton = YES;
        }

        [confCell prepareCellWithPostRepliesCount:[post.replies count]
                                         andIndex:indexForButton
                           andDisableActionButton:shouldDisableActionButton];
    }
}

/// Utility method for calculation how much space we need to fit that text. Calculation for texView height.
-(CGFloat)heightForText:(NSAttributedString *)text constrainedToSize:(CGSize)size
{
    CGRect frame = CGRectIntegral([text boundingRectWithSize:size
                                                     options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
                                                     context:nil]);
    
    return frame.size.height;
}

/**
 *  Source for the text to be rendered in the text view.
 *  I used a dictionary to map indexPath to some dynamically fetched text.
 */
- (NSAttributedString *)getTextAtIndex:(NSIndexPath *)indexPath
{

    NSUInteger tmpIndex = indexPath.section;
    DVBPost *tmpObj =  _postsArray[tmpIndex];
    NSAttributedString *tmpComment = tmpObj.comment;

    return tmpComment;
}

#pragma mark - Scroll Delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    // Trying to figure out scroll position to store it for restoring later
    if (scrollView.contentOffset.y > 100) {
        // When we go back - table jumps in this values - so the correction is needed here
        CGSize statusBarSize = [[UIApplication sharedApplication] statusBarFrame].size;

        CGFloat topBarDifference = MIN(statusBarSize.width, statusBarSize.height) + _threadViewController.navigationController.navigationBar.frame.size.height;

        if (topBarDifference >= _threadViewController.topBarDifference) {
            _threadViewController.topBarDifference = topBarDifference;
        }

        CGFloat scrollPositionToStore = scrollView.contentOffset.y - _threadViewController.topBarDifference;

        NSNumber *scrollPosition = [NSNumber numberWithFloat:scrollPositionToStore];

        [_threadViewController.threadsScrollPositionManager.threads setValue:scrollPosition
                                                 forKey:_threadViewController.threadNum];
        
        _threadViewController.autoScrollTo = [_threadViewController.threadsScrollPositionManager.threads
                         objectForKey:_threadViewController.threadNum];
    }
}


@end
