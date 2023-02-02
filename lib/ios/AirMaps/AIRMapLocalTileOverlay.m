#import "AIRMapLocalTileOverlay.h"
#import "sqlite3.h"

#define bundle [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"]

@interface AIRMapLocalTileOverlay ()
@end

@implementation AIRMapLocalTileOverlay {
    CIContext *_ciContext;
    CGColorSpaceRef _colorspace;
    NSURLSession *_urlSession;
}


- (void)loadTileAtPath:(MKTileOverlayPath)path result:(void (^)(NSData *, NSError *))result
{
    if (!result) return;
    
    NSInteger maximumZ = 14;
    [self scaleIfNeededLowerZoomTile:path maximumZ:maximumZ result:^(NSData *image, NSError *error) {
        if (!image ) {
            NSInteger zoomLevelToStart = (path.z > maximumZ) ? maximumZ - 1 : path.z - 1;
            NSInteger minimumZoomToSearch = self.minimumZ >= zoomLevelToStart - 3 ? self.minimumZ : zoomLevelToStart - 3;
            [self findLowerZoomTileAndScale:path tryZ:zoomLevelToStart minZ:minimumZoomToSearch result:result];
        } else {
            result(image, error);
        }
    }];
}

- (void)scaleIfNeededLowerZoomTile:(MKTileOverlayPath)path maximumZ:(NSInteger)maximumZ result:(void (^)(NSData *, NSError *))result
{
    NSInteger overZoomLevel = path.z - maximumZ;
    if (overZoomLevel <= 0) {
        [self getTileImage:path result:result];
        return;
    }
    
    NSInteger zoomFactor = 1 << overZoomLevel;
    
    MKTileOverlayPath parentTile;
    parentTile.x = path.x >> overZoomLevel;
    parentTile.y = path.y >> overZoomLevel;
    parentTile.z = path.z - overZoomLevel;
    parentTile.contentScaleFactor = path.contentScaleFactor;
    
    NSInteger xOffset = path.x % zoomFactor;
    NSInteger yOffset = path.y % zoomFactor;
    NSInteger subTileSize = self.tileSize.width / zoomFactor;
    
    if (!_ciContext) _ciContext = [CIContext context];
    if (!_colorspace) _colorspace = CGColorSpaceCreateDeviceRGB();
    
    [self getTileImage:parentTile result:^(NSData *image, NSError *error) {
        if (!image) {
            result(nil, nil);
            return;
        }
        
        CIImage* originalCIImage = [CIImage imageWithData:image];
        
        CGRect rect;
        rect.origin.x = xOffset * subTileSize;
        rect.origin.y = self.tileSize.width - (yOffset + 1) * subTileSize;
        rect.size.width = subTileSize;
        rect.size.height = subTileSize;
        CIVector *inputRect = [CIVector vectorWithCGRect:rect];
        CIFilter* cropFilter = [CIFilter filterWithName:@"CICrop"];
        [cropFilter setValue:originalCIImage forKey:@"inputImage"];
        [cropFilter setValue:inputRect forKey:@"inputRectangle"];
        
        CGAffineTransform trans = CGAffineTransformMakeScale(zoomFactor, zoomFactor);
        CIImage* scaledCIImage = [cropFilter.outputImage imageByApplyingTransform:trans];
        
        NSData *finalImage = [_ciContext PNGRepresentationOfImage:scaledCIImage format:kCIFormatABGR8 colorSpace:_colorspace options:nil];
        result(finalImage, nil);
    }];
}

- (void)findLowerZoomTileAndScale:(MKTileOverlayPath)path tryZ:(NSInteger)tryZ minZ:(NSInteger)minZ result:(void (^)(NSData *, NSError *))result
{
    [self scaleIfNeededLowerZoomTile:path maximumZ:tryZ result:^(NSData *image, NSError *error) {
        if (image) {
            result(image, error);
        } else if (tryZ >= minZ) {
            [self findLowerZoomTileAndScale:path tryZ:tryZ - 1 minZ:minZ result:result];
        } else {
            result(nil, nil);
        }
    }];
}

