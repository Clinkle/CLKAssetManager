#import <AFNetworking/AFHTTPRequestOperationManager.h>
#import "CLKAssetManager.h"
#import "CLKAssetDownload.h"
#import "NSData+MD5.h"
#import "AFHTTPRequestOperationManager+CLKAdditions.h"
#import "CLKFileUtils.h"

#define CLKAssetManagerLog(FORMAT, ARGS...) if (![CLKAssetManager singleton].logsAreSupressed) { NSLog(FORMAT, ARGS); }

@interface CLKAssetManager()

@property (nonatomic, strong) NSCache *assets; // {:key => <NSData>}
@property (nonatomic, strong) NSMutableDictionary *assetDownloads; // {:key => <CLKAssetDownload>}

@property (nonatomic, strong) NSString *urlPrefix;
@property (nonatomic, assign) BOOL logsAreSupressed;
@property (nonatomic, assign) BOOL requestsAreSynchronous;

@property (nonatomic, assign) BOOL isFetchingManifest;

@end

@implementation CLKAssetManager
SYNTHESIZE_SINGLETON_FOR_CLASS(CLKAssetManager)

- (id)init
{
    self = [super init];
    if (self) {
        self.assets = [[NSCache alloc] init];
        self.assetDownloads = [[NSMutableDictionary alloc] init];
        self.urlPrefix = @"https://s3.amazonaws.com"; // you should specify your personal bucket with +setURLPrefix
    }
    return self;
}

+ (void)setURLPrefix:(NSString *)urlPrefix
{
    [self singleton].urlPrefix = urlPrefix;
}

+ (void)suppressLogs:(BOOL)shouldSupress
{
    [self singleton].logsAreSupressed = shouldSupress;
}

+ (void)performRequestsSynchronously:(BOOL)synchronously
{
    [self singleton].requestsAreSynchronous = synchronously;
}

- (BOOL)setAssetData:(NSData *)data
              forKey:(NSString *)key
               error:(NSError **)error
{
    BOOL validChecksum = [self validateChecksumForData:data
                                                forKey:key];
    if (validChecksum) {
        [self.assets setObject:data forKey:key];
    } else {
        NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey : @"Did not set asset",
                NSLocalizedFailureReasonErrorKey : @"checksums did not match",
                NSLocalizedRecoverySuggestionErrorKey : @"Check the manifest file."
        };
        if (error) {
            *error = [NSError errorWithDomain:NSURLErrorDomain
                                         code:0
                                     userInfo:userInfo];
        }
    }
    return validChecksum;
}

- (BOOL)hasCachedAssetForKey:(NSString *)key
{
    if ([self.assets objectForKey:key]) {
        return YES;
    }
    NSString *path = [self filePathToCachedAssetForKey:key];
    return [CLKFileUtils fileExistsAtPath:path];
}

- (NSData *)cachedDataForKey:(NSString *)key
{
    NSData *data = [self.assets objectForKey:key];
    if (!data) {
        data = [self dataFromFileForKey:key];
    }
    if (!data) {
        data = [self dataFromMainBundleForKey:key];
    }
    return data;
}

- (UIImage *)cachedImageForKey:(NSString *)key
{
    NSData *data = [self cachedDataForKey:key];
    return [[UIImage alloc] initWithData:data];
}

- (NSString *)cachedStringForKey:(NSString *)key
{
    NSData *data = [self cachedDataForKey:key];
    if (!data) {
        return nil;
    }
    return [[NSString alloc] initWithData:data
                                 encoding:NSUTF8StringEncoding];
}

- (id)JSONFromData:(NSData *)data
{
    if (!data) {
        return nil;
    }
    NSString *JSONString = [[NSString alloc] initWithData:data
                                                 encoding:NSUTF8StringEncoding];
    JSONString = [CLKFileUtils removeCommentsFromString:JSONString];
    return [NSJSONSerialization JSONObjectWithData:[JSONString dataUsingEncoding:NSUTF8StringEncoding]
                                           options:0
                                             error:nil];
}

- (id)cachedJSONForKey:(NSString *)key
{
    NSData *data = [self cachedDataForKey:key];
    return [self JSONFromData:data];
}

- (NSString *)pathToAssetsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:@"assets"];
}

- (NSString *)pathToAssetsDirectoryForKey:(NSString *)key
{
    NSString *assetsDirectory = [self pathToAssetsDirectory];
    return [assetsDirectory stringByAppendingPathComponent:key];
}

- (NSString *)filePathToCachedAssetForKey:(NSString *)key
{
    NSString *assetsDirectory = [self pathToAssetsDirectoryForKey:key];
    NSString *checksum = [self checksumForKey:key];
    NSString *extension = [key pathExtension];
    NSString *file = [NSString stringWithFormat:@"%@.%@", checksum, extension];
    return [assetsDirectory stringByAppendingPathComponent:file];
}

