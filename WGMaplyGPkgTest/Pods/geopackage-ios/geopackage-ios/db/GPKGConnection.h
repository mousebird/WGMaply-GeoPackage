//
//  GPKGConnection.h
//  geopackage-ios
//
//  Created by Brian Osborn on 5/7/15.
//  Copyright (c) 2015 NGA. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GPKGResultSet.h"
#import "GPKGContentValues.h"

/**
 *  GeoPackage database connection
 */
@interface GPKGConnection : NSObject

/**
 *  GeoPackage name
 */
@property (nonatomic, strong) NSString *name;

/**
 *  GeoPackage filename
 */
@property (nonatomic, strong) NSString *filename;

/**
 *  Initialize
 *
 *  @param filename GeoPackage filename
 *
 *  @return new connection
 */
-(instancetype)initWithDatabaseFilename:(NSString *) filename;

/**
 *  Close the connection
 */
-(void)close;

/**
 *  Raw query
 *
 *  @param statement query statement
 *
 *  @return result set
 */
-(GPKGResultSet *) rawQuery:(NSString *) statement;

/**
 *  Raw query
 *
 *  @param statement query statement
 *  @param args      query args
 *
 *  @return result set
 */
-(GPKGResultSet *) rawQuery:(NSString *) statement andArgs: (NSArray *) args;

/**
 *  Query table columns where
 *
 *  @param table     table
 *  @param columns   columns
 *  @param where     where clause
 *  @param whereArgs where args
 *  @param groupBy   group by clause
 *  @param having    having clause
 *  @param orderBy   order by clause
 *
 *  @return result set
 */
-(GPKGResultSet *) queryWithTable: (NSString *) table
                       andColumns: (NSArray *) columns
                       andWhere: (NSString *) where
                       andWhereArgs: (NSArray *) whereArgs
                       andGroupBy: (NSString *) groupBy
                       andHaving: (NSString *) having
                       andOrderBy: (NSString *) orderBy;

/**
 *  Query table columns where
 *
 *  @param table     table
 *  @param columns   columns
 *  @param where     where clause
 *  @param whereArgs where args
 *  @param groupBy   group by clause
 *  @param having    having clause
 *  @param orderBy   order by clause
 *  @param limit     limit clause
 *
 *  @return result set
 */
-(GPKGResultSet *) queryWithTable: (NSString *) table
                       andColumns: (NSArray *) columns
                       andWhere: (NSString *) where
                       andWhereArgs: (NSArray *) whereArgs
                       andGroupBy: (NSString *) groupBy
                       andHaving: (NSString *) having
                       andOrderBy: (NSString *) orderBy
                       andLimit: (NSString *) limit;

/**
 *  Count statement
 *
 *  @param statement count statement
 *
 *  @return count
 */
-(int) count:(NSString *) statement;

/**
 *  Count statement
 *
 *  @param statement count statement
 *  @param args      statement args
 *
 *  @return count
 */
-(int) count:(NSString *) statement andArgs: (NSArray *) args;

/**
 *  Count with table where
 *
 *  @param table table
 *  @param where where clause
 *
 *  @return count
 */
-(int) countWithTable: (NSString *) table andWhere: (NSString *) where;

/**
 *  Count with table where
 *
 *  @param table     table
 *  @param where     where
 *  @param whereArgs where args
 *
 *  @return count
 */
-(int) countWithTable: (NSString *) table andWhere: (NSString *) where andWhereArgs: (NSArray *) whereArgs;

/**
 *  Get the min result of the column
 *
 *  @param table     table
 *  @param column    column
 *  @param where     where
 *  @param whereArgs where args
 *
 *  @return min or nil
 */
-(NSNumber *) minWithTable: (NSString *) table andColumn: (NSString *) column andWhere: (NSString *) where andWhereArgs: (NSArray *) whereArgs;

/**
 *  Get the max result of the column
 *
 *  @param table     table
 *  @param column    column
 *  @param where     where
 *  @param whereArgs where args
 *
 *  @return max or nil
 */
