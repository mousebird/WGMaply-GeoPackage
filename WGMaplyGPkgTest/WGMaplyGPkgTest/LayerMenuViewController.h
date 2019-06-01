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

@protocol LayerMenuViewControllerDelegate <NSObject>
- (void) setBasemapLoader:(MaplyQuadImageLoader *)basemapLayer;

- (void) addTileLoader:(MaplyQuadImageLoader *)tileLayer;
- (void) removeTileLoader:(MaplyQuadImageLoader *)tileLayer;

- (void) addFeatureLoader:(MaplyQuadPagingLoader *)featureLayer;
- (void) removeFeatureLoader:(MaplyQuadPagingLoader *)featureLayer;
@end


@protocol LayerMenuViewItemDelegate <NSObject>
- (void)toggleLayer:(id)layer;
@end



@interface LayerMenuViewController : UIViewController <RATreeViewDataSource, RATreeViewDelegate, GPKGProgress, LayerMenuViewItemDelegate>

- (id) initWithBasemapLayerTileInfoDict:(NSDictionary<NSString *, MaplyRemoteTileInfoNew *> *)basemapLayerTileInfoDict bounds:(NSDictionary *)bounds coordSys:(MaplyCoordinateSystem *)coordSys viewC:(MaplyBaseViewController *)viewC;

@property (nonatomic, weak) NSObject<LayerMenuViewControllerDelegate> *delegate;




@end
