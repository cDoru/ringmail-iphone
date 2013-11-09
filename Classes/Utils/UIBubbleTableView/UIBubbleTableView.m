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
#import "ChatRoomViewController.h"

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
    
    lastPath = nil;
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
            if (! [chat.direction intValue])
            {
                lastPath = path;
            }
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
        UIImage *image = [UIImage imageWithContentsOfFile:[finalPath stringByAppendingString:@"_t.jpg"]];
        bubble = [NSBubbleData dataWithImage:image date:chat.time type:dir];
    }
    else
    {
        bubble = [NSBubbleData dataWithText:chat.message date:chat.time type:dir];
    }
    if([chat.direction intValue]) // Incoming
    {
        bubble.avatar = [(ChatRoomViewController*)self.bubbleDataSource avatarImage];
    }
    else
    {
        bubble.avatar = nil;
    }
    bubble.chat = chat;
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
    
    if (cell.data.mode == BubbleModeImage)
    {
        if (cell.longPressRecognizer == nil)
        {
            UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
            cell.longPressRecognizer = longPressRecognizer;  
        }
    }    
    else
    {
        cell.longPressRecognizer = nil;        
    }
    
    if (cell.data.type == BubbleTypeMine)
    {
        if (lastPath != nil)
        {
            if ([lastPath compare:indexPath] == NSOrderedSame)
            {
                cell.data.deliveryStatus.hidden = NO;
            }
        }
    }
    
    return cell;
}

#pragma mark - Handling long presses

-(void)handleLongPress:(UILongPressGestureRecognizer*)longPressRecognizer
{
    if (longPressRecognizer.state == UIGestureRecognizerStateBegan)
    {
        UIBubbleTableViewCell *cell = (UIBubbleTableViewCell*)longPressRecognizer.view;
        [LinphoneLogger logc:LinphoneLoggerWarning format:"Image Pressed: %@", cell.data.chat.message];
        
        ImageViewController *controller = DYNAMIC_CAST([[PhoneMainView instance] changeCurrentView:[ImageViewController compositeViewDescription] push:TRUE], ImageViewController);
        if(controller != nil) {
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documents = [paths objectAtIndex:0];
            NSString *file = cell.data.chat.message;
            NSString *file2 = [file copy];
            file2 = [file substringFromIndex:5];
            NSString *finalPath = [documents stringByAppendingPathComponent:file2];
            UIImage *image = [UIImage imageWithContentsOfFile:[finalPath stringByAppendingString:@".jpg"]];
            [controller setImage:image];
        }
    }
}

#pragma mark - Update delivery status

- (void) updateDeliveryStatus:(NSIndexPath *)path status:(NSString *)status
{
    NSBubbleData *data = [[self.bubbleSection objectAtIndex:path.section] objectAtIndex:path.row - 1];
    if (data.deliveryStatus != nil)
    {
        data.deliveryStatus.text = status;
    }
}

@end
