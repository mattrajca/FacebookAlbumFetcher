//
//  AppDelegate.m
//  FacebookAlbumFetcher
//
//  Copyright (c) 2012 Matt Rajca. All rights reserved.
//

#import "AppDelegate.h"

#import <Accounts/Accounts.h>
#import <Social/Social.h>

#import "Album.h"
#import "DownloadOperation.h"
#import "Friend.h"

typedef void(^ParserBlock)(NSData *responseData);

@implementation AppDelegate {
	ACAccountStore *_accountStore;
	NSOperationQueue *_downloadQueue;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	_downloadQueue = [[NSOperationQueue alloc] init];
	[_downloadQueue setMaxConcurrentOperationCount:2];
	[_downloadQueue addObserver:self forKeyPath:@"operationCount" options:0 context:NULL];
	
	_accountStore = [[ACAccountStore alloc] init];
	
	ACAccountType *type = [_accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook];
	
	[_accountStore requestAccessToAccountsWithType:type
										   options:@{ ACFacebookAppIdKey: @"490118324340207", ACFacebookPermissionsKey: @[ @"email", @"read_friendlists", @"friends_photos" ] }
										completion:^(BOOL granted, NSError *error) {
											
											dispatch_async(dispatch_get_main_queue(), ^{
												
												if (granted) {
													[self updateAccountName];
													[self fetchFriends];
												}
												else {
													[NSApp presentError:error];
												}
												
											});
											
										}];
}

- (void)awakeFromNib {
	[self.friendsController addObserver:self forKeyPath:@"selectionIndex" options:0 context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if ([keyPath isEqualToString:@"selectionIndex"]) {
		Friend *f = [[self.friendsController selectedObjects] lastObject];
		
		if (f) {
			if (!f.albums) {
				[self fetchAlbumsForFriend:f];
			}
		}
	}
	else if ([keyPath isEqualToString:@"operationCount"]) {
		[[NSOperationQueue mainQueue] addOperationWithBlock:^{
			if ([_downloadQueue operationCount]) {
				self.isDownloading = YES;
			}
			else {
				self.isDownloading = NO;
			}
		}];
	}
}

- (void)updateAccountName {
	ACAccountType *type = [_accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook];
	ACAccount *account = [[_accountStore accountsWithAccountType:type] lastObject];
	
	self.accountLabel.stringValue = account.username;
}

- (void)performGETRequestWithURL:(NSURL *)url parserBlock:(ParserBlock)block {
	SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeFacebook
											requestMethod:SLRequestMethodGET
													  URL:url
											   parameters:nil];
	
	ACAccountType *type = [_accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook];
	ACAccount *account = [[_accountStore accountsWithAccountType:type] lastObject];
	
	request.account = account;
	
	[request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
		
		dispatch_async(dispatch_get_main_queue(), ^{
			
			if (responseData) {
				block(responseData);
			}
			else {
				[NSApp presentError:error];
			}
			
		});
		
	}];
}

- (void)fetchFriends {
	[self performGETRequestWithURL:[NSURL URLWithString:@"https://graph.facebook.com/me/friends"]
					   parserBlock:^(NSData *responseData) {
						   
						   [self parseFriendsData:responseData];
						   
					   }];
}

- (void)parseFriendsData:(NSData *)responseData {
	NSError *error = nil;
	NSDictionary *tree = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&error];
	
	if (!tree) {
		[NSApp presentError:error];
		return;
	}
	
	NSMutableArray *friends = [NSMutableArray new];
	
	for (NSDictionary *item in tree[@"data"]) {
		Friend *f = [Friend new];
		f.name = item[@"name"];
		f.uid = item[@"id"];
		
		[friends addObject:f];
	}
	
	[friends sortUsingComparator:^NSComparisonResult(Friend *obj1, Friend *obj2) {
		return [obj1.name compare:obj2.name options:0];
	}];
	
	[self.friendsController addObjects:friends];
	
	[self.friendsController setSelectionIndex:0];
}

- (void)fetchAlbumsForFriend:(Friend *)friend {
	NSString *urlString = [NSString stringWithFormat:@"https://graph.facebook.com/%@/albums", friend.uid];
	
	[self performGETRequestWithURL:[NSURL URLWithString:urlString]
					   parserBlock:^(NSData *responseData) {
						   
						   [self parseAlbumsData:responseData forFriend:friend];
						   
					   }];
}

- (void)parseAlbumsData:(NSData *)responseData forFriend:(Friend *)friend {
	NSError *error = nil;
	NSDictionary *tree = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&error];
	
	if (!tree) {
		[NSApp presentError:error];
		return;
	}
	
	NSMutableArray *albums = [NSMutableArray new];
	
	for (NSDictionary *item in tree[@"data"]) {
		Album *album = [Album new];
		album.name = item[@"name"];
		album.uid = item[@"id"];
		
		[albums addObject:album];
	}
	
	friend.albums = albums;
}

- (void)fetchPhotosInAlbum:(Album *)album toDestinationURL:(NSURL *)destination {
	NSString *urlString = [NSString stringWithFormat:@"https://graph.facebook.com/%@/photos", album.uid];
	
	[self performGETRequestWithURL:[NSURL URLWithString:urlString]
					   parserBlock:^(NSData *responseData) {
						   
						   [self parsePhotosData:responseData withDestinationURL:destination];
						   
					   }];
}

- (void)fetchNextBatchOfPhotosWithURL:(NSURL *)nextURL toDestinationURL:(NSURL *)destination {
	[NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:nextURL]
									   queue:[NSOperationQueue mainQueue]
						   completionHandler:^(NSURLResponse *r, NSData *d, NSError *e) {
							   
							   [self parsePhotosData:d withDestinationURL:destination];
							   
						   }];
}

- (void)parsePhotosData:(NSData *)responseData withDestinationURL:(NSURL *)destination {
	NSError *error = nil;
	NSDictionary *tree = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&error];
	
	if (!tree) {
		[NSApp presentError:error];
		return;
	}
	
	for (NSDictionary *item in tree[@"data"]) {
		NSArray *images = item[@"images"];
		NSDictionary *firstImage = images[0];
		
		NSString *downloadURLString = firstImage[@"source"];
		NSURL *downloadURL = [NSURL URLWithString:downloadURLString];
		
		DownloadOperation *op = [[DownloadOperation alloc] initWithURL:downloadURL
												  destinationDirectory:destination];
		
		[_downloadQueue addOperation:op];
	}
	
	NSString *nextURLString = tree[@"paging"][@"next"];
	
	if (nextURLString) {
		NSURL *nextURL = [NSURL URLWithString:nextURLString];
		[self fetchNextBatchOfPhotosWithURL:nextURL toDestinationURL:destination];
	}
}

- (IBAction)download:(id)sender {
	NSURL *downloadsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDownloadsDirectory inDomains:NSUserDomainMask] lastObject];
	
	NSOpenPanel *op = [NSOpenPanel openPanel];
	[op setCanCreateDirectories:YES];
	[op setCanChooseDirectories:YES];
	[op setCanChooseFiles:NO];
	[op setDirectoryURL:downloadsDirectory];
	
	[op beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
		
		if (result != NSFileHandlingPanelOKButton)
			return;
		
		NSURL *url = [op URL];
		Album *album = [[self.albumsController selectedObjects] lastObject];
		
		[self fetchPhotosInAlbum:album toDestinationURL:url];
		
	}];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	return YES;
}

@end
