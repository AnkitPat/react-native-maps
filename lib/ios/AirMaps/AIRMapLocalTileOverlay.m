//
//  AIRMapLocalTileOverlay.m
//  Pods-AirMapsExplorer
//
//  Created by Peter Zavadsky on 04/12/2017.
//

#import "AIRMapLocalTileOverlay.h"
#import "sqlite3.h"

#define bundle [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"]

@interface AIRMapLocalTileOverlay ()
@end

@implementation AIRMapLocalTileOverlay


-(void)loadTileAtPath:(MKTileOverlayPath)path result:(void (^)(NSData *, NSError *))result {
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
    NSString *pathToBeAppended = [NSString stringWithFormat:@"/LocalDatabase/data/%@/maptilesindex.sqlite", targetName];
    NSString *noMaptilePath = [path1.path stringByAppendingPathComponent:@"/LocalDatabase/data/no_maptiles1.png"];
    NSString *maptileIndexPath = [path1.path stringByAppendingPathComponent:pathToBeAppended];
    if ([[NSFileManager defaultManager] fileExistsAtPath:maptileIndexPath]) {
        sqlite3 *_database;
        NSMutableArray *packageIDArray =  [[NSMutableArray alloc] init];
        if (sqlite3_open([maptileIndexPath UTF8String], &_database) == SQLITE_OK) {
            NSString *query = [NSString stringWithFormat:@"SELECT PackageID FROM ZoomLevelTileRange WHERE ZoomLevel=%li AND (%li BETWEEN StartX And EndX) AND (%li BETWEEN StartY And EndY)", (long)path.z, (long)path.x, (long)path.y];
            sqlite3_stmt *statement;
            if (sqlite3_prepare_v2(_database, [query UTF8String], -1, &statement, NULL) == SQLITE_OK) {
                while (sqlite3_step(statement) == SQLITE_ROW) {
                    int packageID = sqlite3_column_int(statement, 0);
                    [packageIDArray addObject:[NSNumber numberWithInt:packageID]];
                }
                sqlite3_finalize(statement);
            } else {
                NSLog(@"Failes to prepare statement");
                NSData *noMaptileImageData = [NSData dataWithContentsOfFile:noMaptilePath];
                result(noMaptileImageData, nil);
                sqlite3_close(_database);
                return;
            }
            sqlite3_close(_database);
        } else {
            NSLog(@"Failed to open database!");
            NSData *noMaptileImageData = [NSData dataWithContentsOfFile:noMaptilePath];
            result(noMaptileImageData, nil);
            return;
        }
        if([packageIDArray count] == 0) {
            NSData *noMaptileImageData = [NSData dataWithContentsOfFile:noMaptilePath];
            result(noMaptileImageData, nil);
            return;
        }
        for (int i = 0; i < [packageIDArray count]; i++) {
            sqlite3 *_maptileDatabase;
            NSInteger packageID = [packageIDArray[i] integerValue];
            NSString *maptilePathToBeAppended = [NSString stringWithFormat:@"/LocalDatabase/data/%@/maptiles.sqlite", targetName];
            if(packageID == 0) {
                maptilePathToBeAppended = [NSString stringWithFormat:@"/LocalDatabase/data/%@/maptiles.sqlite", targetName];
            } else {
                maptilePathToBeAppended = [NSString stringWithFormat:@"/LocalDatabase/data/%@/maptiles%@.sqlite", targetName, packageIDArray[i]];
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
                                NSData *noMaptileImageData = [NSData dataWithContentsOfFile:noMaptilePath];
                                result(noMaptileImageData, nil);
                                sqlite3_finalize(statement);
                                sqlite3_close(_maptileDatabase);
                                return;
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
        NSData *noMaptileImageData = [NSData dataWithContentsOfFile:noMaptilePath];
        result(noMaptileImageData, nil);
        return;
    }
}

@end
