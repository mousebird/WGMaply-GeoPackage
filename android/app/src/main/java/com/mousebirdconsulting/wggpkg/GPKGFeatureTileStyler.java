package com.mousebirdconsulting.wggpkg;

import android.util.Log;

import com.mousebird.maply.AttrDictionary;
import com.mousebird.maply.ComponentObject;
import com.mousebird.maply.MaplyBaseController;
import com.mousebird.maply.MaplyTileID;
import com.mousebird.maply.Mbr;
import com.mousebird.maply.Point2d;
import com.mousebird.maply.VectorObject;
import com.mousebird.maply.VectorStyle;
import com.mousebird.maply.VectorStyleInterface;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;

import mil.nga.geopackage.BoundingBox;
import mil.nga.geopackage.db.GeoPackageDataType;
import mil.nga.geopackage.features.user.FeatureColumn;
import mil.nga.geopackage.features.user.FeatureRow;
import mil.nga.geopackage.geom.GeoPackageGeometryData;
import mil.nga.geopackage.projection.GeometryProjectionTransform;
import mil.nga.wkb.geom.Geometry;
import mil.nga.wkb.geom.GeometryType;
import mil.nga.wkb.geom.LineString;
import mil.nga.wkb.geom.MultiLineString;
import mil.nga.wkb.geom.MultiPoint;
import mil.nga.wkb.geom.MultiPolygon;
import mil.nga.wkb.geom.Point;
import mil.nga.wkb.geom.Polygon;

/**
 * Created by rghosh on 2017-06-13.
 */

public class GPKGFeatureTileStyler {

    public static final int GPKG_FEATURE_TILE_SOURCE_MAX_POINTS = 20000;
    public static final int GPKG_FEATURE_TILE_SOURCE_MAX_BYTES = 160000;

    VectorStyleInterface styleInterface;
    MaplyBaseController viewC;
    int targetLevel, maxZoom;
    GPKGRTreeIndex rTreeIndex;
    GeometryProjectionTransform geomProjTransform;

    public GPKGFeatureTileStyler(VectorStyleInterface styleInterface, MaplyBaseController viewC, int targetLevel, int maxZoom, GPKGRTreeIndex rTreeIndex, GeometryProjectionTransform geomProjTransform) {

        this.styleInterface = styleInterface;
        this.viewC = viewC;
        this.targetLevel = targetLevel;
        this.maxZoom = maxZoom;
        this.rTreeIndex = rTreeIndex;
        this.geomProjTransform = geomProjTransform;

    }

