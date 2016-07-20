//
//  ListTileTablesViewController.h
//  WGMaplyGPkgTest
//
//  Created by Ranen Ghosh on 2016-07-20.
//  Copyright © 2016 mousebird consulting. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TilePyramidViewController.h"

@class GPKGGeoPackage;

@interface ListTileTablesViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) GPKGGeoPackage *geoPackage;
@property (nonatomic, strong) NSArray *tableNames;

@end