-(NSNumber *) maxWithTable: (NSString *) table andColumn: (NSString *) column andWhere: (NSString *) where andWhereArgs: (NSArray *) whereArgs;

/**
 *  Begin an exclusive transaction on the database
 */
-(void) beginTransaction;

/**
 *  Commit an active transaction
 */
-(void) commitTransaction;

/**
 *  Rollback an active transaction
 */
-(void) rollbackTransaction;

/**
 *  Insert statement
 *
 *  @param statement insert statement
 *
 *  @return insertion id
 */
-(long long) insert:(NSString *) statement;

/**
 *  Update statement
 *
 *  @param statement update statement
 *
 *  @return updated rows
 */
-(int) update:(NSString *) statement;

/**
 *  Update table where
 *
 *  @param table  table
 *  @param values content values
 *  @param where  where clause
 *
 *  @return updated rows
 */
-(int) updateWithTable: (NSString *) table andValues: (GPKGContentValues *) values andWhere: (NSString *) where;

/**
 *  Update table where
 *
 *  @param table     table
 *  @param values    content values
 *  @param where     where clause
 *  @param whereArgs where args
 *
 *  @return updated rows
 */
-(int) updateWithTable: (NSString *) table andValues: (GPKGContentValues *) values andWhere: (NSString *) where andWhereArgs: (NSArray *) whereArgs;

/**
 *  Insert into table
 *
 *  @param table  table
 *  @param values content values
 *
 *  @return insertion id
 */
-(long long) insertWithTable: (NSString *) table andValues: (GPKGContentValues *) values;

/**
 *  Delete statement
 *
 *  @param statement delete statement
 *
 *  @return deleted rows
 */
-(int) delete:(NSString *) statement;

/**
 *  Delete from table where
 *
 *  @param table table
 *  @param where where clause
 *
 *  @return deleted rows
 */
-(int) deleteWithTable: (NSString *) table andWhere: (NSString *) where;

/**
 *  Delete from table where
 *
 *  @param table     table
 *  @param where     where clause
 *  @param whereArgs where args
 *
 *  @return deleted rows
 */
-(int) deleteWithTable: (NSString *) table andWhere: (NSString *) where andWhereArgs: (NSArray *) whereArgs;

/**
 *  Execute statement
 *
 *  @param statement execute statement
 */
-(void) exec:(NSString *) statement;

/**
 *  Check if a table exists
 *
 *  @param table table
 *
 *  @return true if exists
 */
-(BOOL) tableExists: (NSString *) table;

/**
 *  Check if the table column exists
 *
 *  @param tableName  table name
 *  @param columnName column name
 *
 *  @return true if column exists
 */
-(BOOL) columnExistsWithTableName: (NSString *) tableName andColumnName: (NSString *) columnName;

/**
 *  Add a new column to the table
 *
 *  @param tableName  table name
 *  @param columnName column name
 *  @param columndef  column definition
 */
-(void) addColumnWithTableName: (NSString *) tableName andColumnName: (NSString *) columnName andColumnDef: (NSString *) columndef;

/**
 *  Query for a single result string
 *
 *  @param sql  sql statement
 *  @param args sql arguments
 *
 *  @return single result object
 */
-(NSString *) querySingleStringResultWithSql: (NSString *) sql andArgs: (NSArray *) args;

/**
 *  Set the GeoPackage application id
 */
-(void) setApplicationId;

/**
 *  Set the application id
 *
 *  @param applicationId application id
 */
-(void) setApplicationId: (NSString *) applicationId;

/**
 *  Get the application id
 *
 *  @return application id
 */
-(NSString *) applicationId;

/**
 *  Set the GeoPackage user version
 */
-(void) setUserVersion;

/**
 *  Set the user version
 *
 *  @param userVersion user version
 */
-(void) setUserVersion: (int) userVersion;

/**
 *  Get the user version
 *
 *  @return user version
 */
-(int) userVersion;

/**
 *  Drop the table
 *
 *  @param table table name
 */
-(void) dropTable: (NSString *) table;

@end
