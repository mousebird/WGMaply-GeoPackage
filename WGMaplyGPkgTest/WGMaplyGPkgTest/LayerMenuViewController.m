//
//  LayerMenuViewController.m
//  WGMaplyGPkgTest
//
//  Created by Ranen Ghosh on 2016-07-31.
//  Copyright © 2016 mousebird consulting. All rights reserved.
//

#import "LayerMenuViewController.h"
#import <WhirlyGlobeComponent.h>
#import "GPKGGeoPackageFactory.h"
#import "GPKGTileSource.h"
#import "GPKGFeatureTileSource.h"
#import "GPKGFeatureIndexManager.h"
#import "LayerTableViewCell.h"
#import "GPKGUtils.h"

@interface LayerMenuViewItem : NSObject
@property (nonatomic, strong) NSString *displayText;
- (id) initWithDisplayText:(NSString *)displayText;
- (UITableViewCell *)cellForTreeView:(RATreeView *)treeView;
@end

@implementation LayerMenuViewItem
- (id) initWithDisplayText:(NSString *)displayText {
    self = [super init];
    if (self) {
        self.displayText = displayText;
    }
    return self;
}

- (UITableViewCell *)cellForTreeView:(RATreeView *)treeView {
    static NSString *cellIdentifier = @"LayerMenuViewItemCell";
    UITableViewCell *cell = [treeView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    cell.textLabel.text = self.displayText;

    return cell;
}
@end


@interface LayerMenuViewHeaderItem : LayerMenuViewItem
@end

@implementation LayerMenuViewHeaderItem

- (UITableViewCell *)cellForTreeView:(RATreeView *)treeView {
    static NSString *cellIdentifier = @"LayerMenuViewHeaderItemCell";
    UITableViewCell *cell = [treeView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    cell.textLabel.text = self.displayText;
    
    UIFont *font = cell.textLabel.font;
    UIFont *boldFont = [UIFont fontWithDescriptor:[[font fontDescriptor] fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold] size:font.pointSize];
    cell.textLabel.font = boldFont;
    
    return cell;
}

@end



@interface LayerMenuViewBasemapItem : LayerMenuViewItem
@property (nonatomic, assign) unsigned int basemapLayerIndex;
- (id) initWithDisplayText:(NSString *)displayText andBasemapLayerIndex:(int)basemapLayerIndex;
@end

@implementation LayerMenuViewBasemapItem
- (id) initWithDisplayText:(NSString *)displayText andBasemapLayerIndex:(int)basemapLayerIndex {
    self = [super initWithDisplayText:displayText];
    if (self) {
        self.basemapLayerIndex = basemapLayerIndex;
    }
    return self;
}
@end





@interface LayerMenuViewGeopackageItem : LayerMenuViewItem

@property (nonatomic, strong) NSString *filename;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, strong) NSArray <NSString *> *tileTableItems;
@property (nonatomic, strong) NSArray <NSString *> *featureTableItems;

- (id) initWithFilename:(NSString *)filename;
@end

@implementation LayerMenuViewGeopackageItem
- (id) initWithFilename:(NSString *)filename {
    self = [super initWithDisplayText:filename];
    if (self) {
        self.filename = filename;
    }
    return self;
}
@end




@interface LayerMenuViewImportingItem : LayerMenuViewItem

@property (nonatomic, weak) LayerMenuViewGeopackageItem *geopackageItem;

- (id) initWithParent:(LayerMenuViewGeopackageItem *)geopackageItem;
@end

@implementation LayerMenuViewImportingItem

- (id) initWithParent:(LayerMenuViewGeopackageItem *)geopackageItem {
    self = [super initWithDisplayText:@"Importing..."];
    if (self) {
        self.geopackageItem = geopackageItem;
    }
    return self;
}

@end




@interface LayerMenuViewTileTableItem : LayerMenuViewItem

@property (nonatomic, weak) LayerMenuViewGeopackageItem *geopackageItem;
@property (nonatomic, strong) NSString *tileTableName;

@property (nonatomic, strong) GPKGTileSource *tileSource;
@property (nonatomic, strong) MaplyQuadImageTilesLayer *imageLayer;

@property (nonatomic, weak) NSObject<LayerMenuViewItemDelegate> *delegate;

- (id) initWithParent:(LayerMenuViewGeopackageItem *)parent andTileTableName:(NSString *)tileTableName;
@end

@implementation LayerMenuViewTileTableItem
- (id) initWithParent:(LayerMenuViewGeopackageItem *)parent andTileTableName:(NSString *)tileTableName {
    self = [super initWithDisplayText:tileTableName];
    if (self) {
        self.geopackageItem = parent;
        self.tileTableName = tileTableName;
    }
    return self;
}

- (UITableViewCell *)cellForTreeView:(RATreeView *)treeView {
    static bool nibRegistered = false;
    static NSString *cellIdentifier = @"LayerMenuViewTileTableItemCell";
    
    if (!nibRegistered) {
        nibRegistered = true;
        [treeView registerNib:[UINib nibWithNibName:@"LayerTableViewCell" bundle:nil] forCellReuseIdentifier:cellIdentifier];
    }
    
    LayerTableViewCell *cell = [treeView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.txtLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    cell.txtLabel.text = self.tileTableName;
    cell.typeImage.image = [UIImage imageNamed:@"ic_tiles"];
    
    cell.idxImage.image = nil;
    
    cell.enabledSwitch.on = (self.imageLayer != nil);
    
    [cell.enabledSwitch removeTarget:nil action:NULL forControlEvents:UIControlEventValueChanged];
    [cell.enabledSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    
    return cell;
}
- (void) switchChanged:(id)sender {
    if (self.delegate)
        [self.delegate toggleLayer:self];
}
@end






@interface LayerMenuViewFeatureTableItem : LayerMenuViewItem

@property (nonatomic, weak) LayerMenuViewGeopackageItem *geopackageItem;
@property (nonatomic, strong) NSString *featureTableName;

@property (nonatomic, strong) GPKGFeatureTileSource *featureSource;
@property (nonatomic, strong) MaplyQuadPagingLayer *pagingLayer;

@property (nonatomic, weak) NSObject<LayerMenuViewItemDelegate> *delegate;

@property (nonatomic, assign) enum WKBGeometryType geometryType;
@property (nonatomic, assign) unsigned int count;
@property (nonatomic, assign) BOOL indexed;
@property (nonatomic, assign) BOOL indexing;

@property (nonatomic, strong) NSString *sld;
@property (nonatomic, strong) NSString *grouping;
@property (nonatomic, strong) NSString *category;
@property (nonatomic, strong) NSNumber *zorder;

- (id) initWithParent:(LayerMenuViewGeopackageItem *)parent andFeatureTableName:(NSString *)featureTableName andGeometryType:(enum WKBGeometryType)geometryType andCount:(int)count andIndexed:(bool)indexed;
@end

@implementation LayerMenuViewFeatureTableItem
- (id) initWithParent:(LayerMenuViewGeopackageItem *)parent andFeatureTableName:(NSString *)featureTableName andGeometryType:(enum WKBGeometryType)geometryType andCount:(int)count andIndexed:(bool)indexed andSLD:(NSString *)sld andGrouping:(NSString *)grouping andCategory:(NSString *)category andZOrder:(NSNumber *)zorder {
    self = [super initWithDisplayText:featureTableName];
    if (self) {
        self.geopackageItem = parent;
        self.featureTableName = featureTableName;
        self.geometryType = geometryType;
        self.count = count;
        self.indexed = indexed;
        self.sld = sld;
        self.grouping = grouping;
        self.category = category;
        self.zorder = zorder;
    }
    return self;
}

- (UITableViewCell *)cellForTreeView:(RATreeView *)treeView {
    
    static bool nibRegistered = false;
    static NSString *cellIdentifier = @"LayerMenuViewFeatureTableItemCell";
    
    if (!nibRegistered) {
        nibRegistered = true;
        [treeView registerNib:[UINib nibWithNibName:@"LayerTableViewCell" bundle:nil] forCellReuseIdentifier:cellIdentifier];
    }
    
    LayerTableViewCell *cell = [treeView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.txtLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    
    cell.txtLabel.text = [NSString stringWithFormat:@"%@ (%i)", self.featureTableName, self.count];
    if (self.geometryType == WKB_GEOMETRY || self.geometryType == WKB_GEOMETRYCOLLECTION)
        cell.typeImage.image = [UIImage imageNamed:@"ic_geometry"];
    else if (self.geometryType == WKB_POINT || self.geometryType == WKB_MULTIPOINT)
        cell.typeImage.image = [UIImage imageNamed:@"ic_point"];
    else if (self.geometryType == WKB_LINESTRING || self.geometryType == WKB_MULTILINESTRING)
        cell.typeImage.image = [UIImage imageNamed:@"ic_linestring"];
    else if (self.geometryType == WKB_POLYGON || self.geometryType == WKB_MULTIPOLYGON)
        cell.typeImage.image = [UIImage imageNamed:@"ic_polygon"];
    else
        NSLog(@"Surprise geom type: %i", self.geometryType);
    
//    if (self.indexed)
//        cell.idxImage.image = [UIImage imageNamed:@"indexed"];
//    else
        cell.idxImage.image = nil;
        
    cell.enabledSwitch.on = (self.pagingLayer != nil || self.indexing);
    [cell.enabledSwitch removeTarget:nil action:NULL forControlEvents:UIControlEventValueChanged];
    [cell.enabledSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    
    
    return cell;

}
- (void) switchChanged:(id)sender {
    if (self.delegate)
        [self.delegate toggleLayer:self];
}
@end




@interface LayerMenuViewIndexingItem : LayerMenuViewItem

@property (nonatomic, weak) LayerMenuViewFeatureTableItem *featureTableItem;
@property (nonatomic, assign) BOOL cancel;
@property (nonatomic, strong) GPKGGeoPackage *gpkg;
@property (nonatomic, strong) GPKGFeatureDao *featureDao;


- (id) initWithParent:(LayerMenuViewFeatureTableItem *)featureTableItem;
@end

@implementation LayerMenuViewIndexingItem

- (id) initWithParent:(LayerMenuViewFeatureTableItem *)featureTableItem {
    self = [super initWithDisplayText:@"Indexing..."];
    if (self) {
        self.featureTableItem = featureTableItem;
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
    GPKGGeoPackageManager *_gpkgGeoPackageManager;
    LayerMenuViewImportingItem *_importingGeopackageItem;
    NSDictionary *_bounds;
    MaplyCoordinateSystem *_coordSys;
    LayerMenuViewIndexingItem *_indexingItem;
}

@end

@implementation LayerMenuViewController


- (id) initWithBasemapLayerTileInfoDict:(NSDictionary<NSString *, MaplyRemoteTileInfo *> *)basemapLayerTileInfoDict bounds:(NSDictionary *)bounds coordSys:(MaplyCoordinateSystem *)coordSys {
    
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _basemapLayerTileInfoDict = basemapLayerTileInfoDict;
        _bounds = bounds;
        _coordSys = coordSys;
        
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
        
        _gpkgGeoPackageManager = [GPKGGeoPackageFactory getManager];
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
        [geopackageEntries addObject:[[LayerMenuViewGeopackageItem alloc] initWithFilename:filename]];
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
    
    [self setBasemapLayerIndex:_basemapLayerEntries.count-1];
}

- (void)viewWillAppear:(BOOL)animated {
    
    _treeView.frame = self.view.bounds;
    LayerMenuViewBasemapItem *selBasemapItem;
    for (id selItem in [_treeView itemsForSelectedRows]) {
        if ([selItem isKindOfClass:[LayerMenuViewBasemapItem class]]) {
             selBasemapItem = (LayerMenuViewBasemapItem *)selItem;
        }
    }
    
    // FIXME: reloading is buggy
    //[self reloadDirectoryContent];
    //[_treeView reloadData];
    
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
            if (basemapItem.basemapLayerIndex != basemapLayerIndex)
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

#pragma mark RATreeView Delegate and Data Source methods

- (NSInteger)treeView:(RATreeView *)treeView numberOfChildrenOfItem:(nullable id)item {
    if (!item && _basemapLayerEntries)
        return _basemapLayerEntries.count + _directoryContent.count + 2;
    
    if ([item isKindOfClass:[LayerMenuViewGeopackageItem class]]) {
        
        LayerMenuViewGeopackageItem *geopackageItem = (LayerMenuViewGeopackageItem *)item;
        if (_importingGeopackageItem && _importingGeopackageItem.geopackageItem == geopackageItem) {
            return 1;
        }
        
        if (!geopackageItem.loaded)
            return 0;
        return geopackageItem.tileTableItems.count + geopackageItem.featureTableItems.count;
        
    }
    if ([item isKindOfClass:[LayerMenuViewFeatureTableItem class]]) {
        LayerMenuViewFeatureTableItem *featureTableItem = (LayerMenuViewFeatureTableItem *)item;
        if (_indexingItem && featureTableItem.indexing && _indexingItem.featureTableItem == featureTableItem) {
            return 1;
        }
    }
    return 0;
}

- (UITableViewCell *)treeView:(RATreeView *)treeView cellForItem:(nullable id)item {
    
    if (![item isKindOfClass:[LayerMenuViewItem class]])
        return nil;
    
    LayerMenuViewItem *layerMenuViewItem = (LayerMenuViewItem *)item;
    return [layerMenuViewItem cellForTreeView:treeView];
}

- (id)treeView:(RATreeView *)treeView child:(NSInteger)index ofItem:(nullable id)item {
    if (!item) {
        if (index == 0)
            return  [[LayerMenuViewHeaderItem alloc] initWithDisplayText:@"BASEMAPS"];
        else if (index >= _firstBasemapLayerIndex && index <= _lastBasemapLayerIndex) {
            int basemapIdx = (int)index - _firstBasemapLayerIndex;
            return _basemapLayerEntries[basemapIdx];
        } else if (index == _lastBasemapLayerIndex + 1) {
            return  [[LayerMenuViewHeaderItem alloc] initWithDisplayText:@"GEOPACKAGES"];
        } else if (index >= _firstGeopackageIndex && index <= _lastGeopackageIndex) {
            int geopackageIdx = (int)index - _firstGeopackageIndex;
            return _geopackageEntries[geopackageIdx];
        }
    }
    if ([item isKindOfClass:[LayerMenuViewGeopackageItem class]]) {
        LayerMenuViewGeopackageItem *geopackageItem = (LayerMenuViewGeopackageItem *)item;
        if (_importingGeopackageItem && _importingGeopackageItem.geopackageItem == geopackageItem && index==0)
            return _importingGeopackageItem;
        if (!geopackageItem.loaded)
            return nil;
        if (index < geopackageItem.tileTableItems.count)
            return geopackageItem.tileTableItems[index];
        else
            return geopackageItem.featureTableItems[index-geopackageItem.tileTableItems.count];
    }
    
    if ([item isKindOfClass:[LayerMenuViewFeatureTableItem class]]) {
        LayerMenuViewFeatureTableItem *featureTableItem = (LayerMenuViewFeatureTableItem *)item;
        if (_indexingItem && featureTableItem.indexing && _indexingItem.featureTableItem == featureTableItem && index==0) {
            return _indexingItem;
        }
    }
    return nil;
}

- (void)treeView:(RATreeView *)treeView didSelectRowForItem:(id)item {
    if (!item)
        return;
    
    if ([item isKindOfClass:[LayerMenuViewBasemapItem class]]) {
        LayerMenuViewBasemapItem *layerMenuViewItem = (LayerMenuViewBasemapItem *)item;
        [self setBasemapLayerIndex:layerMenuViewItem.basemapLayerIndex];
    }
    
}

- (id)treeView:(RATreeView *)treeView willDeselectRowForItem:(id)item {
    if ([_treeView itemsForSelectedRows].count == 1)
        return nil;
    return item;
}

- (id)treeView:(RATreeView *)treeView willSelectRowForItem:(id)item {
    
    if ([item isKindOfClass:[LayerMenuViewBasemapItem class]]) {
        return item;
    } else if ([item isKindOfClass:[LayerMenuViewGeopackageItem class]]) {
        
        if (_importingGeopackageItem || _indexingItem)
            return nil;
        
        LayerMenuViewGeopackageItem *geopackageItem = (LayerMenuViewGeopackageItem *)item;
        
        if (geopackageItem.loaded) {
            [self toggleGeopackageItem:geopackageItem];
            return nil;
        }
        
        _importingGeopackageItem = [[LayerMenuViewImportingItem alloc] initWithParent:geopackageItem];
        
        [_treeView insertItemsAtIndexes:[NSIndexSet indexSetWithIndex:0] inParent:geopackageItem withAnimation:RATreeViewRowAnimationLeft];
        [_treeView expandRowForItem:geopackageItem withRowAnimation:RATreeViewRowAnimationLeft];
        [_treeView reloadRowsForItems:@[geopackageItem] withRowAnimation:RATreeViewRowAnimationNone];
        
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *docsDir = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
        NSURL *url = [docsDir URLByAppendingPathComponent:geopackageItem.filename];

        @try {
            NSLog(@"Importing GeoPackage...");
            [_gpkgGeoPackageManager importGeoPackageFromUrl:url withName:geopackageItem.filename andProgress:self];
            NSLog(@"GeoPackage imported.");
        } @catch (NSException *exception) {
            if (![exception.name isEqualToString:@"Database Exists"]) {
                NSLog(@"Error: unexpected exception on importing GeoPackage.");
                NSLog(@"%@", exception);
                _importingGeopackageItem = nil;
                [_treeView deleteItemsAtIndexes:[NSIndexSet indexSetWithIndex:0] inParent:geopackageItem withAnimation:RATreeViewRowAnimationLeft];
//                [_treeView reloadRowsForItems:@[geopackageItem] withRowAnimation:RATreeViewRowAnimationNone];
                [_gpkgGeoPackageManager close];
                _gpkgGeoPackageManager = [GPKGGeoPackageFactory getManager];
                return nil;
            }
            NSLog(@"GeoPackage already imported.");
            [self completed];
        }
        
        return nil;
    }
    return nil;
}

#pragma mark GPKGProgress methods

-(void) setMax: (int) max {
    
}

-(void) addProgress: (int) progress {
    
}

-(BOOL) isActive {
    if (_indexingItem && _indexingItem.cancel) {
        
        return NO;
    }
    return YES;
}

-(BOOL) cleanupOnCancel {
    return YES;
}

- (void) completed {
    if (_importingGeopackageItem) {
        [self completedImport];
    }
    // For some reason, completed doesn't get called when indexing is done from another thread...
    // Have to call completeIndexing explicitly in toggleLayer: .
//    else if (_indexingItem) {
//        [self completedIndexing];
//    }
}
- (void) completedImport {
    LayerMenuViewGeopackageItem *geopackageItem = _importingGeopackageItem.geopackageItem;
    GPKGGeoPackage *gpkg = [_gpkgGeoPackageManager open:geopackageItem.filename];
    if (!gpkg) {
        NSLog(@"Error: GeoPackage is nil.");
        _importingGeopackageItem = nil;
        [_treeView deleteItemsAtIndexes:[NSIndexSet indexSetWithIndex:0] inParent:geopackageItem withAnimation:RATreeViewRowAnimationLeft];
//        [_treeView reloadRowsForItems:@[geopackageItem] withRowAnimation:RATreeViewRowAnimationNone];
        [_gpkgGeoPackageManager close];
        _gpkgGeoPackageManager = [GPKGGeoPackageFactory getManager];
        return;
    }
    
    NSMutableDictionary *extraContents = [NSMutableDictionary dictionary];
    GPKGContentsDao *contentsDao = [gpkg getContentsDao];
    GPKGResultSet *results;
    @try {
        results = [contentsDao rawQuery:@"SELECT table_name, sld, grouping, category, zorder FROM gpkg_contents;"];
        while([results moveToNext]) {
            NSArray *result = [results getRow];
            NSString *tableName = result[0];
            NSString *sld = result[1];
            NSString *grouping = result[2];
            NSString *category = result[3];
            NSNumber *zorder = result[4];
            NSMutableDictionary *tableInfo = [NSMutableDictionary dictionary];
            [GPKGUtils setObject:sld forKey:@"sld" inDictionary:tableInfo];
            [GPKGUtils setObject:grouping forKey:@"grouping" inDictionary:tableInfo];
            [GPKGUtils setObject:category forKey:@"category" inDictionary:tableInfo];
            [GPKGUtils setObject:zorder forKey:@"zorder" inDictionary:tableInfo];
            extraContents[tableName] = tableInfo;
        }
    } @catch (NSException *exception) {
        @try {
            if (results)
                [results close];
        } @catch (NSException *exception) {
        }
        results = nil;
        
        [gpkg close];
        gpkg = [_gpkgGeoPackageManager open:geopackageItem.filename];
    }
    @try {
        if (results)
            [results close];
    } @catch (NSException *exception) {
    }
    
    
    
    
    GPKGTileMatrixSetDao *tmsd = [gpkg getTileMatrixSetDao];
    NSArray *tileTables;
    @try {
        tileTables = [tmsd getTileTables];
    } @catch (NSException *exception) {
        tileTables = nil;
    }
    tmsd = nil;

    GPKGGeometryColumnsDao *gcd = [gpkg getGeometryColumnsDao];
    NSArray *featureTables;
    NSMutableArray <NSNumber *> *featureCounts = [NSMutableArray array];
    NSMutableArray <NSNumber *> *geometryTypes = [NSMutableArray array];
    NSMutableArray <NSNumber *> *indexedStates = [NSMutableArray array];
    @try {
        featureTables = [gcd getFeatureTables];
        
        for (NSString *tableName in featureTables) {
            GPKGFeatureDao *featureDao = [gpkg getFeatureDaoWithTableName:tableName];
            [featureCounts addObject:@([featureDao count])];
            GPKGGeometryColumns *geometryColumns = [featureDao geometryColumns];
            [geometryTypes addObject:@(geometryColumns.getGeometryType)];
            GPKGFeatureIndexManager *indexer = [[GPKGFeatureIndexManager alloc] initWithGeoPackage:gpkg andFeatureDao:featureDao];
            [indexedStates addObject:@([indexer isIndexedWithFeatureIndexType:GPKG_FIT_GEOPACKAGE])];
            [indexer close];
        }
        
        
        
    } @catch (NSException *exception) {
        featureTables = nil;
    }
    gcd = nil;
    [gpkg close];
    
    NSMutableArray *tileTableItems = [NSMutableArray array];
    if (tileTables) {
        for (NSString *tileTable in tileTables) {
            LayerMenuViewTileTableItem *tileTableItem = [[LayerMenuViewTileTableItem alloc] initWithParent:geopackageItem andTileTableName:tileTable];
            tileTableItem.delegate = self;
            [tileTableItems addObject:tileTableItem];
        }
    }
    geopackageItem.tileTableItems = tileTableItems;
    
    NSMutableArray *featureTableItems = [NSMutableArray array];
    if (featureTables) {
        for (int i=0; i<featureTables.count; i++) {
            NSString *featureTable = featureTables[i];
            int count = featureCounts[i].intValue;
            bool indexed = indexedStates[i].boolValue;
            enum WKBGeometryType geometryType = geometryTypes[i].intValue;
            
            NSDictionary *tableInfo = extraContents[featureTable];
            NSString *sld, *grouping, *category;
            NSNumber *zorder;
            if (tableInfo) {
                sld = tableInfo[@"sld"];
                grouping = tableInfo[@"grouping"];
                category = tableInfo[@"category"];
                zorder = tableInfo[@"zorder"];
            }
            
            LayerMenuViewFeatureTableItem *featureTableItem = [[LayerMenuViewFeatureTableItem alloc] initWithParent:geopackageItem andFeatureTableName:featureTable andGeometryType:geometryType andCount:count andIndexed:indexed andSLD:sld andGrouping:grouping andCategory:category andZOrder:zorder];
            
            
            featureTableItem.delegate = self;
            [featureTableItems addObject:featureTableItem];
        }
    }
    geopackageItem.featureTableItems = featureTableItems;
    
    geopackageItem.loaded = TRUE;
    
    [_treeView collapseRowForItem:geopackageItem withRowAnimation:RATreeViewRowAnimationNone];
    [_treeView deleteItemsAtIndexes:[NSIndexSet indexSetWithIndex:0] inParent:geopackageItem withAnimation:RATreeViewRowAnimationNone];
    [_treeView insertItemsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, tileTableItems.count + featureTableItems.count)] inParent:geopackageItem withAnimation:RATreeViewRowAnimationNone];
    _importingGeopackageItem = nil;
    [_treeView expandRowForItem:geopackageItem withRowAnimation:RATreeViewRowAnimationLeft];
}

- (void)completedIndexing {
    dispatch_async(dispatch_get_main_queue(), ^{
        LayerMenuViewFeatureTableItem *featureTableItem = _indexingItem.featureTableItem;
        featureTableItem.indexing = NO;
        [_treeView deleteItemsAtIndexes:[NSIndexSet indexSetWithIndex:0] inParent:featureTableItem withAnimation:RATreeViewRowAnimationLeft];
        
        if (_indexingItem.cancel) {
//            [_indexingItem.featureDao rollbackTransaction];
//            [_indexingItem.gpkg close];
        } else {
//            [_indexingItem.featureDao commitTransaction];
            
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSURL *docsDir = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
            NSURL *sldURL;
            if (featureTableItem.sld && ![featureTableItem.sld isEqual:[NSNull null]])
                sldURL = [NSURL URLWithString:featureTableItem.sld relativeToURL:docsDir];
            
            GPKGFeatureTileSource *featureTileSource = [[GPKGFeatureTileSource alloc] initWithGeoPackage:_indexingItem.gpkg tableName:featureTableItem.featureTableName bounds:_bounds sldURL:sldURL];
            
            MaplyQuadPagingLayer *vecLayer = [[MaplyQuadPagingLayer alloc] initWithCoordSystem:_coordSys delegate:featureTileSource];
            vecLayer.numSimultaneousFetches = 1;
            vecLayer.drawPriority = kMaplyImageLayerDrawPriorityDefault + 200;
            
            featureTableItem.featureSource = featureTileSource;
            featureTableItem.pagingLayer = vecLayer;
            featureTableItem.indexed = YES;
            [self.delegate addFeatureLayer:vecLayer];
        }
        
        [_treeView reloadRowsForItems:@[featureTableItem] withRowAnimation:RATreeViewRowAnimationNone];
        
        _indexingItem.featureDao = nil;
        _indexingItem.gpkg = nil;
        _indexingItem = nil;
    });
}

-(void) failureWithError: (NSString *) error {
    if (_importingGeopackageItem) {
        NSLog(@"Error; GeoPackage import failed.");
        NSLog(@"%@", error);
        LayerMenuViewGeopackageItem *geopackageItem = _importingGeopackageItem.geopackageItem;
        _importingGeopackageItem = nil;
        [_treeView deleteItemsAtIndexes:[NSIndexSet indexSetWithIndex:0] inParent:geopackageItem withAnimation:RATreeViewRowAnimationLeft];
//        [_treeView reloadRowsForItems:@[geopackageItem] withRowAnimation:RATreeViewRowAnimationNone];
        [_gpkgGeoPackageManager close];
        _gpkgGeoPackageManager = [GPKGGeoPackageFactory getManager];
    } else if (_indexingItem) {
        NSLog(@"Error; GeoPackage feature indexing failed.");
        NSLog(@"%@", error);
        LayerMenuViewFeatureTableItem *featureTableItem = _indexingItem.featureTableItem;
        featureTableItem.indexing = NO;
        if (_indexingItem.featureDao) {
            @try {
                [_indexingItem.featureDao rollbackTransaction];
            } @catch (NSException *exception) {
            }
            _indexingItem.featureDao = nil;
        }
        if (_indexingItem.gpkg) {
            @try {
                [_indexingItem.gpkg close];
            } @catch (NSException *exception) {
            }
            _indexingItem.gpkg = nil;
        }
        _indexingItem = nil;
        [_treeView deleteItemsAtIndexes:[NSIndexSet indexSetWithIndex:0] inParent:featureTableItem withAnimation:RATreeViewRowAnimationLeft];
//        [_treeView reloadRowsForItems:@[featureTableItem] withRowAnimation:RATreeViewRowAnimationNone];
        [_gpkgGeoPackageManager close];
        _gpkgGeoPackageManager = [GPKGGeoPackageFactory getManager];
    }
}

- (void)toggleGeopackageItem:(LayerMenuViewGeopackageItem *)geopackageItem {
    BOOL expanded = [_treeView isCellForItemExpanded:geopackageItem];
    if (expanded)
        [_treeView collapseRowForItem:geopackageItem withRowAnimation:RATreeViewRowAnimationLeft];
    else
        [_treeView expandRowForItem:geopackageItem withRowAnimation:RATreeViewRowAnimationLeft];
}

- (void)toggleLayer:(id)layerItem {
    if (!self.delegate)
        return;
    
    if ([layerItem isKindOfClass:[LayerMenuViewTileTableItem class]]) {
        
        LayerMenuViewTileTableItem *tileTableItem = (LayerMenuViewTileTableItem *)layerItem;
        if (tileTableItem.imageLayer) {
            [self.delegate removeTileLayer:tileTableItem.imageLayer];
            tileTableItem.imageLayer = nil;
            [tileTableItem.tileSource close];
            tileTableItem.tileSource = nil;
        } else {
            LayerMenuViewGeopackageItem *geopackageItem = tileTableItem.geopackageItem;
            GPKGGeoPackage *gpkg = [_gpkgGeoPackageManager open:geopackageItem.filename];
            
            GPKGTileSource *gpkgTileSource = [[GPKGTileSource alloc] initWithGeoPackage:gpkg tableName:tileTableItem.tileTableName bounds:_bounds];
            
            MaplyQuadImageTilesLayer *imageLayer = [[MaplyQuadImageTilesLayer alloc] initWithCoordSystem:gpkgTileSource.coordSys tileSource:gpkgTileSource];
            
            imageLayer.numSimultaneousFetches = 2;
            // This fades in the image layer
//            imageLayer.color = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.5];
            imageLayer.drawPriority = kMaplyImageLayerDrawPriorityDefault + 100;
            
            tileTableItem.tileSource = gpkgTileSource;
            tileTableItem.imageLayer = imageLayer;
            [self.delegate addTileLayer:imageLayer];
            
        }
        
        
    } else if ([layerItem isKindOfClass:[LayerMenuViewFeatureTableItem class]]) {
        
        LayerMenuViewFeatureTableItem *featureTableItem = (LayerMenuViewFeatureTableItem *)layerItem;
        if (featureTableItem.pagingLayer) {
            [self.delegate removeFeatureLayer:featureTableItem.pagingLayer];
            featureTableItem.pagingLayer = nil;
            [featureTableItem.featureSource close];
            featureTableItem.featureSource = nil;
        } else {
            
            if (_importingGeopackageItem ||
                (_indexingItem && (_indexingItem.featureTableItem != featureTableItem || _indexingItem.cancel)) ) {
                
                [_treeView reloadRowsForItems:@[featureTableItem] withRowAnimation:RATreeViewRowAnimationNone];
                return;
            }
            if (_indexingItem) {
                _indexingItem.cancel = YES;
                return;
            }
            
            

            
            _indexingItem = [[LayerMenuViewIndexingItem alloc] initWithParent:featureTableItem];
            
            featureTableItem.indexing = YES;
            
            [_treeView insertItemsAtIndexes:[NSIndexSet indexSetWithIndex:0] inParent:featureTableItem withAnimation:RATreeViewRowAnimationLeft];
            [_treeView expandRowForItem:featureTableItem withRowAnimation:RATreeViewRowAnimationLeft];
            [_treeView reloadRowsForItems:@[featureTableItem] withRowAnimation:RATreeViewRowAnimationNone];
            
            
            LayerMenuViewGeopackageItem *geopackageItem = featureTableItem.geopackageItem;
            GPKGGeoPackage *gpkg = [_gpkgGeoPackageManager open:geopackageItem.filename];
            _indexingItem.gpkg = gpkg;
            
            GPKGFeatureDao *featureDao = [gpkg getFeatureDaoWithTableName:featureTableItem.featureTableName];
            _indexingItem.featureDao = featureDao;
            
//            GPKGFeatureIndexManager *indexer = [[GPKGFeatureIndexManager alloc] initWithGeoPackage:gpkg andFeatureDao:featureDao];
//            [indexer setProgress:self];

            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
//                NSLog(@"LayerMenuViewController: Starting index.");
//                @try {
//                    [featureDao beginTransaction];
//                    [indexer indexWithFeatureIndexType:GPKG_FIT_GEOPACKAGE];
//                    // Commit the transaction in completedIndexing method.
//                } @catch (NSException *exception) {
//                    NSLog(@"LayerMenuViewController: Error indexing geometry.");
//                    NSLog(@"%@", exception);
//                    [featureDao rollbackTransaction];
//                    dispatch_async(dispatch_get_main_queue(), ^{
//                        featureTableItem.indexing = NO;
//                        _indexingItem.featureDao = nil;
//                        [gpkg close];
//                        _indexingItem.gpkg = nil;
//                        _indexingItem = nil;
//                        [_treeView deleteItemsAtIndexes:[NSIndexSet indexSetWithIndex:0] inParent:featureTableItem withAnimation:RATreeViewRowAnimationLeft];
////                        [_treeView reloadRowsForItems:@[featureTableItem] withRowAnimation:RATreeViewRowAnimationNone];
//                        [_gpkgGeoPackageManager close];
//                        _gpkgGeoPackageManager = [GPKGGeoPackageFactory getManager];
//
//                    });
//                    
//                }
//                NSLog(@"LayerMenuViewController: Finished index.");
                [self completedIndexing];
                    
                
            });
            
        }
        
    }
    return;
    
}

@end