- (NSData *)dataFromFileForKey:(NSString *)key
{
    NSString *path = [self filePathToCachedAssetForKey:key];
    return [NSData dataWithContentsOfFile:path
                                  options:0
                                    error:NULL];
}

- (NSData *)dataFromMainBundleForKey:(NSString *)key
{
    NSString *filename = [[key lastPathComponent] stringByDeletingPathExtension];
    NSString *extension = [key pathExtension];
    NSString *path = [[NSBundle mainBundle] pathForResource:filename
                                                     ofType:extension
                                                inDirectory:nil
                                            forLocalization:nil];
    if (path) {
        return [NSData dataWithContentsOfFile:path
                                      options:0
                                        error:NULL];
    }
    return nil;
}

- (void)fetchManifest
{
    NSString *defaultName = [self defaultManifestName];
    [self fetchManifestNamed:defaultName];
}

- (NSString *)defaultManifestName
{
    NSString *version = [self currentAppVersion];
    NSString *formattedVersion = [version stringByReplacingOccurrencesOfString:@"."
                                                                    withString:@"_"];
    return [NSString stringWithFormat:@"manifest_%@", formattedVersion];
}

- (void)fetchManifestNamed:(NSString *)manifestName
{
    if (self.isFetchingManifest) {
        return;
    }
    self.isFetchingManifest = YES;

    NSString *urlString = [NSString stringWithFormat:@"%@/%@.json", self.urlPrefix, manifestName];

    CLKAssetManagerLog(@"Remote Assets: fetching manifest at %@", urlString);

    __weak typeof(self) weakSelf = self;
    AFHTTPRequestOperationManager *manager = [[AFHTTPRequestOperationManager alloc] init];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"text/plain", @"application/json", nil];
    manager.requestSerializer.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    [manager URLString:urlString
             completed:^(AFHTTPRequestOperation *operation, id responseObject, NSError *error) {
                 dispatch_async(dispatch_get_main_queue(), ^{
                     if (!error) {
                         [weakSelf updateManifest:responseObject];
                     } else {
                         CLKAssetManagerLog(@"Remote Assets: failed to fetch manifest at %@ with error %@", urlString, error);
                     }
                     self.isFetchingManifest = NO;
                 });
             }
           synchronous:self.requestsAreSynchronous];
}

- (void)updateManifest:(NSDictionary *)manifest
{
    CLKAssetManagerLog(@"Remote Assets: did fetch manifest: %@", [CLKFileUtils jsonFromCollection:manifest prettyPrinted:YES]);

    NSDictionary *oldManifest = [self.manifest copy];
    for (NSString *key in oldManifest) {
        if (manifest[key]) {
            NSString *oldChecksum = oldManifest[key][@"checksum"];
            NSString *checksum = manifest[key][@"checksum"];
            if (![oldChecksum isEqualToString:checksum]) {
                [self clearCacheForKey:key];
            }
        } else {
            [self clearCacheForKey:key];
        }
    }
    self.manifest = manifest;
}

+ (NSArray *)defaultsBackedProperties
{
    return @[@"manifest"];
}

- (void)setManifest:(NSDictionary *)manifest
{
    if ([manifest isEqual:_manifest]) {
        return;
    }

    _manifest = manifest;
    [self.assetDownloads removeAllObjects];
}

- (NSString *)checksumForData:(NSData *)data
{
    return [data MD5];
}

- (BOOL)validateChecksumForData:(NSData *)data
                         forKey:(NSString *)key
{
    NSString *validChecksum = [self checksumForKey:key];
    NSString *dataChecksum = [self checksumForData:data];
    return [validChecksum isEqualToString:dataChecksum];
}

- (void)assetForKey:(NSString *)key
          completed:(void (^)(NSData *data, NSError *error, CLKAssetManagerCacheType cacheType))completed
{
    NSData *data = [self.assets objectForKey:key];
    if (data) {
        if (completed) {
            completed(data, nil, CLKAssetManagerCacheTypeMemory);
        }
        return;
    }

    __block NSData *diskData = nil;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        diskData = [self dataFromFileForKey:key];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (diskData) {
                NSError *error = nil;
                [self setAssetData:diskData
                            forKey:key
                             error:&error];
                if (completed) {
                    completed(diskData, error, CLKAssetManagerCacheTypeDisk);
                }
                return;
            }

            CLKAssetManagerLog(@"Remote Assets: fetching asset %@", key);

            // Not in memory nor on disk, so download the asset
            // TODO: if the asset download already exists, add the current completion block to an array of completion blocks
            CLKAssetDownload *assetDownload = [self assetDownloadForKey:key];

            [assetDownload downloadWithCompletion:^(AFHTTPRequestOperation *operation, NSData *data, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!error) {
                        NSError *saveError = nil;
                        [self setAssetData:data
                                    forKey:key
                                     error:&saveError];
                        if (!saveError) {
                            [self saveAssetToDisk:data
                                           forKey:key];

                            CLKAssetManagerLog(@"Remote Assets: successfully fetched asset %@", key);
                        } else {
                            CLKAssetManagerLog(@"Remote Assets: failed to fetched asset %@ with error %@", key, saveError);
                        }

                        [self.assetDownloads removeObjectForKey:key]; // We're done with the download

                        if (completed) {
                            completed(data, error, CLKAssetManagerCacheTypeNone);
                        }
                    } else {
                        CLKAssetManagerLog(@"Remote Assets: failed to fetched asset %@ with error %@", key, error);
                        NSData *dataFromBundle = [self dataFromMainBundleForKey:key];
                        if (completed) {
                            completed(dataFromBundle, dataFromBundle ? nil : error, CLKAssetManagerCacheTypeNone);
                        }
                    }
                });
            }
                                    synchronously:self.requestsAreSynchronous];
        });
    });
}

