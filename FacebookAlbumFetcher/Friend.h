//
//  Friend.h
//  FacebookAlbumFetcher
//
//  Copyright Matt Rajca 2012. All rights reserved.
//

@interface Friend : NSObject

@property (copy) NSString *name;
@property (copy) NSString *uid;
@property (strong) NSArray *albums;

@end
