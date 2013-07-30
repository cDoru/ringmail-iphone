//
//  UIBubbleTableView.m
//
//  Created by Alex Barinov
//  Project home page: http://alexbarinov.github.com/UIBubbleTableView/
//
//  This work is licensed under the Creative Commons Attribution-ShareAlike 3.0 Unported License.
//  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/3.0/
//

#import "UIBubbleTableView.h"
#import "NSBubbleData.h"
#import "UIBubbleHeaderTableViewCell.h"
#import "UIBubbleTypingTableViewCell.h"

@interface UIBubbleTableView ()

@property (nonatomic, retain) NSMutableArray *bubbleSection;

@end

@implementation UIBubbleTableView

@synthesize bubbleDataSource = _bubbleDataSource;
@synthesize snapInterval = _snapInterval;
@synthesize bubbleSection = _bubbleSection;
@synthesize typingBubble = _typingBubble;
@synthesize showAvatars = _showAvatars;

#pragma mark - Initializators

- (void)initializator
{
    // UITableView properties
    
    self.backgroundColor = [UIColor clearColor];
    self.separatorStyle = UITableViewCellSeparatorStyleNone;
    assert(self.style == UITableViewStylePlain);
    
    self.delegate = self;
    self.dataSource = self;
    
    // UIBubbleTableView default properties
    
    self.snapInterval = 120;
    self.typingBubble = NSBubbleTypingTypeNobody;
}

- (id)init
{
    self = [super init];
    if (self) [self initializator];
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) [self initializator];
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) [self initializator];
    return self;
}

- (id)initWithFrame:(CGRect)frame style:(UITableViewStyle)style
{
    self = [super initWithFrame:frame style:UITableViewStylePlain];
    if (self) [self initializator];
    return self;
}

#if !__has_feature(objc_arc)
- (void)dealloc
{
    [_bubbleSection release];
	_bubbleSection = nil;
	_bubbleDataSource = nil;
    [super dealloc];
}
#endif

#pragma mark - Override

- (void)reloadData
{
    self.showsVerticalScrollIndicator = NO;
    self.showsHorizontalScrollIndicator = NO;
    
    // Cleaning up
	self.bubbleSection = nil;
    
    // Loading new data
    int count = 0;
#if !__has_feature(objc_arc)
    self.bubbleSection = [[[NSMutableArray alloc] init] autorelease];
#else
    self.bubbleSection = [[NSMutableArray alloc] init];
#endif
    
    if (self.bubbleDataSource && (count = [self.bubbleDataSource rowsForBubbleTable:self]) > 0)
    {
#if !__has_feature(objc_arc)
        NSMutableArray *bubbleData = [[[NSMutableArray alloc] initWithCapacity:count] autorelease];
#else
        NSMutableArray *bubbleData = [[NSMutableArray alloc] initWithCapacity:count];
#endif
        
        for (int i = 0; i < count; i++)
        {
            ChatModel *chat = (ChatModel*)[self.bubbleDataSource bubbleTableView:self dataForRow:i];
            [bubbleData addObject:chat];
        }
        
        [bubbleData sortUsingComparator:^NSComparisonResult(id obj1, id obj2)
         {
             ChatModel *bubbleData1 = (ChatModel *)obj1;
             ChatModel *bubbleData2 = (ChatModel *)obj2;
             
             return [bubbleData1.time compare:bubbleData2.time];
         }];
        
        NSDate *last = [NSDate dateWithTimeIntervalSince1970:0];
        NSMutableArray *currentSection = nil;
        
        int section = -1;
        int row = 1;
        for (int i = 0; i < count; i++)
        {
            ChatModel *chat = (ChatModel *)[bubbleData objectAtIndex:i];
            if ([chat.time timeIntervalSinceDate:last] > self.snapInterval)
            {
#if !__has_feature(objc_arc)
                currentSection = [[[NSMutableArray alloc] init] autorelease];
#else
                currentSection = [[NSMutableArray alloc] init];
#endif
                [self.bubbleSection addObject:currentSection];
                section++;
                row = 1;
            }
            NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:section];
            NSObject *data = [self makeBubbleData:chat indexPath:path];
            row++;
            assert([data isKindOfClass:[NSBubbleData class]]);
            [currentSection addObject:data];
            //[self loadBubbleImages:chat];
            last = chat.time;
        }
    }
    
    [super reloadData];
}

#pragma mark - Bubble Data

