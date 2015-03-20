#import "AFHTTPRequestOperationManager+CLKAdditions.h"

@implementation AFHTTPRequestOperationManager (CLAdditions)

- (AFHTTPRequestOperation *)method:(NSString *)method
                         URLString:(NSString *)URLString
                        parameters:(NSDictionary *)parameters
                         completed:(void (^)(AFHTTPRequestOperation *operation, id responseObject, NSError *error))completed
                       synchronous:(BOOL)synchronous
{
    NSMutableURLRequest *request = [self.requestSerializer requestWithMethod:[method capitalizedString]
                                                                   URLString:[[NSURL URLWithString:URLString relativeToURL:self.baseURL] absoluteString]
                                                                  parameters:parameters
                                                                       error:nil];

    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id responseObject) {
        if (completed) {
            completed(operation, responseObject, nil);
        }
    };
    void (^failureBlock)(AFHTTPRequestOperation *, NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        if (completed) {
            completed(operation, nil, error);
        }
    };
    AFHTTPRequestOperation *operation = [self HTTPRequestOperationWithRequest:request
                                                                      success:successBlock
                                                                      failure:failureBlock];

    [self.operationQueue addOperation:operation];

    if (synchronous) {
        [operation waitUntilFinished];
        if (operation.responseObject) {
            successBlock(operation, operation.responseObject);
        } else {
            failureBlock(operation, operation.error);
        }
    }
    return operation;
}

- (AFHTTPRequestOperation *)URLString:(NSString *)URLString
                            completed:(void (^)(AFHTTPRequestOperation *operation, id responseObject, NSError *error))completed
                          synchronous:(BOOL)synchronous
{
    return [self method:@"GET"
              URLString:URLString
             parameters:nil
              completed:completed
            synchronous:synchronous];
}

@end
