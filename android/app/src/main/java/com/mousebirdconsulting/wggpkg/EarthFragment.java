package com.mousebirdconsulting.wggpkg;


import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import com.j256.ormlite.dao.GenericRawResults;
import com.mousebird.maply.GlobeMapFragment;
import com.mousebird.maply.MapboxVectorTileSource;
import com.mousebird.maply.PlateCarreeCoordSystem;
import com.mousebird.maply.QuadImageTileLayer;
import com.mousebird.maply.QuadPagingLayer;
import com.mousebird.maply.RemoteTileInfo;
import com.mousebird.maply.RemoteTileSource;
import com.mousebird.maply.SphericalMercatorCoordSystem;
import com.mousebird.maply.VectorStyleSimpleGenerator;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;

import mil.nga.geopackage.GeoPackage;
import mil.nga.geopackage.GeoPackageManager;
import mil.nga.geopackage.core.contents.ContentsDao;
import mil.nga.geopackage.db.GeoPackageConnection;
import mil.nga.geopackage.factory.GeoPackageFactory;
import mil.nga.geopackage.features.user.FeatureDao;
import mil.nga.geopackage.tiles.user.TileDao;


public class EarthFragment extends GlobeMapFragment {

    HashMap<String, HashMap<String, Boolean>> vectorLayerConfig = new HashMap<>();
    HashMap<String, HashMap<String, Boolean>> tileLayerConfig = new HashMap<>();

    HashMap<String, List<Number>> bounds = null;

    class TableInfo {
        public String sld, grouping, category;
        public Number zorder;
    }

    HashMap<String, HashMap<String, TableInfo>> extraContents = new HashMap<>();

    public EarthFragment() {
        super();



    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container,
                             Bundle inState) {
        super.onCreateView(inflater, container, inState);

        // Do app specific setup logic.
        Log.i("EarthFragment", "onCreateView");

        return baseControl.getContentView();
    }

    void setBounds() {
        bounds = new HashMap<>();
        try {
            InputStream inputStream = getContext().getAssets().open("bounds.json");
            BufferedReader streamReader = new BufferedReader(new InputStreamReader(inputStream, "UTF-8"));
            StringBuilder responseStrBuilder = new StringBuilder();

            String inputStr;
            while ((inputStr = streamReader.readLine()) != null)
                responseStrBuilder.append(inputStr);

            JSONObject jObject = new JSONObject(responseStrBuilder.toString());
            Iterator<?> keys = jObject.keys();
            while (keys.hasNext()) {
                String key = (String)keys.next();
                JSONArray jsonArray = jObject.getJSONArray(key);
                ArrayList<Number>  entry = new ArrayList<>();
                for (int i=0; i<6; i++)
                    entry.add(jsonArray.getDouble(i));
                entry.add(jsonArray.getBoolean(6) ? 1 : 0);
                bounds.put(key, entry);
            }

        } catch (Exception e) {
            Log.e("EarthFragment", "exception processing bounds", e);
        }
    }



    @Override
    protected MapDisplayType chooseDisplayType() {
        return MapDisplayType.Globe;
    }

