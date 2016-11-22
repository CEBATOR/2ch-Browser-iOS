//
//  DVBAsyncBoardViewController.m
//  dvach-browser
//
//  Created by Andrey Konstantinov on 15/11/16.
//  Copyright © 2016 8of. All rights reserved.
//

#import "DVBAsyncBoardViewController.h"
#import "DVBThread.h"
#import "DVBBoardModel.h"
#import "ThreadNode.h"
#import "DVBRouter.h"
#import "DVBBoardStyler.h"
#import "DVBCreatePostViewControllerDelegate.h"

@interface DVBAsyncBoardViewController () <ASTableDataSource, ASTableDelegate, DVBCreatePostViewControllerDelegate>

@property (nonatomic, strong) ASTableNode *tableNode;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
/// Board's shortcode.
@property (strong, nonatomic) NSString *boardCode;
/// MaxPage (i.e. page count) for specific board.
@property (assign, nonatomic) NSInteger pages;
@property (nonatomic, assign) NSInteger currentPage;
@property (atomic, assign) BOOL alreadyLoadingNextPage;
/// Array contains all threads' OP posts for one page.
@property (nonatomic, strong) NSMutableArray *threadsArray;
@property (nonatomic, strong) DVBBoardModel *boardModel;
/// Need property for know if we gonna create new thread or not.
@property (nonatomic, strong) NSString *createdThreadNum;

@end

@implementation DVBAsyncBoardViewController

- (instancetype)initBoardCode:(NSString *)boardCode pages:(NSInteger)pages
{
    _tableNode = [[ASTableNode alloc] initWithStyle:UITableViewStylePlain];
    
    self = [super initWithNode:_tableNode];
    
    if (self) {
        _boardCode = boardCode;
        _pages = pages;

        UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Compose"]
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(openNewThread)];
        self.navigationItem.rightBarButtonItem = item;

        [self setupTableNode];
        _currentPage = 0;
        
        // set loading flag here because othervise
        // scrollViewDidScroll methods will start loading 'next' page (actually the same page) again
        _alreadyLoadingNextPage = NO;
        
        // If no pages setted (or pages is 0 - then set 10 pages).
        if (!_pages) {
            _pages = 10;
        }
        
        self.title = [NSString stringWithFormat:@"/%@/",_boardCode];
        _boardModel = [[DVBBoardModel alloc] initWithBoardCode:_boardCode
                                                    andMaxPage:_pages];
        [self initialBoardLoad];
    }
    
    return self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:YES];
    // Because we need to turn off toolbar every time view appears, not only when it loads first time
    [self.navigationController setToolbarHidden:YES animated:NO];
}

#pragma mark - Setup

- (void)setupTableNode
{
    [UIApplication sharedApplication].keyWindow.backgroundColor = [DVBBoardStyler threadCellBackgroundColor];

    _tableNode.view.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableNode.view.contentInset = UIEdgeInsetsMake([DVBBoardStyler elementInset]-1, 0, [DVBBoardStyler elementInset], 0);
    _tableNode.backgroundColor = [DVBBoardStyler threadCellBackgroundColor];
    _tableNode.delegate = self;
    _tableNode.dataSource = self;
    _tableNode.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableNode.view.showsVerticalScrollIndicator = NO;
    _tableNode.view.showsHorizontalScrollIndicator = NO;
    _refreshControl = [[UIRefreshControl alloc] init];
    [_refreshControl addTarget:self
                        action:@selector(reloadBoardPage)
              forControlEvents:UIControlEventValueChanged];
    [_tableNode.view addSubview:_refreshControl];
}

#pragma mark - Network