- (void)imageForKey:(NSString *)key
          completed:(void (^)(UIImage *image, NSError *error, CLKAssetManagerCacheType cacheType))completed
{
    [self assetForKey:key
            completed:^(NSData *data, NSError *error, CLKAssetManagerCacheType cacheType) {
                if (completed) {
                    UIImage *image = [UIImage imageWithData:data];
                    completed(image, error, cacheType);
                }
            }];
}

- (void)stringForKey:(NSString *)key
           completed:(void (^)(NSString *string, NSError *error, CLKAssetManagerCacheType cacheType))completed
{
    [self assetForKey:key
            completed:^(NSData *data, NSError *error, CLKAssetManagerCacheType cacheType) {
                if (completed) {
                    NSString *string = [NSString stringWithUTF8String:[data bytes]];
                    completed(string, error, cacheType);
                }
            }];
}

- (void)JSONForKey:(NSString *)key
         completed:(void (^)(id JSON, NSError *error, CLKAssetManagerCacheType cacheType))completed
{
    [self assetForKey:key
            completed:^(NSData *data, NSError *error, CLKAssetManagerCacheType cacheType) {
                if (completed) {
                    id json = [self JSONFromData:data];
                    completed(json, error, cacheType);
                }
            }];
}


- (NSString *)URLStringForKey:(NSString *)key
{
    return self.manifest[key][@"url"];
}

- (NSString *)checksumForKey:(NSString *)key
{
    return self.manifest[key][@"checksum"];
}

- (CLKAssetDownload *)assetDownloadForKey:(NSString *)key
{
    CLKAssetDownload *assetDownload = self.assetDownloads[key];
    if (!assetDownload) {
        NSString *URLString;
        URLString = [self URLStringForKey:key];

        assetDownload = [[CLKAssetDownload alloc] initWithURLString:URLString];
        self.assetDownloads[key] = assetDownload;
    }
    return assetDownload;
}

- (void)deleteFilesInDirectory:(NSString *)directory
                        except:(NSString *)checksum
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *files = [fileManager contentsOfDirectoryAtPath:directory error:NULL];
    for (NSString *file in files) {
        if ([[file lastPathComponent] hasPrefix:checksum]) {
            continue;
        }
        NSString *path = [directory stringByAppendingPathComponent:file];
        [CLKFileUtils removeItemAtPath:path];
    }
}

- (void)saveAssetToDisk:(NSData *)data
                 forKey:(NSString *)key
{
    NSString *assetsDirectory = [self pathToAssetsDirectoryForKey:key];
    [CLKFileUtils createDirectoryAtPath:assetsDirectory];
    NSString *path = [self filePathToCachedAssetForKey:key];
    NSError *error;
    [data writeToFile:path
              options:NSDataWritingAtomic | NSDataWritingFileProtectionComplete
                error:&error];
    if (!error) {
        [self cleanupOldAssetsForKey:key];
    }
}

- (void)cleanupOldAssetsForKey:(NSString *)key
{
    NSString *assetsDirectory = [self pathToAssetsDirectoryForKey:key];
    NSString *checksum = [self checksumForKey:key];
    [self deleteFilesInDirectory:assetsDirectory
                          except:checksum];
}

- (void)clearCache
{
    self.assets = [[NSCache alloc] init];
    NSString *assetsDirectory = [self pathToAssetsDirectory];
    [CLKFileUtils removeItemAtPath:assetsDirectory];
}

- (void)clearCacheForKey:(NSString *)key
{
    [self clearMemoryCacheForKey:key];
    [self clearDiskCacheForKey:key];
}

- (void)clearDiskCacheForKey:(NSString *)key
{
    NSString *path = [self filePathToCachedAssetForKey:key];
    [CLKFileUtils removeItemAtPath:path];
}

- (void)clearMemoryCacheForKey:(NSString *)key
{
    [self.assets removeObjectForKey:key];
}

#pragma mark - app version
- (NSString *)currentAppVersion
{
    return [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
}

@end