    public int buildObjects(MaplyTileID tileID, Mbr geoBbox, Mbr geoBboxDeg, ArrayList<ComponentObject> compObjs) {

        if (tileID.level > targetLevel)
            return 0;

        HashMap<String, ArrayList<VectorObject>> featureStyles = new HashMap<>();

        BoundingBox gpkgBbox = new BoundingBox(geoBboxDeg.ll.getX(), geoBboxDeg.ur.getX(), geoBboxDeg.ll.getY(), geoBboxDeg.ur.getY());
        GPKGRTreeIndexCursor rTreeIndexCursor = rTreeIndex.query(gpkgBbox);
        int n = rTreeIndexCursor.getCount();
        long totalBytes = 0;

        if (n > 0 && tileID.level == targetLevel) {

            String[] columnNames = null;

            while(rTreeIndexCursor.moveToNext()) {
                GPKGRTreeIndexRow rTreeIndexRow = rTreeIndexCursor.getRow();
                FeatureRow featureRow = rTreeIndex.getFeatureRow(rTreeIndexRow);
                GeoPackageGeometryData geometryData = featureRow.getGeometry();

                if (columnNames == null)
                    columnNames = featureRow.getColumnNames();

                totalBytes += geometryData.getBytes().length;
                if (totalBytes > GPKG_FEATURE_TILE_SOURCE_MAX_BYTES && targetLevel < maxZoom)
                    break;

                if (geometryData != null && !geometryData.isEmpty()) {

                    Geometry geometry = geometryData.getGeometry();
                    if (geometry != null) {

                        geometry = geomProjTransform.transform(geometry);

                        ArrayList<VectorObject> pointObjs = new ArrayList<>();
                        ArrayList<VectorObject> linestringObjs = new ArrayList<>();
                        ArrayList<VectorObject> polygonObjs = new ArrayList<>();

//                        HashMap<String, Object> attributes = new HashMap<>();
//                        attributes.put("geometry_type", geometry.getGeometryType().getName());

                        AttrDictionary attributes = new AttrDictionary();
                        attributes.setString("geometry_type", geometry.getGeometryType().getName());

                        for (String columnName : columnNames) {

                            FeatureColumn featureColumn = featureRow.getColumn(columnName);
                            GeoPackageDataType geoPackageDataType = featureColumn.getDataType();

                            if (geoPackageDataType == GeoPackageDataType.BOOLEAN)

                            switch (geoPackageDataType) {
                                case TEXT: {
                                    attributes.setString(columnName, (String) featureRow.getValue(columnName));
                                    break;
                                }
                                case BOOLEAN:
                                case TINYINT:
                                case SMALLINT:
                                case MEDIUMINT:
                                case INT:
                                case INTEGER: {
                                    attributes.setInt(columnName, ((Number) featureRow.getValue(columnName)).intValue());
                                    break;
                                }
                                case FLOAT:
                                case DOUBLE:
                                case REAL: {
                                    attributes.setDouble(columnName, ((Number) featureRow.getValue(columnName)).doubleValue());
                                    break;
                                }
                                default:
                                    continue;
                            }
                        }


                        VectorStyle[] vectorStyles = styleInterface.stylesForFeature(attributes, tileID, "", viewC);
                        if (vectorStyles == null || vectorStyles.length == 0)
                            continue;

                        if (geometry.getGeometryType() == GeometryType.LINESTRING) {
                            LineString  lineString = (LineString)geometry;
                            if (!processLineString(lineString, tileID, geoBbox, geoBboxDeg, linestringObjs))
                                n -= 1;
                        } else if (geometry.getGeometryType() == GeometryType.POLYGON) {
                            Polygon polygon = (Polygon)geometry;
                            if (!processPolygon(polygon, tileID, geoBbox, geoBboxDeg, linestringObjs, polygonObjs))
                                n -= 1;
                        } else if (geometry.getGeometryType() == GeometryType.POINT) {
                            Point point = (Point)geometry;
                            Point2d point2d = new Point2d(point.getX()*Math.PI/180.0, point.getY()*Math.PI/180.0);

                            VectorObject vectorObject = new VectorObject();
                            vectorObject.addPoint(point2d);
                            pointObjs.add(vectorObject);
                        } else if (geometry.getGeometryType() == GeometryType.MULTIPOINT) {
                            MultiPoint multiPoint = (MultiPoint)geometry;
                            VectorObject multiPointObj = new VectorObject();
                            Point2d point2d;
                            for (Point point: multiPoint.getPoints()) {
                                point2d = new Point2d(point.getX()*180.0/Math.PI, point.getY());
                                multiPointObj.addPoint(point2d);
                            }
                            pointObjs.add(multiPointObj);
                        } else if (geometry.getGeometryType() == GeometryType.MULTILINESTRING) {
                            MultiLineString multiLineString = (MultiLineString)geometry;
                            for (LineString lineString : multiLineString.getLineStrings()) {
                                processLineString(lineString, tileID, geoBbox, geoBboxDeg, linestringObjs);
                            }
                        } else if (geometry.getGeometryType() == GeometryType.MULTIPOLYGON) {
                            MultiPolygon multiPolygon = (MultiPolygon)geometry;
                            for (Polygon polygon : multiPolygon.getPolygons()) {
                                processPolygon(polygon, tileID, geoBbox, geoBboxDeg, linestringObjs, polygonObjs);
                            }
                        } else {
                            n -= 1;
                        }

                        ArrayList<VectorObject> allVectorObjects = new ArrayList<>();
                        allVectorObjects.addAll(pointObjs);
                        allVectorObjects.addAll(linestringObjs);
                        allVectorObjects.addAll(polygonObjs);

                        for (VectorObject vectorObject : allVectorObjects) {
                            for (VectorStyle vectorStyle : vectorStyles) {
                                ArrayList<VectorObject> featuresForStyle = featureStyles.get(vectorStyle.getUuid());
                                if (featuresForStyle == null) {
                                    featuresForStyle = new ArrayList<>();
                                    featureStyles.put(vectorStyle.getUuid(), featuresForStyle);
                                }
                                featuresForStyle.add(vectorObject);
                            }
                            vectorObject.getAttributes().addEntries(attributes);
                        }

                    }
                }


            }
            rTreeIndexCursor.close();
        }

        if (totalBytes > GPKG_FEATURE_TILE_SOURCE_MAX_BYTES && targetLevel < maxZoom) {
            targetLevel += 1;
            return 0;
        }

        ArrayList<String> symbolizerKeys = new ArrayList<>(featureStyles.keySet());
        java.util.Collections.sort(symbolizerKeys);

        for (String key : symbolizerKeys) {
            VectorStyle vectorStyle = styleInterface.styleForUUID(key, viewC);
            ArrayList<VectorObject> features = featureStyles.get(key);
            compObjs.addAll(Arrays.asList(vectorStyle.buildObjects(features, tileID, viewC)));
        }

        return n;
    }

