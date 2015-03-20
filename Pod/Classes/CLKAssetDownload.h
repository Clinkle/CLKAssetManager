#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger , CLKAssetDownloadState) {
    CLKAssetDownloadStateUnknown,
    CLKAssetDownloadStateDownloading,
    CLKAssetDownloadStateDone,
    CLKAssetDownloadStateFailed
};

@class AFHTTPRequestOperation;
@interface CLKAssetDownload : NSObject

@property (nonatomic, readonly) CLKAssetDownloadState state;

@property (nonatomic, readonly) NSString *URLString;
@property (nonatomic, readonly) NSArray *observers;
@property (nonatomic, readonly) NSData *data;

- (id)initWithURLString:(NSString *)URLString;

- (void)downloadWithCompletion:(void (^)(AFHTTPRequestOperation *, id, NSError *))completed
                 synchronously:(BOOL)synchronous;

@end