/*- (void) loadBubbleImages:(ChatModel*)chat
{
    NSBubbleType dir;
    if([chat.direction intValue]) // Incoming
    {
        dir = BubbleTypeSomeoneElse;
    }
    else
    {
        dir = BubbleTypeMine;       
    }
    if ([chat isExternalImage])
    {
    }
    else if ([chat isInternalImage])
    {
        [LinphoneLogger logc:LinphoneLoggerWarning format:"Begin Loading: %@", chat.message];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, (unsigned long)NULL), ^(void) {
            [[LinphoneManager instance].photoLibrary assetForURL:[NSURL URLWithString:[chat message]] resultBlock:^(ALAsset *asset) {                
                ALAssetRepresentation* representation = [asset defaultRepresentation];
                UIImage *image = [UIImage imageWithCGImage:[representation fullResolutionImage]
                                                     scale:representation.scale
                                               orientation:(UIImageOrientation)representation.orientation];
                image = [UIImage decodedImageWithImage:image];
                NSBubbleData* bubble = [NSBubbleData dataWithImage:image date:chat.time type:dir];
                [LinphoneLogger logc:LinphoneLoggerWarning format:"Done Loading: %@", chat.message];
                NSArray* data = [NSArray arrayWithObjects:[chat indexPath], bubble, nil];
                [self performSelectorOnMainThread:@selector(updateBubbleData:) withObject:data waitUntilDone:YES];
                //[self updateBubble:[chat indexPath] bubbleData:bubble];
            } failureBlock:^(NSError *error) {
                [LinphoneLogger log:LinphoneLoggerError format:@"Can't read image"];
            }];
        });
    }
}*/

- (NSBubbleData *)makeBubbleData:(ChatModel*)chat indexPath:(NSIndexPath*)path
{
    [chat setIndexPath:path];
    NSBubbleData *bubble;
    NSBubbleType dir;
    if([chat.direction intValue]) // Incoming
    {
        dir = BubbleTypeSomeoneElse;
    }
    else
    {
        dir = BubbleTypeMine;
    }
    if ([chat isInternalImage])
    {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documents = [paths objectAtIndex:0];
        NSString *file = chat.message;
        NSString *file2 = [file copy];
        file2 = [file substringFromIndex:5];
        NSString *finalPath = [documents stringByAppendingPathComponent:file2];
        UIImage *image = [UIImage imageWithContentsOfFile:finalPath];
        bubble = [NSBubbleData dataWithImage:image date:chat.time type:dir];
    }
    else
    {
        bubble = [NSBubbleData dataWithText:chat.message date:chat.time type:dir];
    }
    bubble.avatar = nil;
    [LinphoneLogger logc:LinphoneLoggerWarning format:"Chat Bubble: %@", chat.message];
    return bubble;
}

#pragma mark - UITableViewDelegate implementation

#pragma mark - UITableViewDataSource implementation

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    int result = [self.bubbleSection count];
    if (self.typingBubble != NSBubbleTypingTypeNobody) result++;
    return result;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // This is for now typing bubble
	if (section >= [self.bubbleSection count]) return 1;
    
    return [[self.bubbleSection objectAtIndex:section] count] + 1;
}

- (float)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Now typing
	if (indexPath.section >= [self.bubbleSection count])
    {
        return MAX([UIBubbleTypingTableViewCell height], self.showAvatars ? 52 : 0);
    }
    
    // Header
    if (indexPath.row == 0)
    {
        return [UIBubbleHeaderTableViewCell height];
    }
    
    NSBubbleData *data = [[self.bubbleSection objectAtIndex:indexPath.section] objectAtIndex:indexPath.row - 1];
    return MAX(data.insets.top + data.view.frame.size.height + data.insets.bottom, self.showAvatars ? 52 : 0);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Now typing
	if (indexPath.section >= [self.bubbleSection count])
    {
        static NSString *cellId = @"tblBubbleTypingCell";
        UIBubbleTypingTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
        
        if (cell == nil) cell = [[UIBubbleTypingTableViewCell alloc] init];

        cell.type = self.typingBubble;
        cell.showAvatar = self.showAvatars;
        
        return cell;
    }

    // Header with date and time
    if (indexPath.row == 0)
    {
        static NSString *cellId = @"tblBubbleHeaderCell";
        UIBubbleHeaderTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
        NSBubbleData *data = [[self.bubbleSection objectAtIndex:indexPath.section] objectAtIndex:0];
        
        if (cell == nil) cell = [[UIBubbleHeaderTableViewCell alloc] init];

        cell.date = data.date;
       
        return cell;
    }
    
    // Standard bubble    
    static NSString *cellId = @"tblBubbleCell";
    UIBubbleTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    NSBubbleData *data = [[self.bubbleSection objectAtIndex:indexPath.section] objectAtIndex:indexPath.row - 1];
    
    if (cell == nil) cell = [[UIBubbleTableViewCell alloc] init];
    
    cell.data = data;
    cell.showAvatar = self.showAvatars;
    
    return cell;
}

/*-(void) updateBubbleData:(NSArray*)data
{
    [self updateBubble:(NSIndexPath*)[data objectAtIndex:0] bubbleData:(NSBubbleData*)[data objectAtIndex:1]];
}

-(void) updateBubble:(NSIndexPath *)indexPath bubbleData:(NSBubbleData*)newBubble
{
    [[self.bubbleSection objectAtIndex:indexPath.section] replaceObjectAtIndex:(indexPath.row - 1) withObject:newBubble];
    NSArray *paths = [NSArray arrayWithObject:indexPath];
    [self beginUpdates];
    [self reloadRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationRight];
    [self endUpdates];
}*/

@end
