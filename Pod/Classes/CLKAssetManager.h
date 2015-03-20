#import <Foundation/Foundation.h>
#import "AFHTTPRequestOperationManager.h"
#import <CLKSingletons/CLKSingletons.h>
#import <CLKModel/CLKModel.h>

@class CLKAssetManager;

/**
 *
 * CLKAssetManager is responsible for determining if an asset need to be downloaded, caching it to memory, and persisting it to disk.
 * CLKAssetManager uses CLKAssetDownload to fetch the assets from the web, but then handles memory and disk storage for you.
 *
 * CLKAssetManager supports pre-loading, checking if data is cached, responding to multiple completion blocks
 * if 'assetForKey:completed:' is called multiple times on the same key and more.
 *
 * The goal of this asset manager is to be data agnostic, so it returns mostly NSData *
 * There are some helper methods like, cachedImageForKey: and cachedStringForKey: that return other objects.
 * If you want to return others, please use cachedDataForKey: and convert that to your object.
 *
 */

typedef NS_ENUM(NSInteger, CLKAssetManagerCacheType)
{
    CLKAssetManagerCacheTypeNone,
    CLKAssetManagerCacheTypeDisk,
    CLKAssetManagerCacheTypeMemory
};

@interface CLKAssetManager : CLKModel
DECLARE_SINGLETON_FOR_CLASS(CLKAssetManager)

// e.g. pass https://mycompany-ios-remote-assets.s3.amazonaws.com or the root URI for your assets directory
+ (void)setURLPrefix:(NSString *)urlPrefix;

+ (void)suppressLogs:(BOOL)shouldSupress;

+ (void)performRequestsSynchronously:(BOOL)synchronously;

@property (nonatomic, readonly) AFHTTPRequestOperationManager *requestOperationManager;
@property (nonatomic, strong) NSDictionary *manifest; // generated and uploaded through `rake remote_assets:upload`

// returns the cached asset in the block, or fetches a new one if needed
- (void)assetForKey:(NSString *)key
          completed:(void (^)(NSData *, NSError *, CLKAssetManagerCacheType))completed;
- (void)imageForKey:(NSString *)key
          completed:(void (^)(UIImage *, NSError *, CLKAssetManagerCacheType))completed;
- (void)stringForKey:(NSString *)key
           completed:(void (^)(NSString *, NSError *, CLKAssetManagerCacheType))completed;
- (void)JSONForKey:(NSString *)key
         completed:(void (^)(id, NSError *, CLKAssetManagerCacheType))completed;

- (BOOL)hasCachedAssetForKey:(NSString *)key;

// returns the cached asset if it exists, single threaded even if it has to go to disk
- (NSData *)cachedDataForKey:(NSString *)key;
- (UIImage *)cachedImageForKey:(NSString *)key;
- (NSString *)cachedStringForKey:(NSString *)key;
- (id)cachedJSONForKey:(NSString *)key;

- (NSString *)filePathToCachedAssetForKey:(NSString *)key;

- (void)clearCacheForKey:(NSString *)key;
- (void)clearDiskCacheForKey:(NSString *)key;
- (void)clearMemoryCacheForKey:(NSString *)key;
- (void)clearCache;

- (void)fetchManifest;

@end