//
//  LayerMenuViewController.m
//  WGMaplyGPkgTest
//
//  Created by Ranen Ghosh on 2016-07-31.
//  Copyright © 2016 mousebird consulting. All rights reserved.
//

#import "LayerMenuViewController.h"
#import <WhirlyGlobeComponent.h>


@interface LayerMenuViewItem : NSObject
@property (nonatomic, strong) NSString *displayText;
- (id) initWithDisplayText:(NSString *)displayText;
@end

@implementation LayerMenuViewItem
- (id) initWithDisplayText:(NSString *)displayText {
    self = [super init];
    if (self) {
        self.displayText = displayText;
    }
    return self;
}
@end

@interface LayerMenuViewBasemapItem : LayerMenuViewItem
@property (nonatomic, strong) NSNumber *basemapLayerIndex;
- (id) initWithDisplayText:(NSString *)displayText andBasemapLayerIndex:(int)basemapLayerIndex;
@end

@implementation LayerMenuViewBasemapItem
- (id) initWithDisplayText:(NSString *)displayText andBasemapLayerIndex:(int)basemapLayerIndex {
    self = [super initWithDisplayText:displayText];
    if (self) {
        self.basemapLayerIndex = @(basemapLayerIndex);
    }
    return self;
}
@end


@interface LayerMenuViewGeopackageItem : LayerMenuViewItem
@property (nonatomic, strong) NSString *filename;
- (id) initWithDisplayText:(NSString *)displayText andFilename:(NSString *)filename;
@end

@implementation LayerMenuViewGeopackageItem
- (id) initWithDisplayText:(NSString *)displayText andFilename:(NSString *)filename {
    self = [super initWithDisplayText:displayText];
    if (self) {
        self.filename = filename;
    }
    return self;
}
@end




@interface LayerMenuViewController () {
    RATreeView *_treeView;
    NSDictionary <NSString *, MaplyRemoteTileInfo *> *_basemapLayerTileInfoDict;
    NSArray<LayerMenuViewBasemapItem *> *_basemapLayerEntries;
    NSArray<LayerMenuViewGeopackageItem *> *_geopackageEntries;
    int _firstBasemapLayerIndex, _lastBasemapLayerIndex, _firstGeopackageIndex, _lastGeopackageIndex;
    NSArray *_directoryContent;

}

@end

@implementation LayerMenuViewController


- (id) initWithBasemapLayerTileInfoDict:(NSDictionary<NSString *, MaplyRemoteTileInfo *> *)basemapLayerTileInfoDict {
    
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _basemapLayerTileInfoDict = basemapLayerTileInfoDict;
        NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)  objectAtIndex:0];
        
        NSMutableArray <LayerMenuViewBasemapItem *> *basemapLayerEntries = [NSMutableArray <LayerMenuViewBasemapItem *> array];
        NSArray <NSString *> *allKeys = _basemapLayerTileInfoDict.allKeys;
        for (int idx=0; idx<allKeys.count; idx++) {
            NSString *displayText = allKeys[idx];
            
            _basemapLayerTileInfoDict[displayText].cacheDir = [NSString stringWithFormat:@"%@/%@/",cacheDir, displayText];
            
            [basemapLayerEntries addObject:[[LayerMenuViewBasemapItem alloc] initWithDisplayText:displayText andBasemapLayerIndex:idx]];
        }
        _basemapLayerEntries = basemapLayerEntries;
        
        _firstBasemapLayerIndex = 1;
        _lastBasemapLayerIndex = (int)(_firstBasemapLayerIndex + _basemapLayerEntries.count) - 1;
    }
    return self;
    
}

- (void)reloadDirectoryContent {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *docsDir = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    
    NSString *riversGpkgPath = [[docsDir URLByAppendingPathComponent:@"rivers.gpkg"] path];
    if (![fileManager fileExistsAtPath:riversGpkgPath]) {
        NSString *inBundlePath = [[NSBundle mainBundle] pathForResource:@"rivers" ofType:@"gpkg"];
        [fileManager copyItemAtPath:inBundlePath toPath:riversGpkgPath error:nil];
    }
    
    NSArray *directoryContent = [fileManager contentsOfDirectoryAtPath:[docsDir path] error:nil];
    NSPredicate *fltr = [NSPredicate predicateWithFormat:@"self ENDSWITH[c] '.gpkg'"];
    _directoryContent = [directoryContent filteredArrayUsingPredicate:fltr];
    
    NSMutableArray <LayerMenuViewGeopackageItem *> *geopackageEntries = [NSMutableArray <LayerMenuViewGeopackageItem *> array];
    for (NSString *filename in _directoryContent) {
        [geopackageEntries addObject:[[LayerMenuViewGeopackageItem alloc] initWithDisplayText:filename andFilename:filename]];
    }
    _geopackageEntries = geopackageEntries;
    
    _firstGeopackageIndex = _lastBasemapLayerIndex + 2;
    _lastGeopackageIndex = (int)(_firstGeopackageIndex + _geopackageEntries.count) - 1;
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    _treeView = [[RATreeView alloc] initWithFrame:self.view.bounds];
    _treeView.delegate = self;
    _treeView.dataSource = self;
    _treeView.allowsMultipleSelection = true;
    [self.view addSubview:_treeView];
    
    [self reloadDirectoryContent];
    [_treeView reloadData];
    
    [self setBasemapLayerIndex:0];
}

