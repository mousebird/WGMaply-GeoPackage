//
//  GPKGMetadataExtension.h
//  geopackage-ios
//
//  Created by Brian Osborn on 5/4/16.
//  Copyright © 2016 NGA. All rights reserved.
//

#import "GPKGBaseExtension.h"

extern NSString * const GPKG_METADATA_EXTENSION_NAME;

/**
 *  Metadata extension
 */
@interface GPKGMetadataExtension : GPKGBaseExtension

/**
 *  Extension name
 */
@property (nonatomic, strong) NSString *extensionName;

/**
 *  Extension definition URL
 */
@property (nonatomic, strong) NSString *definition;

/**
 *  Initialize
 *
 *  @param geoPackage GeoPackage
 *
 *  @return new instance
 */
-(instancetype) initWithGeoPackage: (GPKGGeoPackage *) geoPackage;

/**
 *  Get or create the extension
 *
 *  @return extension
 */
-(GPKGExtensions *) getOrCreate;

/**
 *  Determine if the GeoPackage has the extension
 *
 *  @return true if has extension
 */
-(BOOL) has;

@end