- (void)getTileImage:(MKTileOverlayPath)path result:(void (^)(NSData *, NSError *))result
{
    @try{
        NSLog(@">>>>>>>>>> %d", (long)path.z < 9);
        NSString *downloadedPackagesString = [[NSUserDefaults standardUserDefaults] stringForKey:@"DOWNLOADEDPACKAGEIDS"];
        NSData* data = [downloadedPackagesString dataUsingEncoding:NSUTF8StringEncoding];
        NSMutableArray *downloadedPackages = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];  // if you are expecting  the JSON string to be in form of array else use NSDictionary instead
        [downloadedPackages addObject: @"0"];
        NSLog(@">>>>>> Downloaded packages: %@", downloadedPackages);
        NSString *targetName = [NSString stringWithFormat:@""];
        NSArray *targets = @[@"ACSIEurope", @"ACSICampingcard", @"ACSIKfk"];
        int index = (int)[targets indexOfObject: bundle];
        switch(index) {
            case 0:
                targetName = @"EURO";
                break;
            case 1:
                targetName = @"CCA";
                break;
            case 2:
                targetName = @"KFK";
                break;
            default:
                break;
                
        }
        NSURL *path1 = [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory
                                                               inDomains:NSUserDomainMask] lastObject];
        //    NSString *pathToBeAppended = [NSString stringWithFormat:@"/LocalDatabase/data/%@/maptilesindex.sqlite", targetName];
        ////    NSString *noMaptilePath = [path1.path stringByAppendingPathComponent:@"/LocalDatabase/data/no_maptiles1.png"];
        //    NSString *maptileIndexPath = [path1.path stringByAppendingPathComponent:pathToBeAppended];
        //    if ([[NSFileManager defaultManager] fileExistsAtPath:maptileIndexPath]) {
        //        sqlite3 *_database;
        //        NSMutableArray *packageIDArray =  [[NSMutableArray alloc] init];
        //        if (sqlite3_open([maptileIndexPath UTF8String], &_database) == SQLITE_OK) {
        //            NSString *query = [NSString stringWithFormat:@"SELECT PackageID FROM ZoomLevelTileRange WHERE ZoomLevel=%li AND (%li BETWEEN StartX And EndX) AND (%li BETWEEN StartY And EndY)", (long)path.z, (long)path.x, (long)path.y];
        //            sqlite3_stmt *statement;
        //            if (sqlite3_prepare_v2(_database, [query UTF8String], -1, &statement, NULL) == SQLITE_OK) {
        //                while (sqlite3_step(statement) == SQLITE_ROW) {
        //                    int packageID = sqlite3_column_int(statement, 0);
        //                    [packageIDArray addObject:[NSNumber numberWithInt:packageID]];
        //                }
        //                sqlite3_finalize(statement);
        //            } else {
        //                NSLog(@"Failes to prepare statement");
        ////                NSData *noMaptileImageData = [NSData dataWithContentsOfFile:noMaptilePath];
        //                result(nil, nil);
        //                sqlite3_close(_database);
        //                return;
        //            }
        //            sqlite3_close(_database);
        //        } else {
        //            NSLog(@"Failed to open database!");
        ////            NSData *noMaptileImageData = [NSData dataWithContentsOfFile:noMaptilePath];
        //            result(nil, nil);
        //            return;
        //        }
        //        if([packageIDArray count] == 0) {
        ////            NSData *noMaptileImageData = [NSData dataWithContentsOfFile:noMaptilePath];
        //            result(nil, nil);
        //            return;
        //        }
        for (int i = 0; i < [downloadedPackages count]; i++) {
            sqlite3 *_maptileDatabase;
            NSInteger packageID = [downloadedPackages[i] integerValue];
            NSString *maptilePathToBeAppended = [NSString stringWithFormat:@"/LocalDatabase/data/%@/maptiles.sqlite", targetName];
            if(packageID == 0 && (long)path.z < 9) {
                maptilePathToBeAppended = [NSString stringWithFormat:@"/LocalDatabase/data/%@/maptiles.sqlite", targetName];
            } else if (packageID == 0) {
                continue;
            } else {
                maptilePathToBeAppended = [NSString stringWithFormat:@"/LocalDatabase/data/%@/maptiles%@.sqlite", targetName, downloadedPackages[i]];
            }
            NSString *maptilePath = [path1.path stringByAppendingPathComponent:maptilePathToBeAppended];
            if ([[NSFileManager defaultManager] fileExistsAtPath:maptilePath]) {
                if (sqlite3_open([maptilePath UTF8String], &_maptileDatabase) == SQLITE_OK) {
                    NSString *query = [NSString stringWithFormat:@"SELECT ImageData FROM Tile WHERE ZoomLevel=%ld AND X=%ld and Y=%ld", (long)path.z, (long)path.x, (long)path.y];
                    sqlite3_stmt *statement;
                    if (sqlite3_prepare_v2(_maptileDatabase, [query UTF8String], -1, &statement, NULL) == SQLITE_OK) {
                        if (sqlite3_step(statement) == SQLITE_ROW) {
                            const void *ptr = sqlite3_column_blob(statement, 0);
                            int size = sqlite3_column_bytes(statement, 0);
                            NSData *imageData = [[NSData alloc] initWithBytes:ptr length:size];
                            if(size == 0) {
                                //                                NSData *noMaptileImageData = [NSData dataWithContentsOfFile:noMaptilePath];
                                //                                result(nil, nil);
                                sqlite3_finalize(statement);
                                sqlite3_close(_maptileDatabase);
                                continue;
                            } else {
                                result(imageData, nil);
                                sqlite3_finalize(statement);
                                sqlite3_close(_maptileDatabase);
                                return;
                            }
                        }
                        sqlite3_finalize(statement);
                    }
                    sqlite3_close(_maptileDatabase);
                }
            }
        }
        NSLog(@"Failed to open database!");
        //        NSData *noMaptileImageData = [NSData dataWithContentsOfFile:noMaptilePath];
        result(nil, nil);
        return;
    } @catch (NSException *exception) {
        // Because we see that sometimes this method causes the app to crash, we've added a try/catch block.
        // This way the exception will be caught and no tileimage will be returned, but the app will not crash.
        result(nil,nil);
        return;
    }
}

