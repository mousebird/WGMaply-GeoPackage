package com.mousebirdconsulting.wggpkg;

import android.content.Context;
import android.content.res.AssetManager;
import android.graphics.BitmapFactory;
import android.os.Bundle;
import android.support.annotation.Nullable;
import android.support.v4.app.Fragment;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;

import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import butterknife.BindView;
import butterknife.ButterKnife;
import butterknife.Unbinder;
import mil.nga.geopackage.GeoPackage;
import mil.nga.geopackage.GeoPackageManager;
import mil.nga.geopackage.core.contents.Contents;
import mil.nga.geopackage.core.contents.ContentsDao;
import mil.nga.geopackage.factory.GeoPackageFactory;
import tellh.com.recyclertreeview_lib.TreeNode;
import tellh.com.recyclertreeview_lib.TreeViewAdapter;
import tellh.com.recyclertreeview_lib.TreeViewBinder;

public class GPkgTreeFragment extends Fragment {

    @BindView(R.id.rv) RecyclerView rv;

    private Unbinder unbinder;
    private TreeViewAdapter adapter;
    private GeoPackageManager geoPackageManager;

    private GPkgTreeFragmentInteractionListener mListener;

    public GPkgTreeFragment() {
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container,
                             Bundle savedInstanceState) {
        return inflater.inflate(R.layout.fragment_gpkg_tree, container, false);
    }

    @Override
    public void onViewCreated(View view, @Nullable Bundle savedInstanceState) {
        unbinder = ButterKnife.bind(this, view);
        geoPackageManager = GeoPackageFactory.getManager(getContext());
        initData();
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        unbinder.unbind();
    }

    @Override
    public void onAttach(Context context) {
        super.onAttach(context);
        if (context instanceof GPkgTreeFragmentInteractionListener) {
            mListener = (GPkgTreeFragmentInteractionListener) context;
        } else {
            throw new RuntimeException(context.toString()
                    + " must implement GPkgTreeFragmentInteractionListener");
        }
    }

    @Override
    public void onDetach() {
        super.onDetach();
        mListener = null;
    }

    public interface GPkgTreeFragmentInteractionListener {
        void onFragmentInteraction();
        void changeFeatureLayer(String gpkg, String featureTable, boolean enabled);
        void changeTileLayer(String gpkg, String tileTable, boolean enabled);
        boolean isFeatureLayerEnabled(String gpkg, String featureTable);
    }


