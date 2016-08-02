//
//  LayerMenuViewController.h
//  WGMaplyGPkgTest
//
//  Created by Ranen Ghosh on 2016-07-31.
//  Copyright © 2016 mousebird consulting. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RATreeView.h"

@class MaplyQuadImageTilesLayer;
@class MaplyRemoteTileInfo;

@protocol LayerMenuViewControllerDelegate <NSObject>

- (void) setBasemapLayer:(MaplyQuadImageTilesLayer *)basemapLayer;

@end

@interface LayerMenuViewController : UIViewController <RATreeViewDataSource, RATreeViewDelegate>

- (id) initWithBasemapLayerTileInfoDict:(NSDictionary<NSString *, MaplyRemoteTileInfo *> *)basemapLayerTileInfoDict;

@property (nonatomic, weak) NSObject<LayerMenuViewControllerDelegate> *delegate;




@end
