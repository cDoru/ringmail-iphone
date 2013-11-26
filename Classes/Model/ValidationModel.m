/* ChatModel.m
 *
 * Copyright (C) 2012  Belledonne Comunications, Grenoble, France
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or   
 *  (at your option) any later version.                                 
 *                                                                      
 *  This program is distributed in the hope that it will be useful,     
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of      
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the       
 *  GNU General Public License for more details.                
 *                                                                      
 *  You should have received a copy of the GNU General Public License   
 *  along with this program; if not, write to the Free Software         
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */ 

#import "ValidationModel.h"
#import "JSONKit.h"

#define RINGMAIL_VALIDATION @"ringmail_validation.json"

@implementation ValidationModel

#pragma mark - Validation Functions

+ (BOOL)hasData
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documents = [paths objectAtIndex:0];
    NSString *finalPath = [documents stringByAppendingPathComponent:RINGMAIL_VALIDATION];
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    return [fileMgr fileExistsAtPath:finalPath];
}

+ (void)storeData:(NSDictionary *)data
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documents = [paths objectAtIndex:0];
    NSString *finalPath = [documents stringByAppendingPathComponent:RINGMAIL_VALIDATION];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data options:0 error:nil];
    [jsonData writeToFile:finalPath atomically:YES];
    NSLog(@"Stored Validation: %@", data);
}

+ (NSMutableDictionary *)readData
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documents = [paths objectAtIndex:0];
    NSString *finalPath = [documents stringByAppendingPathComponent:RINGMAIL_VALIDATION];
    NSData *jsonData = [[[NSData alloc] initWithContentsOfFile:finalPath] autorelease];
    NSMutableDictionary *res = [jsonData mutableObjectFromJSONData];
    //NSLog(@"Retrieved Validation: %@", res);
    return res;
}

+ (void)removeData
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documents = [paths objectAtIndex:0];
    NSString *finalPath = [documents stringByAppendingPathComponent:RINGMAIL_VALIDATION];
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSError *error;
    [fileMgr removeItemAtPath:finalPath error:&error];
}


@end