- (void)viewWillAppear:(BOOL)animated {
    
    LayerMenuViewBasemapItem *selBasemapItem;
    for (id selItem in [_treeView itemsForSelectedRows]) {
        if ([selItem isKindOfClass:[LayerMenuViewBasemapItem class]]) {
             selBasemapItem = (LayerMenuViewBasemapItem *)selItem;
        }
    }
    
    [self reloadDirectoryContent];
    [_treeView reloadData];
    
    if (selBasemapItem)
        [_treeView selectRowForItem:selBasemapItem animated:NO scrollPosition:RATreeViewScrollPositionNone];
}


- (void)setBasemapLayerIndex:(int)basemapLayerIndex {
    if (!self.delegate || !_basemapLayerTileInfoDict || _basemapLayerTileInfoDict.count <= basemapLayerIndex)
        return;
    MaplyRemoteTileInfo *ti = _basemapLayerTileInfoDict[_basemapLayerEntries[basemapLayerIndex].displayText];
    MaplyRemoteTileSource *tileSource = [[MaplyRemoteTileSource alloc] initWithInfo:ti];
    MaplyQuadImageTilesLayer *layer = [[MaplyQuadImageTilesLayer alloc] initWithCoordSystem:tileSource.coordSys tileSource:tileSource];
    layer.drawPriority = kMaplyImageLayerDrawPriorityDefault;
    layer.handleEdges = true;
    
    for (id selItem in [_treeView itemsForSelectedRows]) {
        if ([selItem isKindOfClass:[LayerMenuViewBasemapItem class]]) {
            LayerMenuViewBasemapItem *basemapItem = (LayerMenuViewBasemapItem *)selItem;
            if (![basemapItem.basemapLayerIndex isEqualToNumber:@(basemapLayerIndex)])
                [_treeView deselectRowForItem:selItem animated:NO];
        } else
            [_treeView deselectRowForItem:selItem animated:NO];
    }
    [_treeView selectRowForItem:_basemapLayerEntries[basemapLayerIndex] animated:NO scrollPosition:RATreeViewScrollPositionNone];
    
    [self.delegate setBasemapLayer:layer];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (NSInteger)treeView:(RATreeView *)treeView numberOfChildrenOfItem:(nullable id)item {
    if (!item && _basemapLayerEntries)
        return _basemapLayerEntries.count + _directoryContent.count + 2;
    return 0;
}

- (UITableViewCell *)treeView:(RATreeView *)treeView cellForItem:(nullable id)item {
    
    static NSString *cellIdentifier = @"BasemapCell";
    UITableViewCell *cell = [treeView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    
    if ([item isKindOfClass:[LayerMenuViewItem class]]) {
        cell.textLabel.text = ((LayerMenuViewItem *)item).displayText;
    }
    
    return cell;
}

- (id)treeView:(RATreeView *)treeView child:(NSInteger)index ofItem:(nullable id)item {
    if (!item) {
        if (index == 0)
            return  [[LayerMenuViewItem alloc] initWithDisplayText:@"BASEMAPS"];
        else if (index >= _firstBasemapLayerIndex && index <= _lastBasemapLayerIndex) {
            int basemapIdx = (int)index - _firstBasemapLayerIndex;
            return _basemapLayerEntries[basemapIdx];
        } else if (index == _lastBasemapLayerIndex + 1) {
            return  [[LayerMenuViewItem alloc] initWithDisplayText:@"GEOPACKAGES"];
        } else if (index >= _firstGeopackageIndex && index <= _lastGeopackageIndex) {
            int geopackageIdx = (int)index - _firstGeopackageIndex;
            return _geopackageEntries[geopackageIdx];
        }
    }
    return nil;
}

- (void)treeView:(RATreeView *)treeView didSelectRowForItem:(id)item {
    if (!item)
        return;
    
    if ([item isKindOfClass:[LayerMenuViewBasemapItem class]]) {
        LayerMenuViewBasemapItem *layerMenuViewItem = (LayerMenuViewBasemapItem *)item;
        [self setBasemapLayerIndex:layerMenuViewItem.basemapLayerIndex.intValue];
    }
    
}

- (id)treeView:(RATreeView *)treeView willSelectRowForItem:(id)item {
    if ([item isKindOfClass:[LayerMenuViewBasemapItem class]]) {
        return item;
    } else if ([item isKindOfClass:[LayerMenuViewGeopackageItem class]]) {
        
        LayerMenuViewGeopackageItem *geopackageItem = (LayerMenuViewGeopackageItem *)item;
        
        
        
        return nil;
    }
    return nil;
}

@end







