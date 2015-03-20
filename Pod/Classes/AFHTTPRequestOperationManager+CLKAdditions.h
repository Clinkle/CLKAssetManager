#import "AFHTTPRequestOperationManager.h"

@interface AFHTTPRequestOperationManager (CLAdditions)

- (AFHTTPRequestOperation *)URLString:(NSString *)URLString
                            completed:(void (^)(AFHTTPRequestOperation *operation, id responseObject, NSError *error))completed
                          synchronous:(BOOL)synchronous;

- (AFHTTPRequestOperation *)method:(NSString *)method
                         URLString:(NSString *)URLString
                        parameters:(NSDictionary *)parameters
                         completed:(void (^)(AFHTTPRequestOperation *operation, id responseObject, NSError *error))completed
                       synchronous:(BOOL)synchronous;

@end
