//
//  StartupViewController.m
//  WGMaplyGPkgTest
//
//  Created by Ranen Ghosh on 2016-07-20.
//  Copyright © 2016 mousebird consulting. All rights reserved.
//

#import "StartupViewController.h"
#import "ListTileTablesViewController.h"
#import "GPKGGeoPackageFactory.h"

@interface StartupViewController ()

@end

@implementation StartupViewController {
    GPKGGeoPackageManager *_gpkgGeoPackageManager;
    NSString *selectedFilename;
    
    UITableView *_tableView;
    NSArray *_directoryContent;
    
    GPKGGeoPackage *_gpkg;
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Choose Geopackage";
    
    _gpkgGeoPackageManager = [GPKGGeoPackageFactory getManager];
    [self reloadDirectoryContent];
    
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor grayColor];
    _tableView.separatorColor = [UIColor whiteColor];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_tableView];
    self.view.autoresizesSubviews = true;
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

}

- (void)viewWillAppear:(BOOL)animated
{
    
    [self reloadDirectoryContent];
    [_tableView reloadData];
    
    if (_gpkg) {
        [_gpkg close];
        _gpkg = nil;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}



#pragma mark - Table Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _directoryContent.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString *title = nil;
    return title;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    
    cell.textLabel.text = _directoryContent[indexPath.row];
    
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.backgroundColor = [UIColor grayColor];
    
    return cell;
}


#pragma mark - Table Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    selectedFilename = _directoryContent[indexPath.row];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *docsDir = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *url = [docsDir URLByAppendingPathComponent:selectedFilename];
    
    
    @try {
        NSLog(@"Importing GeoPackage...");
        [_gpkgGeoPackageManager importGeoPackageFromUrl:url withName:selectedFilename andProgress:self];
        NSLog(@"GeoPackage imported.");
    } @catch (NSException *exception) {
        if (![exception.name isEqualToString:@"Database Exists"]) {
            NSLog(@"Error: unexpected exception on importing GeoPackage.");
            NSLog(@"%@", exception);
            [_gpkgGeoPackageManager close];
            return;
        }
        NSLog(@"GeoPackage already imported.");
        [self completed];
    }
    
    

//    ViewController *viewC = [[ViewController alloc] initWithNibName:nil bundle:nil];
//    [self.navigationController pushViewController:viewC animated:YES];
}


-(void) setMax: (int) max {
    
}

-(void) addProgress: (int) progress {
    
}

-(BOOL) isActive {
    return YES;
}

-(BOOL) cleanupOnCancel {
    return YES;
}

-(void) completed {
    _gpkg = [_gpkgGeoPackageManager open:selectedFilename];
    if (!_gpkg) {
        _gpkg = [_gpkgGeoPackageManager open:selectedFilename];
    }
    if (!_gpkg) {
        NSLog(@"Error: GeoPackage is nil.");
        return;
    }
    GPKGTileMatrixSetDao *tmsd = [_gpkg getTileMatrixSetDao];
    NSArray *tileTables;
    @try {
        tileTables = [tmsd getTileTables];
    } @catch (NSException *exception) {
        tileTables = nil;
    }
    tmsd = nil;
    
    GPKGGeometryColumnsDao *gcd = [_gpkg getGeometryColumnsDao];
    NSArray *featureTables;
    @try {
        featureTables = [gcd getFeatureTables];
        NSLog(@"featureTables: %@", featureTables);
    } @catch (NSException *exception) {
        featureTables = nil;
    }
    gcd = nil;
    
    if ((!tileTables || tileTables.count < 1) && (!featureTables || featureTables.count < 1)) {
        NSLog(@"No tile pyramids or geometry features found in this geopackage.");
        return;
    }
    
    [_gpkg close];
    _gpkg = [_gpkgGeoPackageManager open:selectedFilename];
    
    ListTileTablesViewController *lttvc = [[ListTileTablesViewController alloc] initWithNibName:nil bundle:nil];
    lttvc.geoPackage = _gpkg;
    lttvc.tileTableNames = tileTables;
    lttvc.featureTableNames = featureTables;
    [self.navigationController pushViewController:lttvc animated:YES];
}

-(void) failureWithError: (NSString *) error {
    NSLog(@"Error; GeoPackage import failed.");
    NSLog(@"%@", error);
}


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
