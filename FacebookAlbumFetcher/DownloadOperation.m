//
//  DownloadOperation.m
//  FacebookAlbumFetcher
//
//  Copyright Matt Rajca 2012. All rights reserved.
//

#import "DownloadOperation.h"

@implementation DownloadOperation {
	NSURL *_url;
	NSURL *_destinationURL;
	NSURLDownload *_download;
}

- (id)initWithURL:(NSURL *)url destinationDirectory:(NSURL *)destinationURL {
	NSParameterAssert(url);
	NSParameterAssert(destinationURL);
	
	self = [super init];
	if (self) {
		_url = [url copy];
		_destinationURL = [destinationURL copy];
	}
	return self;
}

- (void)start {
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:NO];
		return;
	}
	
	[self willChangeValueForKey:@"isExecuting"];
	
	_download = [[NSURLDownload alloc] initWithRequest:[NSURLRequest requestWithURL:_url]
											  delegate:self];
	
	[self didChangeValueForKey:@"isExecuting"];
	
	NSString *directory = [_url lastPathComponent];
	
	[_download setDestination:[[_destinationURL URLByAppendingPathComponent:directory] path]
			   allowOverwrite:YES];
}

- (BOOL)isExecuting {
	return (_download != nil);
}

- (BOOL)isFinished {
	return (_download == nil);
}

- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error {
	NSLog(@"Download failed: %@", error);
	
	[self downloadDidFinish:download];
}

- (void)downloadDidFinish:(NSURLDownload *)download {
	[self willChangeValueForKey:@"isExecuting"];
	[self willChangeValueForKey:@"isFinished"];
	
	_download = nil;
	
	[self didChangeValueForKey:@"isExecuting"];
	[self didChangeValueForKey:@"isFinished"];
}

@end
