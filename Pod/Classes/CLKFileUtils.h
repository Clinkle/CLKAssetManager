#import <Foundation/Foundation.h>

@interface CLKFileUtils : NSObject

+ (BOOL)saveData:(NSData *)data
          atPath:(NSString *)filePath;
+ (BOOL)fileExistsAtPath:(NSString *)filePath;
+ (BOOL)removeItemAtPath:(NSString *)filePath;
+ (NSData *)dataAtPath:(NSString *)filePath;
+ (NSData *)dataAtURL:(NSString *)urlStr;
+ (BOOL)createDirectoryAtPath:(NSString *)directoryPath;

+ (NSString *)jsonFromCollection:(id)collection
                   prettyPrinted:(BOOL)prettyPrinted;
+ (NSString *)removeCommentsFromString:(NSString *)originalString;

@end
