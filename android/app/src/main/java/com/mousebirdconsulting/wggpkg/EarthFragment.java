package com.mousebirdconsulting.wggpkg;


import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import com.mousebird.maply.GlobeMapFragment;
import com.mousebird.maply.MaplyBaseController;
import com.mousebird.maply.QuadImageTileLayer;
import com.mousebird.maply.QuadPagingLayer;
import com.mousebird.maply.RemoteTileInfo;
import com.mousebird.maply.RemoteTileSource;
import com.mousebird.maply.SphericalMercatorCoordSystem;

import mil.nga.geopackage.db.GeoPackageConnection;
import mil.nga.geopackage.factory.GeoPackageFactory;
import mil.nga.geopackage.GeoPackageManager;
import mil.nga.geopackage.GeoPackage;
import mil.nga.geopackage.features.user.FeatureDao;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import android.util.Log;

import com.mousebirdconsulting.wggpkg.R;

import org.json.JSONArray;
import org.json.JSONObject;

import static java.security.AccessController.getContext;


public class EarthFragment extends GlobeMapFragment {

    HashMap<String, HashMap<String, Boolean>> vectorLayerConfig = new HashMap<>();

    HashMap<String, List<Number>> bounds = null;

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


        for (String gpkgFilename : vectorLayerConfig.keySet()) {
            for (String featureTableName: vectorLayerConfig.get(gpkgFilename).keySet()) {
                Log.i("EarthFragment", "controlHasStarted ; " + gpkgFilename + " ; " + featureTableName );

                boolean imported = false;
                try {
                    imported = manager.importGeoPackage(gpkgFilename, getContext().getAssets().open(gpkgFilename));
                } catch (Exception e) {
                    if (!e.getMessage().startsWith("GeoPackage database already exists"))
                        Log.e("EarthFragment", "Import exception", e);
                    else
                        imported = true;
                }

                Log.i("EarthFragment", "imported? " + imported);

                GeoPackage gpkg = manager.open(gpkgFilename);

                FeatureDao featureDao = gpkg.getFeatureDao(featureTableName);

                GPKGFeatureTileSource tileSource = new GPKGFeatureTileSource("ne_10m_populated_places.gpkg",
                        gpkg, (GeoPackageConnection)gpkg.getDatabase(), featureDao,
                        "mainne_10m_populated_places.sld", getContext().getAssets(), getContext().getResources().getDisplayMetrics(), bounds, 1, 20);



                QuadPagingLayer quadPagingLayer = new QuadPagingLayer(baseControl, new SphericalMercatorCoordSystem(), tileSource);

                baseControl.addLayer(quadPagingLayer);

            }
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


}

