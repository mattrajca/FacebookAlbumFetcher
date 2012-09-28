//
//  DownloadOperation.h
//  FacebookAlbumFetcher
//
//  Copyright Matt Rajca 2012. All rights reserved.
//

@interface DownloadOperation : NSOperation < NSURLDownloadDelegate >

- (id)initWithURL:(NSURL *)url destinationDirectory:(NSURL *)destinationURL;

@end
