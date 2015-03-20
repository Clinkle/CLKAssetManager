#import "CLKAssetDownload.h"
#import "AFHTTPRequestOperationManager+CLKAdditions.h"

@interface CLKAssetDownload()

@property (nonatomic, strong) NSString *URLString;
@property (nonatomic, assign) CLKAssetDownloadState state;

@end

@implementation CLKAssetDownload

+ (AFHTTPRequestOperationManager *)requestOperationManager {
    static AFHTTPRequestOperationManager *requestOperationManager = nil;
    if (requestOperationManager == nil) {
        requestOperationManager = [[AFHTTPRequestOperationManager alloc] init];
        requestOperationManager.responseSerializer = [AFHTTPResponseSerializer serializer];
    }
    return requestOperationManager;
}

- (id)initWithURLString:(NSString *)URLString
{
    self = [self init];
    if (self) {
        self.URLString = URLString;
    }
    return self;
}

- (void)downloadWithCompletion:(void (^)(AFHTTPRequestOperation *operation, id responseObject, NSError *error))completed
                 synchronously:(BOOL)synchronous
{
    if (!self.URLString) {
        if (completed) {
            NSDictionary *userInfo = @{
                    NSLocalizedDescriptionKey : @"Did not fetch asset",
                    NSLocalizedFailureReasonErrorKey : @"NSURLString was nil",
                    NSLocalizedRecoverySuggestionErrorKey : @"Check the manifest file."
            };
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                                 code:0
                                             userInfo:userInfo];
            completed(nil, nil, error);
        }
        return;
    }

    self.state = CLKAssetDownloadStateDownloading;

    AFHTTPRequestOperationManager *requestOperationManager = [CLKAssetDownload requestOperationManager];
    [requestOperationManager URLString:self.URLString
                             completed:^(AFHTTPRequestOperation *operation, NSData *data, NSError *error) {
                                 self.state = error ? CLKAssetDownloadStateFailed : CLKAssetDownloadStateDone;
                                 if (completed) {
                                     completed(operation, data, error);
                                 }
                             }
                           synchronous:synchronous];
}

@end