/// First time loading thread list
- (void)initialBoardLoad
{
    weakify(self);
    [_boardModel reloadBoardWithCompletion:^(NSArray *completionThreadsArray)
     {
         strongify(self);
         if (!self) { return; }
         _threadsArray = [completionThreadsArray mutableCopy];
         dispatch_async(dispatch_get_main_queue(), ^{
             [_tableNode reloadData];
             self.alreadyLoadingNextPage = NO;
         });
     }];
}
- (void)reloadBoardPage
{
    // Prevent reloading while already loading board items
    if (_alreadyLoadingNextPage) {
        [_refreshControl endRefreshing];
        return;
    }
    _alreadyLoadingNextPage = YES;
    double duration = 1.0;
    [UIView animateWithDuration:duration
                     animations:^{
        _tableNode.view.layer.opacity = 0;
    } completion:^(BOOL finished) {
        [_tableNode reloadData];
        weakify(self);
        [_boardModel reloadBoardWithCompletion:^(NSArray *completionThreadsArray)
         {
             strongify(self);
             if (!self) { return; }
             self.currentPage = 0;
             _threadsArray = [completionThreadsArray mutableCopy];
             dispatch_async(dispatch_get_main_queue(), ^{
                 [_refreshControl endRefreshing];
                 [_tableNode reloadData];
                 [UIView animateWithDuration:duration
                                  animations:^{
                     _tableNode.view.layer.opacity = 1;
                 } completion:^(BOOL finished) {
                     self.alreadyLoadingNextPage = NO;
                 }];
             });
         }];
    }];


}

- (void)loadNextBoardPage
{
    weakify(self);
    if (_pages > _currentPage)  {
        [_boardModel loadNextPageWithCompletion:^(NSArray *completionThreadsArray, NSError *error)
         {
             strongify(self);
             if (!self) { return; }
             NSInteger threadsCountWas = _threadsArray.count ? _threadsArray.count : 0;
             _threadsArray = [completionThreadsArray mutableCopy];
             NSInteger threadsCountNow = _threadsArray.count ? _threadsArray.count : 0;

             NSMutableArray *mutableIndexPathes = [@[] mutableCopy];

             for (NSInteger i = threadsCountWas; i < threadsCountNow; i++) {
                 [mutableIndexPathes addObject:[NSIndexPath indexPathForRow:i inSection:0]];
             }
             if (_threadsArray.count == 0) {
                 // [self showMessageAboutError];
                 self.navigationItem.rightBarButtonItem.enabled = NO;
             } else {
                 self.currentPage++;
                 // Update only if we have something to show
                 dispatch_async(dispatch_get_main_queue(), ^{
                     [_tableNode insertRowsAtIndexPaths:mutableIndexPathes.copy withRowAnimation:UITableViewRowAnimationFade];
                     self.alreadyLoadingNextPage = NO;
                     self.navigationItem.rightBarButtonItem.enabled = YES;
                     // self.tableView.backgroundView = nil;
                 });
             }
             // [self handleError:error];
         }];
    } else {
        _currentPage = 0;
        [self loadNextBoardPage];
    }
}

#pragma mark - Routing

- (void)openNewThread
{
    [DVBRouter openCreateThreadFrom:self boardCode:_boardCode];
}

#pragma mark - DVBCreatePostViewControllerDelegate

- (void)openThredWithCreatedThread:(NSString *)threadNum
{
    [DVBRouter pushThreadFrom:self withThreadNum:threadNum boardCode:_boardCode];
}

#pragma mark - ASTableNode

- (ASCellNodeBlock)tableNode:(ASTableNode *)tableNode nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath
{
    DVBThread *thread = _boardModel.threadsArray[indexPath.row];
    return ^{
        return [[ThreadNode alloc] initWithThread:thread];
    };
}

- (void)tableNode:(ASTableNode *)tableNode willDisplayRowWithNode:(ASCellNode *)node
{
    // Early return if something go wrong
    if (!node.indexPath.row || _boardModel.threadsArray.count == 0 || _boardModel.threadsArray.count <= node.indexPath.row) {
        return;
    }
    if ([[_boardModel.threadsArray lastObject] isEqual:_boardModel.threadsArray[node.indexPath.row]] ) {
        [self loadNextBoardPage];
    }
}

- (NSInteger)tableNode:(ASTableNode *)tableNode numberOfRowsInSection:(NSInteger)section
{
    return _boardModel.threadsArray.count;
}

- (void)tableNode:(ASTableNode *)tableNode didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    DVBThread *thread = _boardModel.threadsArray[indexPath.row];
    [DVBRouter pushThreadFrom:self withThread:thread boardCode:_boardCode];
    [_tableNode deselectRowAtIndexPath:indexPath animated:YES];
}

@end