    private void initData() {

        System.loadLibrary("gnustl_shared");
        System.loadLibrary("Maply");
        System.loadLibrary("sqliteX");


        List<TreeNode> nodes = new ArrayList<>();

        AssetManager assetManager = getActivity().getApplicationContext().getAssets();

        TreeNode<LayerMenuViewHeaderItem> basemapsNode = new TreeNode<>(new LayerMenuViewHeaderItem("BASEMAPS"));
        TreeNode<LayerMenuViewHeaderItem> geopackagesNode = new TreeNode<>(new LayerMenuViewHeaderItem("GEOPACKAGES"));
        nodes.add(basemapsNode);
        nodes.add(geopackagesNode);

        try {
            for (String file : assetManager.list("")) {
                if (file.endsWith(".gpkg") || file.endsWith(".GPKG")) {
                    TreeNode<LayerMenuViewGeopackageItem> gpkgNode = new TreeNode<>(new LayerMenuViewGeopackageItem(file));
                    geopackagesNode.addChild(gpkgNode);
                }

            }
        } catch (Exception e) {
        }

        rv.setLayoutManager(new LinearLayoutManager(getActivity().getApplicationContext()));
        adapter = new TreeViewAdapter(nodes, Arrays.asList(new GPkgNodeBinder()));

        adapter.setOnTreeNodeListener(new TreeViewAdapter.OnTreeNodeListener() {
            @Override
            public boolean onClick(TreeNode node, RecyclerView.ViewHolder holder) {
                mListener.onFragmentInteraction();

                LayerMenuViewItem item = (LayerMenuViewItem)node.getContent();

                if (item instanceof  LayerMenuViewGeopackageItem) {

                    LayerMenuViewGeopackageItem gpkgItem = (LayerMenuViewGeopackageItem) item;
                    String filename = gpkgItem.getFilename();

                    if (!gpkgItem.isImported()) {

                        try {
                            boolean imported = geoPackageManager.importGeoPackage(filename, getContext().getAssets().open(filename));
                            gpkgItem.setImported(imported);
                        } catch (Exception e) {
                            if (e.getMessage().startsWith("GeoPackage database already exists"))
                                gpkgItem.setImported(true);
                            else
                                Log.e("GPkgTreeFragment", "Import exception", e);
                        }
                    }

                    if (gpkgItem.isImported() && !gpkgItem.isLoaded()) {

                        GeoPackage gpkg = geoPackageManager.open(filename);
                        List<String> features = gpkg.getFeatureTables();
                        for (String featureTableName : features) {
                            LayerMenuViewFeatureTableItem layerMenuViewFeatureTableItem = new LayerMenuViewFeatureTableItem(featureTableName);
                            layerMenuViewFeatureTableItem.enabled = mListener.isFeatureLayerEnabled(filename, featureTableName);
                            TreeNode<LayerMenuViewFeatureTableItem> featureTableNode = new TreeNode<>(layerMenuViewFeatureTableItem);
                            node.addChild(featureTableNode);
                        }

                        List<String> tiles = gpkg.getTileTables();
                        for (String tileTableName : tiles) {
                            TreeNode<LayerMenuViewTileTableItem> tileTableNode = new TreeNode<>(new LayerMenuViewTileTableItem(tileTableName));
                            node.addChild(tileTableNode);
                        }

                        List<String> vecTiles = new ArrayList<String>();
                        try {
                            ContentsDao contentsDao = gpkg.getContentsDao();
                            List<Contents> contents = contentsDao.queryForEq(Contents.COLUMN_DATA_TYPE,
                                    "mbvectiles");
                            for (Contents content : contents) {
                                vecTiles.add(content.getTableName());
                            }
                        } catch (SQLException e) {
                            e.printStackTrace();
                        }

                        for (String tileTableName : vecTiles) {
                            TreeNode<LayerMenuViewTileTableItem> tileTableNode = new TreeNode<>(new LayerMenuViewTileTableItem(tileTableName));
                            node.addChild(tileTableNode);
                        }

                        gpkgItem.setLoaded(true);
                        Log.i("GPkgTreeFragment", "gpkg contents: F " + features.size() + " ; T " + tiles.size());

                    }


                } else if (item instanceof  LayerMenuViewFeatureTableItem) {
                    LayerMenuViewFeatureTableItem featureTableItem = (LayerMenuViewFeatureTableItem)item;
                    featureTableItem.enabled = !featureTableItem.enabled;
                    adapter.notifyDataSetChanged();

                    TreeNode parentNode = node.getParent();

                    LayerMenuViewItem parentItem = (LayerMenuViewItem)parentNode.getContent();
                    LayerMenuViewGeopackageItem gpkgItem = (LayerMenuViewGeopackageItem) parentItem;
                    String filename = gpkgItem.getFilename();
                    String featureTableName = featureTableItem.getFeatureTableName();

                    mListener.changeFeatureLayer(filename, featureTableName, featureTableItem.enabled);
                } else if (item instanceof  LayerMenuViewTileTableItem) {
                    LayerMenuViewTileTableItem tileTableItem = (LayerMenuViewTileTableItem)item;
                    tileTableItem.enabled = !tileTableItem.enabled;
                    adapter.notifyDataSetChanged();

                    TreeNode parentNode = node.getParent();

                    LayerMenuViewItem parentItem = (LayerMenuViewItem)parentNode.getContent();
                    LayerMenuViewGeopackageItem gpkgItem = (LayerMenuViewGeopackageItem) parentItem;
                    String filename = gpkgItem.getFilename();
                    String tileTableName = tileTableItem.getTileTableName();

                    mListener.changeTileLayer(filename, tileTableName, tileTableItem.enabled);
                } else if (item instanceof  LayerMenuViewTileTableItem) {
                    LayerMenuViewTileTableItem tileTableItem = (LayerMenuViewTileTableItem)item;
                    tileTableItem.enabled = !tileTableItem.enabled;
                    adapter.notifyDataSetChanged();
                }


                if (!node.isLeaf()) {
                    //Update and toggle the node.
                    onToggle(!node.isExpand(), holder);
//                    if (!node.isExpand())
//                        adapter.collapseBrotherNode(node);
                }
                return false;
            }

            @Override
            public void onToggle(boolean isExpand, RecyclerView.ViewHolder holder) {
                Log.i("GPkgTreeFragment", "onToggle");


//                DirectoryNodeBinder.ViewHolder dirViewHolder = (DirectoryNodeBinder.ViewHolder) holder;
//                final ImageView ivArrow = dirViewHolder.getIvArrow();
//                int rotateDegree = isExpand ? 90 : -90;
//                ivArrow.animate().rotationBy(rotateDegree)
//                        .start();
            }
        });
        rv.setAdapter(adapter);

    }


    public class GPkgNodeBinder extends TreeViewBinder<GPkgNodeBinder.ViewHolder> {
        @Override
        public ViewHolder provideViewHolder(View itemView) {
            return new ViewHolder(itemView);
        }

        @Override
        public void bindView(ViewHolder holder, int position, TreeNode node) {
            LayerMenuViewItem item = (LayerMenuViewItem) node.getContent();
            holder.tvName.setText(item.displayText());

            if (item instanceof  LayerMenuViewFeatureTableItem || item instanceof LayerMenuViewTileTableItem) {
                boolean enabled = false;
                if (item instanceof  LayerMenuViewFeatureTableItem)
                    enabled = ((LayerMenuViewFeatureTableItem)item).enabled;
                else if (item instanceof LayerMenuViewTileTableItem)
                    enabled = ((LayerMenuViewTileTableItem)item).enabled;
                if (enabled)
                    holder.imageView.setImageBitmap(BitmapFactory.decodeResource(getActivity().getApplicationContext().getResources(), R.drawable.checkbox_marked));
                else
                    holder.imageView.setImageBitmap(BitmapFactory.decodeResource(getActivity().getApplicationContext().getResources(), R.drawable.checkbox_blank_outline));
                holder.tvName.setCompoundDrawablesWithIntrinsicBounds(0, 0, 0, 0);
            } else {
                holder.imageView.setImageBitmap(BitmapFactory.decodeResource(getActivity().getApplicationContext().getResources(), R.drawable.ic_keyboard_arrow_right_black_18dp));
                holder.tvName.setCompoundDrawablesWithIntrinsicBounds(R.drawable.ic_folder_light_blue_700_24dp, 0, 0, 0);

            }

        }

        @Override
        public int getLayoutId() {
            return R.layout.item;
        }

        public class ViewHolder extends TreeViewBinder.ViewHolder {
            public TextView tvName;
            public ImageView imageView;

            public ViewHolder(View rootView) {
                super(rootView);
                this.tvName = (TextView) rootView.findViewById(R.id.tv_name);
                this.imageView = (ImageView) rootView.findViewById(R.id.iv_arrow);
            }

        }
    }




}