    @Override
    protected void controlHasStarted() {
        if (bounds == null)
            setBounds();

        // setup base layer tiles
        String cacheDirName = "stamen_toner";
        File cacheDir = new File(getActivity().getCacheDir(), cacheDirName);
        cacheDir.mkdir();
        RemoteTileSource remoteTileSource = new RemoteTileSource(baseControl, new RemoteTileInfo("http://tile.stamen.com/toner/", "png", 0, 18));
        remoteTileSource.setCacheDir(cacheDir);
        SphericalMercatorCoordSystem coordSystem = new SphericalMercatorCoordSystem();

        // globeControl is the controller when using MapDisplayType.Globe
        // mapControl is the controller when using MapDisplayType.Map
        QuadImageTileLayer baseLayer = new QuadImageTileLayer(globeControl, coordSystem, remoteTileSource);
        baseLayer.setImageDepth(1);
        baseLayer.setSingleLevelLoading(false);
        baseLayer.setUseTargetZoomLevel(false);
        baseLayer.setCoverPoles(true);
        baseLayer.setHandleEdges(true);

        // add layer and position
        globeControl.addLayer(baseLayer);
        globeControl.animatePositionGeo(-3.6704803, 40.5023056, 5, 1.0);



        // Get a manager
        GeoPackageManager manager = GeoPackageFactory.getManager(getContext());

        // Available databases
        List<String> databases = manager.databases();

        // Work through the vector layers
        for (String gpkgFilename : vectorLayerConfig.keySet()) {
            GeoPackage gpkg = manager.open(gpkgFilename);

            boolean imported = false;
            try {
                imported = manager.importGeoPackage(gpkgFilename, getContext().getAssets().open(gpkgFilename));
            } catch (Exception e) {
                if (!e.getMessage().startsWith("GeoPackage database already exists"))
                    Log.e("EarthFragment", "Import exception", e);
                else
                    imported = true;
            }

            setExtraContents(gpkgFilename, gpkg);

            HashMap<String, TableInfo> gpkgExtraContents = extraContents.get(gpkgFilename);

            for (String featureTableName: vectorLayerConfig.get(gpkgFilename).keySet()) {
                FeatureDao featureDao = gpkg.getFeatureDao(featureTableName);

                String sldFilename = null;
                if (gpkgExtraContents != null) {
                    TableInfo tableInfo = gpkgExtraContents.get(featureTableName);
                    if (tableInfo != null)
                        sldFilename = tableInfo.sld;
                }

                GPKGFeatureTileSource tileSource = new GPKGFeatureTileSource(gpkgFilename,
                        gpkg, (GeoPackageConnection)gpkg.getDatabase(), featureDao,
                        sldFilename, getContext().getAssets(), getContext().getResources().getDisplayMetrics(), bounds, 1, 20);

                QuadPagingLayer quadPagingLayer = new QuadPagingLayer(baseControl, new PlateCarreeCoordSystem(), tileSource);

                baseControl.addLayer(quadPagingLayer);

            }
        }

        // Work through the image layers
        for (String gpkgFilename : tileLayerConfig.keySet()) {
            GeoPackage gpkg = manager.open(gpkgFilename);
            ContentsDao contentsDao = gpkg.getContentsDao();
            List<String> fields = getContentsFields(contentsDao);

            boolean imported = false;
            try {
                imported = manager.importGeoPackage(gpkgFilename, getContext().getAssets().open(gpkgFilename));
            } catch (Exception e) {
                if (!e.getMessage().startsWith("GeoPackage database already exists"))
                    Log.e("EarthFragment", "Import exception", e);
                else
                    imported = true;
            }

            for (String tileTableName: tileLayerConfig.get(gpkgFilename).keySet()) {
                TileDao tileDao = gpkg.getTileDao(tileTableName);

                boolean isVectorTiles = false;
                if (fields.contains("data_type")) {
                    try {
                        GenericRawResults<String[]> rawResults = contentsDao.queryRaw("SELECT table_name, data_type FROM gpkg_contents;");
                        List<String[]> results = rawResults.getResults();
                        for (String[] entry : results) {
                            String tableName = entry[0];
                            if (tableName.equals(tileTableName)) {
                                if (entry[1].equals("mbvectiles"))
                                    isVectorTiles = true;
                            }
                        }
                    } catch (Exception e) {
                        continue;
                    }
                }

                if (isVectorTiles)
                {
                    // Mapbox Vector tile format data
                    // Yes, this is custom to us
                    GPKGVectorTileSource vecTileSource = new GPKGVectorTileSource(gpkgFilename, gpkg,
                            (GeoPackageConnection) gpkg.getDatabase(), tileDao, bounds);

                    // A simple vector style that picks random colors
                    VectorStyleSimpleGenerator simpleStyle = new VectorStyleSimpleGenerator(baseControl);

                    // Set up the source and start the layer
                    MapboxVectorTileSource mbTileSource = new MapboxVectorTileSource(vecTileSource,simpleStyle);

                    QuadPagingLayer layer = new QuadPagingLayer(baseControl,vecTileSource.coordSys,mbTileSource);
                    layer.setSimultaneousFetches(4);
                    layer.setImportance(1024*1024);

                    baseControl.addLayer(layer);
                } else {
                    // Regular image tile pyramid
                    GPKGImageTileSource imageTileSource = new GPKGImageTileSource(gpkgFilename, gpkg,
                            (GeoPackageConnection) gpkg.getDatabase(), tileDao, bounds);

                    QuadImageTileLayer imageTileLayer = new QuadImageTileLayer(baseControl, imageTileSource.getCoordSys(), imageTileSource);
                    imageTileLayer.setDrawPriority(200);

                    baseControl.addLayer(imageTileLayer);
                }
            }
        }
    }

