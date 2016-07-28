//
//  ListTileTablesViewController.m
//  WGMaplyGPkgTest
//
//  Created by Ranen Ghosh on 2016-07-20.
//  Copyright © 2016 mousebird consulting. All rights reserved.
//

#import "ListTileTablesViewController.h"
#import "GPKGGeoPackageFactory.h"

@interface ListTileTablesViewController ()

@end

@implementation ListTileTablesViewController {
    UITableView *_tableView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Choose Tile or Feature Table";
    
    
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor grayColor];
    _tableView.separatorColor = [UIColor whiteColor];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_tableView];
    self.view.autoresizesSubviews = true;

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
}

- (void)viewWillAppear:(BOOL)animated
{
    
    [_tableView reloadData];
}



#pragma mark - Table Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
        return self.tileTableNames.count;
    else
        return self.featureTableNames.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0)
        return @"Tile Tables";
    else
        return @"Feature Tables";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    
    
    if (indexPath.section == 0)
        cell.textLabel.text = self.tileTableNames[indexPath.row];
    else
        cell.textLabel.text = self.featureTableNames[indexPath.row];
    
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.backgroundColor = [UIColor grayColor];
    
    return cell;
}

#pragma mark - Table Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    TilePyramidViewController *viewC = [[TilePyramidViewController alloc] initWithNibName:nil bundle:nil];
    
    viewC.geoPackage = self.geoPackage;
    if (indexPath.section == 0)
        viewC.tileTableName = self.tileTableNames[indexPath.row];
    else
        viewC.featureTableName = self.featureTableNames[indexPath.row];
    
    [self.navigationController pushViewController:viewC animated:YES];

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
