//
//  AppDelegate.h
//  FacebookAlbumFetcher
//
//  Copyright (c) 2012 Matt Rajca. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (strong) IBOutlet NSWindow *window;
@property (strong) IBOutlet NSArrayController *friendsController;
@property (strong) IBOutlet NSArrayController *albumsController;
@property (assign) IBOutlet NSTextField *accountLabel;

@property (assign) BOOL isDownloading;

@end