    List<String> getContentsFields(ContentsDao contentsDao) {
        ArrayList<String> fields = new ArrayList<>();
        try {
            GenericRawResults<String[]> rawResults = contentsDao.queryRaw("PRAGMA table_info(gpkg_contents);");
            List<String[]> results = rawResults.getResults();
            for (String[] entry : results)
                fields.add(entry[1]);
        } catch (Exception e) {
            // TODO: handle this error?
        }
        return fields;
    }

    void setExtraContents(String gpkgFilename, GeoPackage gpkg) {
        if (extraContents.containsKey(gpkgFilename))
            return;

        HashMap<String, TableInfo> gpkgExtraContents = new HashMap<>();
        extraContents.put(gpkgFilename, gpkgExtraContents);

        ContentsDao contentsDao = gpkg.getContentsDao();
        List<String> fields = getContentsFields(contentsDao);
        if (!fields.contains("sld"))
            return;

        try {
            GenericRawResults<String[]> rawResults = contentsDao.queryRaw("SELECT table_name, sld FROM gpkg_contents;");
            List<String[]> results = rawResults.getResults();
            for (String[] entry : results) {
                String tableName = entry[0];
                TableInfo tableInfo = new TableInfo();
                tableInfo.sld = entry[1];
                gpkgExtraContents.put(tableName, tableInfo);
            }
        } catch (Exception e) {
            Log.e("EarthFragment", "Error in setExtraContents.", e);
        }
    }


    public void changeFeatureLayer(String gpkg, String featureTable, boolean enabled) {

        HashMap<String, Boolean> featureTables = vectorLayerConfig.get(gpkg);

        if ((featureTables == null) && enabled) {
            featureTables = new HashMap<>();
            vectorLayerConfig.put(gpkg, featureTables);
        }

        if (enabled)
            featureTables.put(featureTable, Boolean.TRUE);
        else
            featureTables.remove(featureTable);

    }

    public boolean isFeatureLayerEnabled(String gpkg, String featureTable) {
        HashMap<String, Boolean> featureTables = vectorLayerConfig.get(gpkg);
        if (featureTables == null)
            return false;
        Boolean enabled = featureTables.get(featureTable);
        return ((enabled != null) && enabled);
    }

    public void changeTileLayer(String gpkg, String tileTable, boolean enabled) {

        HashMap<String, Boolean> tileTables = tileLayerConfig.get(gpkg);

        if ((tileTables == null) && enabled) {
            tileTables = new HashMap<>();
            tileLayerConfig.put(gpkg, tileTables);
        }

        if (enabled)
            tileTables.put(tileTable, Boolean.TRUE);
        else
            tileTables.remove(tileTable);

    }

    public boolean isTileLayerEnabled(String gpkg, String tileTable) {
        HashMap<String, Boolean> tileTables = tileLayerConfig.get(gpkg);
        if (tileTables == null)
            return false;
        Boolean enabled = tileTables.get(tileTable);
        return ((enabled != null) && enabled);
    }

}

