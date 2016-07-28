//
//  ViewController.h
//  WGMaplyGPkgTest
//
//  Created by Ranen Ghosh on 2016-07-07.
//  Copyright © 2016 mousebird consulting. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WhirlyGlobeComponent.h>

@class GPKGGeoPackage;

@interface TilePyramidViewController : UIViewController <WhirlyGlobeViewControllerDelegate, MaplyViewControllerDelegate>

@property (nonatomic, strong) GPKGGeoPackage *geoPackage;
@property (nonatomic, strong) NSString *tileTableName;
@property (nonatomic, strong) NSString *featureTableName;

@end

