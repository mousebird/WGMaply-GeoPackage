//
//  LayerMenuViewController.h
//  WGMaplyGPkgTest
//
//  Created by Ranen Ghosh on 2016-07-31.
//  Copyright © 2016 mousebird consulting. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RATreeView.h"
#import "GPKGProgress.h"
#import "WhirlyGlobeComponent.h"


@class MaplyQuadImageTilesLayer;
@class MaplyQuadPagingLayer;
@class MaplyRemoteTileInfo;
@class MaplyCoordinateSystem;

@protocol LayerMenuViewControllerDelegate <NSObject>
- (void) setBasemapLayer:(MaplyQuadImageTilesLayer *)basemapLayer;

- (void) addTileLayer:(MaplyQuadImageTilesLayer *)tileLayer;
- (void) removeTileLayer:(MaplyQuadImageTilesLayer *)tileLayer;

- (void) addFeatureLayer:(MaplyQuadPagingLayer *)featureLayer;
- (void) removeFeatureLayer:(MaplyQuadPagingLayer *)featureLayer;
@end


@protocol LayerMenuViewItemDelegate <NSObject>
- (void)toggleLayer:(id)layer;
@end



@interface LayerMenuViewController : UIViewController <RATreeViewDataSource, RATreeViewDelegate, GPKGProgress, LayerMenuViewItemDelegate>

- (id) initWithBasemapLayerTileInfoDict:(NSDictionary<NSString *, MaplyRemoteTileInfo *> *)basemapLayerTileInfoDict bounds:(NSDictionary *)bounds coordSys:(MaplyCoordinateSystem *)coordSys viewC:(MaplyBaseViewController *)viewC;

@property (nonatomic, weak) NSObject<LayerMenuViewControllerDelegate> *delegate;




@end
