//
//  ViewController.m
//  WGMaplyGPkgTest
//
//  Created by Ranen Ghosh on 2016-07-07.
//  Copyright © 2016 mousebird consulting. All rights reserved.
//

#import "TilePyramidViewController.h"
#import "GPkgTestConfig.h"
#import "GPKGGeoPackageFactory.h"
#import "GPKGTileSource.h"
#import "MaplyWMSTileSource.h"
#import "GPKGIOUtils.h"
#import "GPKGFeatureTileSource.h"


@interface TilePyramidViewController ()

@end

@implementation TilePyramidViewController {
    WhirlyGlobeViewController *globeVC;
    MaplyViewController *mapVC;
    MaplyBaseViewController *theViewC;
    
    GPKGGeoPackageManager *_manager;
    GPKGGeoPackage *_geoPackage;

    
    GPKGTileSource *_gpkgTileSource;
    MaplyQuadImageTilesLayer *_imageLayer;
    
    LayerMenuViewController *_layerMenuVC;
    UIPopoverController *_popControl;
    
    MaplyQuadImageTilesLayer *_basemapLayer;
    
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *boundsPath = [[NSBundle mainBundle] pathForResource:@"bounds" ofType:@"json"];
    NSData *boundsData = [NSData dataWithContentsOfFile:boundsPath];
    NSError *error = nil;
    NSDictionary *bounds = [NSJSONSerialization JSONObjectWithData:boundsData
                                                           options:kNilOptions
                                                             error:&error];
    
    

    
    if (gpkgTestDoGlobe) {
        globeVC = [[WhirlyGlobeViewController alloc] init];
        theViewC = globeVC;
        globeVC.delegate = self;
        
        [self.view addSubview:globeVC.view];
        globeVC.view.frame = self.view.bounds;
        [self addChildViewController:globeVC];
    } else {
        mapVC = [[MaplyViewController alloc] initWithMapType:MaplyMapTypeFlat];
        theViewC = mapVC;
//        mapVC.coordSys = _gpkgTileSource.coordSys;
        mapVC.coordSys = [[MaplySphericalMercator alloc] initWebStandard];
        mapVC.delegate = self;
        
        [self.view addSubview:mapVC.view];
        mapVC.view.frame = self.view.bounds;
        [self addChildViewController:mapVC];
    }
    
    
    MaplyCoordinate startCoord = MaplyCoordinateMakeWithDegrees(-98.5795, 39.828175);
    
    UIBarButtonItem *layerMenuButton = [[UIBarButtonItem alloc] initWithTitle:@"Layer Menu" style:UIBarButtonItemStylePlain target:self action:@selector(showPopover)];
    self.navigationItem.rightBarButtonItem = layerMenuButton;
    
    _layerMenuVC = [[LayerMenuViewController alloc] initWithBasemapLayerTileInfoDict:[self getBasemapLayerTileInfoDict] bounds:bounds coordSys:theViewC.coordSystem viewC:theViewC];
    _layerMenuVC.delegate = self;
    [_layerMenuVC view];
    
    if (gpkgTestDoGlobe)
        [globeVC setPosition:startCoord height:0.5];
    else
        [mapVC setPosition:startCoord height:0.5];

}

- (NSDictionary <NSString *, MaplyRemoteTileInfo *> *) getBasemapLayerTileInfoDict {
    
    return @{
             @"Positron" :    [[MaplyRemoteTileInfo alloc] initWithBaseURL:@"http://light_all.basemaps.cartocdn.com/light_all/" ext:@"png" minZoom:0 maxZoom:20],
             @"Dark Matter" : [[MaplyRemoteTileInfo alloc] initWithBaseURL:@"http://dark_all.basemaps.cartocdn.com/dark_all/" ext:@"png" minZoom:0 maxZoom:20],
             };
}

- (void)globeViewController:(WhirlyGlobeViewController *__nonnull)viewC didTapAt:(MaplyCoordinate)coord {
    
    NSLog(@"didTapAt %f %f", coord.x * RAD_TO_DEG, coord.y * RAD_TO_DEG);
}

- (void)maplyViewController:(MaplyViewController *__nonnull)viewC didTapAt:(MaplyCoordinate)coord {

    NSLog(@"didTapAt %f %f", coord.x * RAD_TO_DEG, coord.y * RAD_TO_DEG);
}

- (void)showPopover {
    _popControl = [[UIPopoverController alloc] initWithContentViewController:_layerMenuVC];
    _popControl.delegate = self;
    [_popControl setPopoverContentSize:CGSizeMake(400.0,4.0/5.0*self.view.bounds.size.height)];
    [_popControl presentPopoverFromRect:CGRectMake(0, 0, 10, 10) inView:self.view permittedArrowDirections:UIPopoverArrowDirectionUp animated:YES];
    
    _layerMenuVC.view.frame = CGRectMake(0, 0, 400.0,4.0/5.0*self.view.bounds.size.height);
}

- (void) setBasemapLayer:(MaplyQuadImageTilesLayer *)basemapLayer {
    if (_basemapLayer) {
        [theViewC removeLayer:_basemapLayer];
    }
    _basemapLayer = basemapLayer;
    [theViewC addLayer:_basemapLayer];
}

- (void) addTileLayer:(MaplyQuadImageTilesLayer *)tileLayer {
    [theViewC addLayer:tileLayer];
}

- (void) removeTileLayer:(MaplyQuadImageTilesLayer *)tileLayer {
    [theViewC removeLayer:tileLayer];
}

- (void) addFeatureLayer:(MaplyQuadPagingLayer *)featureLayer {
    [theViewC addLayer:featureLayer];
}

- (void) removeFeatureLayer:(MaplyQuadPagingLayer *)featureLayer {
    [theViewC removeLayer:featureLayer];
}


@end
