#import "CLKFileUtils.h"

@implementation CLKFileUtils

#pragma mark - file
+ (BOOL)saveData:(NSData *)data
          atPath:(NSString *)filePath
{
    return [[NSFileManager defaultManager] createFileAtPath:filePath
                                                   contents:data
                                                 attributes:nil];
}

+ (BOOL)fileExistsAtPath:(NSString *)filePath
{
    return [[NSFileManager defaultManager] fileExistsAtPath:filePath];
}

+ (BOOL)removeItemAtPath:(NSString *)filePath
{
    return [[NSFileManager defaultManager] removeItemAtPath:filePath
                                                      error:NULL];
}

+ (NSData *)dataAtPath:(NSString *)filePath
{
    return [[NSFileManager defaultManager] contentsAtPath:filePath];
}

+ (NSData *)dataAtURL:(NSString *)urlStr
{
    NSURL *url = [NSURL URLWithString:urlStr];
    return [NSData dataWithContentsOfURL:url];
}

+ (BOOL)createDirectoryAtPath:(NSString *)directoryPath
{
    return [[NSFileManager defaultManager] createDirectoryAtPath:directoryPath
                                     withIntermediateDirectories:YES
                                                      attributes:nil
                                                           error:NULL];
}

#pragma mark - string <--> json
+ (NSString *)jsonFromCollection:(id)collection
{
    return [self jsonFromCollection:collection
                      prettyPrinted:NO];
}

+ (NSString *)jsonFromCollection:(id)collection
                   prettyPrinted:(BOOL)prettyPrinted
{
    if (!collection) {
        return @"";
    }

    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:collection
                                                       options:prettyPrinted ? NSJSONWritingPrettyPrinted : 0
                                                         error:NULL];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData
                                                 encoding:NSUTF8StringEncoding];
    jsonString = [jsonString stringByReplacingOccurrencesOfString:@"\\/"
                                                       withString:@"/"];
    return jsonString;
}

+ (NSString *)removeCommentsFromString:(NSString *)originalString
{
    NSRange range;
    NSString *strippedString = [originalString copy];
    NSString *commentsRegularExpression = @"(/\\*([^*]|[\r\n]|(\\*+([^*/]|[\r\n])))*\\*+/)|(//.*)"; // from http://ostermiller.org/findcomment.html
    while ((range = [strippedString rangeOfString:commentsRegularExpression
                                          options:NSRegularExpressionSearch]).location != NSNotFound) {
        strippedString = [strippedString stringByReplacingCharactersInRange:range
                                                                 withString:@""];
    }
    return strippedString;
}

@end