    boolean processLineString(LineString lineString, MaplyTileID tileID, Mbr geoBbox, Mbr geoBboxDeg, ArrayList<VectorObject> linestringObjs) {


        ArrayList<Point2d> coords = new ArrayList<Point2d>();

        List<Point> pointsList = lineString.getPoints();
        if (pointsList.size() > 0 && pointsList.size() < GPKG_FEATURE_TILE_SOURCE_MAX_POINTS) {

            for (int i = 0; i < pointsList.size(); i++)
                coords.add(new Point2d(pointsList.get(i).getX(), pointsList.get(i).getY()));

            VectorObject vecObj = new VectorObject();
            vecObj.addLinear(pointsList.toArray(new Point2d[]{}));

            VectorObject clipped = vecObj.clipToMbr(geoBbox);

            linestringObjs.add(clipped);
            return true;
        } else {
            Log.i("GPKGFeatureTileStyler", "skip linestring");
            return false;
        }
    }

    boolean processPolygon(Polygon polygon, MaplyTileID tileID, Mbr geoBbox, Mbr geoBboxDeg, ArrayList<VectorObject> linestringObjs, ArrayList<VectorObject> polygonObjs) {

        boolean processed = true;
        ArrayList<Point2d> outerRing = new ArrayList<>();
        ArrayList<ArrayList<Point2d>> holes = new ArrayList<>();

        VectorObject polyVecObj = null;
        ArrayList<VectorObject> lineVecObjs = new ArrayList<VectorObject>();

        List<LineString> rings = polygon.getRings();
        for (LineString ring: rings) {
            if (ring.numPoints() < GPKG_FEATURE_TILE_SOURCE_MAX_POINTS) {

                List<Point> pointsList = ring.getPoints();
                ArrayList<Point2d> ringCoords = new ArrayList<Point2d>();
                for (int i = 0; i < pointsList.size()-1; i++)
                    ringCoords.add(new Point2d(pointsList.get(i).getX(), pointsList.get(i).getY()));

                if (polyVecObj == null) {
                    polyVecObj = new VectorObject();
                    outerRing = ringCoords;
                } else {
                    holes.add(ringCoords);
                }
            } else {
                Log.i("GPKGFeatureTileStyler", "skip polygon");
                polyVecObj = null;
                break;
            }
        }

        if (polyVecObj != null) {

            if (holes.size() == 0)
                polyVecObj.addAreal(outerRing.toArray(new Point2d[]{}));
            else {
                Point2d[][] holePoints = new Point2d[holes.size()][];
                for (int i = 0; i < holes.size(); i++)
                    holePoints[i] = holes.get(i).toArray(new Point2d[]{});
                polyVecObj.addAreal(outerRing.toArray(new Point2d[]{}), holePoints);
            }

            VectorObject clipped = polyVecObj.clipToMbr(geoBbox);

            if (clipped != null && clipped.getVectorType() == VectorObject.MaplyVectorObjectType.MaplyVectorArealType) {
                polygonObjs.add(clipped);
                for (VectorObject lineVecObj : lineVecObjs) {
                    clipped = lineVecObj.clipToMbr(geoBbox);
                    linestringObjs.add(clipped);
                }
            } else
                processed = false;
        } else
            processed = false;

        return processed;
    }




}
