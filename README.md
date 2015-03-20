# CLKAssetManager
The best way to reduce your iOS app binary by safely downloading binary assets at most once


### Setup

Add `pod 'CLKAssetManager'` to your Podfile.

Create a directory in your app's file system that's not linked by the xcodeproj, for example `/resources/remote_assets`.  These are the files that will be individually uploaded to your Amazon s3 bucket as binaries.  Each file will be MD5 checksumed and named according to this checksum, so as to avoid any conflicts.  Add the contents of `/scripts` to your project under rake's scope and update `config.json` according to your wildest desires.  Now before you deploy your app run `rake remote_assets:upload` and your assets and manifest will be uploaded.  The script uploads the assets before the new manifest, so there's no chance of users trying to fetch not-yet-populated URLs.

### Manifest and checksum cache

Your iOS app knows where this manifest lives based on the app's version and the bucket you provide to `CLKAssetManager`.  You can now ask the CLKAssetManager for your assets by name (e.g. `copy.json` or `my_huge_video_asset.mp4`) and it will determine whether the latest version is the most up-to-date (based on the checksum in the latest manifest).  If it's not up to date, it'll fetch it from s3.  Otherwise it'll look in memory and then on disk.  You can clear your memory and disk caches, either for specific assets or all at once.

### Update assets on the fly

If you'd like to change assets on the fly, simply change the file in your local remote_assets directory. Then re-run `rake remote_assets:upload` and the next time they launch their apps, all your users' apps will fetch the newest manifest, see that there's an updated file and download it.

### Squash your binary size

At Clinkle, this scheme allowed us to decrease our App Store binary from 51MB to 18MB, and it's made us way more responsive to marketing requests for copy and video changes. Pretty great.