- (void)fetchTile:(MKTileOverlayPath)path result:(void (^)(NSData *, NSError *))result
{
    if (!_urlSession) [self createURLSession];
    
    [[_urlSession dataTaskWithURL:[self URLForTilePath:path]
                completionHandler:^(NSData *data,
                                    NSURLResponse *response,
                                    NSError *error) {
        result(data, error);
    }] resume];
}

- (void)writeTileImage:(NSURL *)tileCacheFileDirectory withTileCacheFilePath:(NSURL *)tileCacheFilePath withTileData:(NSData *)data
{
    NSError *error;
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:[tileCacheFileDirectory path]]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:[tileCacheFileDirectory path] withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            NSLog(@"Error: %@", error);
            return;
        }
    }
    
    [[NSFileManager defaultManager] createFileAtPath:[tileCacheFilePath path] contents:data attributes:nil];
    NSLog(@"tileCache SAVED tile %@", [tileCacheFilePath path]);
}
//
//- (void)createTileCacheDirectory
//{
//    NSError *error;
//    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
//    NSString *documentsDirectory = [paths objectAtIndex:0];
//    NSString *tileCacheBaseDirectory = [NSString stringWithFormat:@"%@/tileCache", documentsDirectory];
//    self.tileCachePath = [NSURL fileURLWithPath:tileCacheBaseDirectory isDirectory:YES];
//
//    if (![[NSFileManager defaultManager] fileExistsAtPath:[self.tileCachePath path]])
//        [[NSFileManager defaultManager] createDirectoryAtPath:[self.tileCachePath path] withIntermediateDirectories:NO attributes:nil error:&error];
//}

- (void)createURLSession
{
    if (!_urlSession) {
        _urlSession = [NSURLSession sharedSession];
    }
}
//
//- (void)checkForRefresh:(MKTileOverlayPath)path fromFilePath:(NSURL *)tileCacheFilePath
//{
//    if ([self doesFileNeedRefresh:path fromFilePath:tileCacheFilePath withMaxAge:self.tileCacheMaxAge]) {
//        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^ {
//            // This code runs asynchronously!
//            if ([self doesFileNeedRefresh:path fromFilePath:tileCacheFilePath withMaxAge:self.tileCacheMaxAge]) {
//                if (!_urlSession) [self createURLSession];
//
//                [[_urlSession dataTaskWithURL:[self URLForTilePath:path]
//                    completionHandler:^(NSData *data,
//                                        NSURLResponse *response,
//                                        NSError *error) {
//                    if (!error) {
//                        [[NSFileManager defaultManager] createFileAtPath:[tileCacheFilePath path] contents:data attributes:nil];
//                        NSLog(@"tileCache File refreshed at %@", [tileCacheFilePath path]);
//                    }
//                }] resume];
//            }
//        });
//    }
//}

- (BOOL)doesFileNeedRefresh:(MKTileOverlayPath)path fromFilePath:(NSURL *)tileCacheFilePath withMaxAge:(NSInteger)tileCacheMaxAge
{
    NSError *error;
    NSDictionary<NSFileAttributeKey, id> *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[tileCacheFilePath path] error:&error];
    
    if (fileAttributes) {
        NSDate *modificationDate = fileAttributes[@"NSFileModificationDate"];
        if (modificationDate) {
            if (-1 * (int)modificationDate.timeIntervalSinceNow > tileCacheMaxAge) {
                return YES;
            }
        }
    }
    
    return NO;
}
@end
